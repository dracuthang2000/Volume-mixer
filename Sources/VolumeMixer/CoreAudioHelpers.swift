import AudioToolbox
import CoreAudio
import Foundation

/// Thin wrappers around the C Core Audio property API.
enum CA {
    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func get<T: BitwiseCopyable>(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        initial: T
    ) -> T? {
        var addr = address(selector, scope: scope)
        guard AudioObjectHasProperty(object, &addr) else { return nil }
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let err = AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value)
        return err == noErr ? value : nil
    }

    @discardableResult
    static func set<T: BitwiseCopyable>(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        _ value: T
    ) -> Bool {
        var addr = address(selector, scope: scope)
        var value = value
        let size = UInt32(MemoryLayout<T>.size)
        return AudioObjectSetPropertyData(object, &addr, 0, nil, size, &value) == noErr
    }

    static func isSettable(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> Bool {
        var addr = address(selector, scope: scope)
        guard AudioObjectHasProperty(object, &addr) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(object, &addr, &settable) == noErr && settable.boolValue
    }

    static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        guard AudioObjectHasProperty(object, &addr) else { return nil }
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    static func objectIDs(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
        var addr = address(selector)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.stride)
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.stride))
    }

    /// Calls `handler` on the main queue whenever a property of the system object changes.
    static func addSystemListener(_ selector: AudioObjectPropertySelector, handler: @escaping () -> Void) {
        var addr = address(selector)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main) { _, _ in
            handler()
        }
    }

    // MARK: Devices

    static func defaultOutputDevice() -> AudioObjectID {
        get(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice,
            initial: AudioObjectID(kAudioObjectUnknown)) ?? AudioObjectID(kAudioObjectUnknown)
    }

    static func deviceUID(_ device: AudioObjectID) -> String? {
        string(device, kAudioDevicePropertyDeviceUID)
    }

    static func deviceName(_ device: AudioObjectID) -> String? {
        string(device, kAudioObjectPropertyName)
    }

    // MARK: Processes (macOS 14.2+)

    static func processObjectList() -> [AudioObjectID] {
        objectIDs(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList)
    }

    static func processPID(_ process: AudioObjectID) -> pid_t {
        get(process, kAudioProcessPropertyPID, initial: pid_t(-1)) ?? -1
    }

    static func processBundleID(_ process: AudioObjectID) -> String? {
        string(process, kAudioProcessPropertyBundleID).flatMap { $0.isEmpty ? nil : $0 }
    }

    static func processIsRunningOutput(_ process: AudioObjectID) -> Bool {
        (get(process, kAudioProcessPropertyIsRunningOutput, initial: UInt32(0)) ?? 0) != 0
    }
}

/// The output device's own volume and mute: the "System" row, like the master slider on Windows.
enum SystemVolume {
    private static let volumeSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
    private static let outputScope = kAudioDevicePropertyScopeOutput

    static func canSetVolume(_ device: AudioObjectID) -> Bool {
        CA.isSettable(device, volumeSelector, scope: outputScope)
    }

    static func volume(_ device: AudioObjectID) -> Double? {
        CA.get(device, volumeSelector, scope: outputScope, initial: Float32(0)).map(Double.init)
    }

    static func setVolume(_ volume: Double, on device: AudioObjectID) {
        CA.set(device, volumeSelector, scope: outputScope, Float32(min(max(volume, 0), 1)))
    }

    static func isMuted(_ device: AudioObjectID) -> Bool? {
        CA.get(device, kAudioDevicePropertyMute, scope: outputScope, initial: UInt32(0)).map { $0 != 0 }
    }

    static func setMuted(_ muted: Bool, on device: AudioObjectID) {
        CA.set(device, kAudioDevicePropertyMute, scope: outputScope, UInt32(muted ? 1 : 0))
    }
}
