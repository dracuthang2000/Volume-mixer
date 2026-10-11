import AppKit
import Darwin
import UniformTypeIdentifiers

/// The app a process belongs to, so helper processes (Chrome renderers, Safari's WebKit
/// processes, Electron helpers…) are grouped under one row like the Windows mixer.
struct AppIdentity {
    /// Stable key used for grouping and saved settings: bundle ID when known, otherwise a path.
    let key: String
    let name: String
    let icon: NSImage

    static func resolve(pid: pid_t, bundleID: String?) -> AppIdentity {
        let owner = responsiblePID(for: pid)

        // Prefer the outermost .app bundle that contains the responsible process.
        for candidate in [owner, pid] {
            if let path = executablePath(of: candidate), let appPath = outermostAppBundle(in: path) {
                let bundle = Bundle(path: appPath)
                let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? FileManager.default.displayName(atPath: appPath)
                return AppIdentity(
                    key: bundle?.bundleIdentifier ?? appPath,
                    name: name,
                    icon: sized(NSWorkspace.shared.icon(forFile: appPath))
                )
            }
        }

        if let app = NSRunningApplication(processIdentifier: owner), let name = app.localizedName {
            return AppIdentity(
                key: app.bundleIdentifier ?? "pid:\(owner)",
                name: name,
                icon: sized(app.icon ?? NSWorkspace.shared.icon(for: .application))
            )
        }

        let path = executablePath(of: pid)
        return AppIdentity(
            key: bundleID ?? path ?? "pid:\(pid)",
            name: bundleID ?? path.map { ($0 as NSString).lastPathComponent } ?? "Process \(pid)",
            icon: sized(path.map { NSWorkspace.shared.icon(forFile: $0) } ?? NSWorkspace.shared.icon(for: .unixExecutable))
        )
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func outermostAppBundle(in path: String) -> String? {
        let components = (path as NSString).pathComponents
        guard let index = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        return NSString.path(withComponents: Array(components[...index]))
    }

    private static func sized(_ image: NSImage) -> NSImage {
        image.size = NSSize(width: 32, height: 32)
        return image
    }

    /// XPC helpers (e.g. Safari's `com.apple.WebKit.GPU`) live outside the app bundle; macOS tracks
    /// which app is "responsible" for them. This symbol is not public API, so it is looked up at
    /// runtime and we fall back to the process itself if it is missing.
    private typealias ResponsibleFunction = @convention(c) (pid_t) -> pid_t
    private static let responsibleFunction: ResponsibleFunction? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid")
        else { return nil }
        return unsafeBitCast(symbol, to: ResponsibleFunction.self)
    }()

    private static func responsiblePID(for pid: pid_t) -> pid_t {
        guard let responsibleFunction else { return pid }
        let owner = responsibleFunction(pid)
        return owner > 0 ? owner : pid
    }
}

/// Caches identities per PID; resolving touches the file system and bundle metadata.
struct AppIdentityCache {
    private var byPID: [pid_t: AppIdentity] = [:]

    mutating func identity(for pid: pid_t, bundleID: String?) -> AppIdentity {
        if let cached = byPID[pid] { return cached }
        let identity = AppIdentity.resolve(pid: pid, bundleID: bundleID)
        byPID[pid] = identity
        return identity
    }

    mutating func prune(keeping livePIDs: Set<pid_t>) {
        byPID = byPID.filter { livePIDs.contains($0.key) }
    }
}
