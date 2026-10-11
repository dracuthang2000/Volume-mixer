import AppKit
import CoreAudio

/// One row in the mixer.
struct AppChannel: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: NSImage
    var volume: Double
    var isMuted: Bool
    var isPlaying: Bool
}

@MainActor
final class MixerModel: ObservableObject {
    @Published private(set) var apps: [AppChannel] = []
    @Published private(set) var outputDeviceName = "No output device"
    @Published private(set) var masterVolume: Double = 0
    @Published private(set) var masterMuted = false
    @Published private(set) var canSetMasterVolume = false
    @Published private(set) var lastError: String?

    /// How long an app stays in the list (and keeps its tap) after it stops playing.
    private static let idleGrace: TimeInterval = 20
    /// Wait this long before retrying a tap that failed to start.
    private static let retryDelay: TimeInterval = 10

    private struct ProcessGroup {
        let identity: AppIdentity
        var objects: [AudioObjectID] = []
        var isPlaying = false
    }

    private var taps: [String: AppAudioTap] = [:]
    private var lastPlayed: [String: Date] = [:]
    private var failedAt: [String: Date] = [:]
    private var identities = AppIdentityCache()
    private let settings = AppSettings()
    private let ownPID = getpid()
    private var outputDevice = AudioObjectID(kAudioObjectUnknown)
    private var outputUID: String?
    private var timer: Timer?

    init() {
        updateOutputDevice()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        CA.addSystemListener(kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in
            MainActor.assumeIsolated { self?.outputDeviceChanged() }
        }
    }

    func shutdown() {
        timer?.invalidate()
        removeAllTaps()
    }

    // MARK: User actions

    func setVolume(_ volume: Double, for id: String) {
        settings.setVolume(volume, for: id)
        update(id) { $0.volume = volume }
        applySetting(for: id)
    }

    func toggleMute(for id: String) {
        settings.setMuted(!settings.isMuted(id), for: id)
        update(id) { $0.isMuted = settings.isMuted(id) }
        applySetting(for: id)
    }

    func setMasterVolume(_ volume: Double) {
        SystemVolume.setVolume(volume, on: outputDevice)
        masterVolume = volume
        if masterMuted, volume > 0 { toggleMasterMute() }
    }

    func toggleMasterMute() {
        SystemVolume.setMuted(!masterMuted, on: outputDevice)
        masterMuted = SystemVolume.isMuted(outputDevice) ?? false
    }

    // MARK: Polling

    /// Re-reads which processes are using audio, regroups them by app and starts/stops taps.
    func refresh() {
        let now = Date()
        var groups: [String: ProcessGroup] = [:]
        var livePIDs = Set<pid_t>()

        for object in CA.processObjectList() {
            let pid = CA.processPID(object)
            guard pid > 0, pid != ownPID else { continue }
            livePIDs.insert(pid)
            let identity = identities.identity(for: pid, bundleID: CA.processBundleID(object))
            groups[identity.key, default: ProcessGroup(identity: identity)].objects.append(object)
            if CA.processIsRunningOutput(object) { groups[identity.key]?.isPlaying = true }
        }
        identities.prune(keeping: livePIDs)

        for (key, group) in groups where group.isPlaying { lastPlayed[key] = now }
        lastPlayed = lastPlayed.filter { groups[$0.key] != nil }

        syncTaps(with: groups, now: now)

        let visible = groups.values.filter { recentlyPlayed($0.identity.key, now: now) }
        let newApps = visible
            .map { group in
                AppChannel(
                    id: group.identity.key,
                    name: group.identity.name,
                    icon: group.identity.icon,
                    volume: settings.volume(for: group.identity.key),
                    isMuted: settings.isMuted(group.identity.key),
                    isPlaying: group.isPlaying
                )
            }
            .sorted { ($0.name.localizedLowercase, $0.id) < ($1.name.localizedLowercase, $1.id) }
        if newApps != apps { apps = newApps }

        refreshMaster()
    }

    // MARK: Taps

    private func needsTap(_ key: String) -> Bool {
        settings.isMuted(key) || settings.volume(for: key) < 0.995
    }

    /// Slider position → amplitude. Squaring gives a more natural (perceptual) feel than linear.
    private func gain(for key: String) -> Float32 {
        settings.isMuted(key) ? 0 : Float32(pow(settings.volume(for: key), 2))
    }

    private func recentlyPlayed(_ key: String, now: Date) -> Bool {
        lastPlayed[key].map { now.timeIntervalSince($0) < Self.idleGrace } ?? false
    }

    private func syncTaps(with groups: [String: ProcessGroup], now: Date) {
        // Remove taps that are no longer needed, idle too long, or whose process set changed.
        for (key, tap) in taps {
            guard let group = groups[key], needsTap(key), recentlyPlayed(key, now: now),
                  Set(group.objects) == tap.processObjects
            else {
                tap.stop()
                taps[key] = nil
                continue
            }
        }

        guard let outputUID else { return }
        for (key, group) in groups where group.isPlaying && needsTap(key) && taps[key] == nil {
            if let failed = failedAt[key], now.timeIntervalSince(failed) < Self.retryDelay { continue }
            do {
                taps[key] = try AppAudioTap(processObjects: group.objects, outputDeviceUID: outputUID, gain: gain(for: key))
                failedAt[key] = nil
                lastError = nil
            } catch {
                failedAt[key] = now
                lastError = "\(group.identity.name): \(error.localizedDescription)"
            }
        }
    }

    private func applySetting(for key: String) {
        if let tap = taps[key] {
            if needsTap(key) {
                tap.gain = gain(for: key)
            } else {
                tap.stop()
                taps[key] = nil
            }
        } else if needsTap(key) {
            failedAt[key] = nil
            refresh()
        }
    }

    private func removeAllTaps() {
        for tap in taps.values { tap.stop() }
        taps.removeAll()
    }

    private func update(_ id: String, _ change: (inout AppChannel) -> Void) {
        if let index = apps.firstIndex(where: { $0.id == id }) { change(&apps[index]) }
    }

    // MARK: Output device

    private func outputDeviceChanged() {
        // Taps are bound to the old speakers; rebuild them on the new default device.
        removeAllTaps()
        failedAt.removeAll()
        updateOutputDevice()
        refresh()
    }

    private func updateOutputDevice() {
        outputDevice = CA.defaultOutputDevice()
        outputUID = CA.deviceUID(outputDevice)
        outputDeviceName = CA.deviceName(outputDevice) ?? "No output device"
        refreshMaster()
    }

    private func refreshMaster() {
        let settable = SystemVolume.canSetVolume(outputDevice)
        if settable != canSetMasterVolume { canSetMasterVolume = settable }
        let volume = SystemVolume.volume(outputDevice) ?? 0
        if abs(volume - masterVolume) > 0.001 { masterVolume = volume }
        let muted = SystemVolume.isMuted(outputDevice) ?? false
        if muted != masterMuted { masterMuted = muted }
    }
}
