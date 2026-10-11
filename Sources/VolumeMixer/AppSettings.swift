import Foundation

/// Remembers each app's volume and mute between launches (keyed by `AppIdentity.key`).
struct AppSettings {
    private let defaults = UserDefaults.standard
    private let volumesKey = "appVolumes"
    private let mutesKey = "appMutes"

    func volume(for key: String) -> Double {
        (defaults.dictionary(forKey: volumesKey)?[key] as? Double) ?? 1
    }

    func isMuted(_ key: String) -> Bool {
        (defaults.dictionary(forKey: mutesKey)?[key] as? Bool) ?? false
    }

    func setVolume(_ volume: Double, for key: String) {
        var all = defaults.dictionary(forKey: volumesKey) ?? [:]
        all[key] = volume >= 0.995 ? nil : volume
        defaults.set(all, forKey: volumesKey)
    }

    func setMuted(_ muted: Bool, for key: String) {
        var all = defaults.dictionary(forKey: mutesKey) ?? [:]
        all[key] = muted ? true : nil
        defaults.set(all, forKey: mutesKey)
    }
}
