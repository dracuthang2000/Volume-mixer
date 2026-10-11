import SwiftUI

struct MixerView: View {
    @ObservedObject var model: MixerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.outputDeviceName, systemImage: "hifispeaker.fill")
                .font(.headline)
                .lineLimit(1)

            VolumeRow(
                icon: Image(systemName: "speaker.wave.3.fill"),
                name: "System",
                volume: model.masterVolume,
                isMuted: model.masterMuted,
                isPlaying: false,
                isEnabled: model.canSetMasterVolume,
                onVolume: model.setMasterVolume,
                onMute: model.toggleMasterMute
            )

            Divider()

            Text("Applications")
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.apps.isEmpty {
                Text("No apps are playing audio.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 40)
            } else if model.apps.count > 6 {
                ScrollView { appRows }.frame(height: 360)
            } else {
                appRows
            }

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button("Sound Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(HoverButtonStyle())
            // Buttons have inner padding for their highlight; pull them back so the text
            // stays aligned with the rest of the window.
            .padding(.horizontal, -8)
        }
        .padding(14)
        .frame(width: 340)
    }

    private var appRows: some View {
        VStack(spacing: 2) {
            ForEach(model.apps) { app in
                VolumeRow(
                    icon: Image(nsImage: app.icon),
                    name: app.name,
                    volume: app.volume,
                    isMuted: app.isMuted,
                    isPlaying: app.isPlaying,
                    isEnabled: true,
                    onVolume: { model.setVolume($0, for: app.id) },
                    onMute: { model.toggleMute(for: app.id) }
                )
            }
        }
    }
}

/// A plain text button that gets a rounded highlight on hover and a stronger one while pressed,
/// matching the row highlight in `VolumeRow`.
struct HoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverButton(configuration: configuration)
    }

    private struct HoverButton: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(fill)
                )
                .contentShape(Rectangle())
                .onHover { isHovered = $0 && isEnabled }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }

        private var fill: Color {
            if configuration.isPressed { return Color.accentColor.opacity(0.3) }
            if isHovered { return Color.primary.opacity(0.08) }
            return .clear
        }
    }
}

struct VolumeRow: View {
    let icon: Image
    let name: String
    let volume: Double
    let isMuted: Bool
    let isPlaying: Bool
    let isEnabled: Bool
    let onVolume: (Double) -> Void
    let onMute: () -> Void

    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 10) {
            icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(name).lineLimit(1)
                    if isPlaying {
                        Circle().fill(.green).frame(width: 6, height: 6)
                    }
                }
                .font(.subheadline)

                HStack(spacing: 6) {
                    Button(action: onMute) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .frame(width: 18)
                            .foregroundStyle(isMuted ? .red : .primary)
                    }
                    .buttonStyle(.borderless)
                    .help(isMuted ? "Unmute" : "Mute")

                    Slider(value: Binding(get: { volume }, set: onVolume), in: 0...1) { editing in
                        isDragging = editing
                    }
                    .controlSize(.small)

                    Text("\(Int((volume * 100).rounded()))")
                        .font(.caption.monospacedDigit())
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .opacity(isMuted ? 0.6 : 1)
        // Highlight the row being hovered, and more strongly the one being adjusted.
        // The negative outer padding lets the highlight extend into the margin while the
        // row's content stays aligned with the headers.
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(highlightColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(isDragging ? 0.6 : 0), lineWidth: 1)
        )
        .padding(.horizontal, -6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 && isEnabled }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isDragging)
        .disabled(!isEnabled)
    }

    private var highlightColor: Color {
        if isDragging { return Color.accentColor.opacity(0.2) }
        if isHovered { return Color.primary.opacity(0.07) }
        return .clear
    }
}
