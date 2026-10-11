import CoreAudio
import Foundation

enum TapError: LocalizedError {
    case createTap(OSStatus)
    case createAggregate(OSStatus)
    case createIOProc(OSStatus)
    case start(OSStatus)

    var errorDescription: String? {
        switch self {
        case .createTap(let s): "Could not create audio tap (\(s)). Allow audio capture in System Settings → Privacy & Security."
        case .createAggregate(let s): "Could not create aggregate device (\(s))."
        case .createIOProc(let s): "Could not create audio callback (\(s))."
        case .start(let s): "Could not start audio device (\(s))."
        }
    }
}

/// Controls the volume of one app (a group of processes).
///
/// How it works:
///  1. A Core Audio *process tap* captures the app's audio and mutes its normal output
///     (`mutedWhenTapped`: muted only while we are reading the tap).
///  2. A private *aggregate device* combines that tap (as input) with the real speakers (as output).
///  3. An IO callback copies tap input → speaker output, multiplied by `gain`.
final class AppAudioTap {
    let processObjects: Set<AudioObjectID>

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "VolumeMixer.tap", qos: .userInteractive)

    /// Written on the main thread, read on the audio thread. A single aligned Float32 store/load is
    /// atomic on Apple hardware, and the audio thread never allocates or locks.
    private let targetGain: UnsafeMutablePointer<Float32>
    /// Audio-thread-only state used to ramp smoothly between gain values (avoids clicks).
    private let currentGain: UnsafeMutablePointer<Float32>

    var gain: Float32 {
        get { targetGain.pointee }
        set { targetGain.pointee = newValue }
    }

    init(processObjects: [AudioObjectID], outputDeviceUID: String, gain: Float32) throws {
        self.processObjects = Set(processObjects)
        targetGain = .allocate(capacity: 1)
        targetGain.initialize(to: gain)
        currentGain = .allocate(capacity: 1)
        currentGain.initialize(to: gain)
        do {
            try start(processObjects: processObjects, outputDeviceUID: outputDeviceUID)
        } catch {
            stop()
            throw error
        }
    }

    deinit {
        stop()
        targetGain.deallocate()
        currentGain.deallocate()
    }

    private func start(processObjects: [AudioObjectID], outputDeviceUID: String) throws {
        let description = CATapDescription(stereoMixdownOfProcesses: processObjects)
        description.uuid = UUID()
        description.name = "Volume Mixer tap"
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped

        var err = AudioHardwareCreateProcessTap(description, &tapID)
        guard err == noErr else { throw TapError.createTap(err) }

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Volume Mixer",
            kAudioAggregateDeviceUIDKey: "VolumeMixer-\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputDeviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputDeviceUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]
        err = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID)
        guard err == noErr else { throw TapError.createAggregate(err) }

        let target = targetGain
        let current = currentGain
        err = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, queue) { _, input, _, output, _ in
            AppAudioTap.render(input: input, output: output, target: target.pointee, current: current)
        }
        guard err == noErr else { throw TapError.createIOProc(err) }

        err = AudioDeviceStart(aggregateID, ioProcID)
        guard err == noErr else { throw TapError.start(err) }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let ioProcID {
                AudioDeviceStop(aggregateID, ioProcID)
                AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        ioProcID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    // MARK: Real-time audio (no allocation, no locks, no Objective-C)

    /// Copies every input channel to the output channels (wrapping if the output has more channels),
    /// applying a linear gain ramp from the previous gain to `target` across the buffer.
    private static func render(
        input: UnsafePointer<AudioBufferList>,
        output: UnsafeMutablePointer<AudioBufferList>,
        target: Float32,
        current: UnsafeMutablePointer<Float32>
    ) {
        let inList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outList = UnsafeMutableAudioBufferListPointer(output)

        var inChannels = 0
        for buffer in inList where buffer.mData != nil { inChannels += Int(buffer.mNumberChannels) }

        let startGain = current.pointee
        var outChannelBase = 0

        for outBuffer in outList {
            guard let outData = outBuffer.mData?.assumingMemoryBound(to: Float32.self) else { continue }
            let outStride = max(Int(outBuffer.mNumberChannels), 1)
            let frames = Int(outBuffer.mDataByteSize) / (MemoryLayout<Float32>.size * outStride)

            guard inChannels > 0, frames > 0 else {
                memset(outBuffer.mData, 0, Int(outBuffer.mDataByteSize))
                outChannelBase += outStride
                continue
            }

            let step = (target - startGain) / Float32(frames)

            for outChannel in 0..<outStride {
                // Find the input buffer/channel feeding this output channel.
                var wanted = (outChannelBase + outChannel) % inChannels
                var source: UnsafeMutablePointer<Float32>?
                var inStride = 1
                var inFrames = 0
                for inBuffer in inList {
                    guard let data = inBuffer.mData else { continue }
                    let channels = Int(inBuffer.mNumberChannels)
                    if wanted < channels {
                        inStride = max(channels, 1)
                        inFrames = Int(inBuffer.mDataByteSize) / (MemoryLayout<Float32>.size * inStride)
                        source = data.assumingMemoryBound(to: Float32.self) + wanted
                        break
                    }
                    wanted -= channels
                }

                var g = startGain
                for frame in 0..<frames {
                    let sample: Float32 = (source != nil && frame < inFrames) ? source![frame * inStride] : 0
                    outData[frame * outStride + outChannel] = sample * g
                    g += step
                }
            }
            outChannelBase += outStride
        }

        current.pointee = target
    }
}
