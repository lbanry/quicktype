import AppKit
import SwiftUI

private struct VisualEffectSurface: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let emphasized: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.isEmphasized = emphasized
        view.material = material
        view.blendingMode = blendingMode
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = emphasized
        nsView.state = .active
    }
}

struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                backgroundSurface
            )
    }

    @ViewBuilder
    private var backgroundSurface: some View {
        if #available(macOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.04),
                            Color.clear,
                            Color.black.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            ZStack {
                VisualEffectSurface(
                    material: .underWindowBackground,
                    blendingMode: .behindWindow,
                    emphasized: true
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        Color.clear,
                        Color.black.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        content
            .background(cardBackground(shape: shape))
            .overlay(
                shape
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 10)
    }

    @ViewBuilder
    private func cardBackground(shape: RoundedRectangle) -> some View {
        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(in: shape)
        } else {
            ZStack {
                VisualEffectSurface(
                    material: .hudWindow,
                    blendingMode: .withinWindow,
                    emphasized: false
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(shape)
        }
    }
}

struct GlassControl: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(controlBackground(shape: shape))
            .overlay(
                shape
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func controlBackground(shape: RoundedRectangle) -> some View {
        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(in: shape)
        } else {
            ZStack {
                VisualEffectSurface(
                    material: .menu,
                    blendingMode: .withinWindow,
                    emphasized: false
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(shape)
        }
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }

    func glassCard() -> some View {
        modifier(GlassCard())
    }

    func glassControl() -> some View {
        modifier(GlassControl())
    }
}
