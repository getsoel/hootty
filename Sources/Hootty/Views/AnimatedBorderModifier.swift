import SwiftUI

/// Static colored border with a pulsing outer glow (shadow).
///
/// Two overlay layers: a blurred glow stroke that pulses opacity,
/// and a sharp solid stroke on top for a clear boundary.
///
/// Usage:
///     myView.glowBorder(shape: Rectangle(), color: .pink)
///
struct GlowBorderModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let color: Color
    let lineWidth: CGFloat
    let glowRadius: CGFloat

    @State private var isPulsing = false

    func body(content: Content) -> some View {
        let inset = shape.inset(by: lineWidth / 2)
        content
            .overlay {
                inset
                    .stroke(color, lineWidth: lineWidth)
                    .shadow(color: color.opacity(isPulsing ? 0.8 : 0.3), radius: glowRadius)
            }
            .overlay {
                inset
                    .stroke(color, lineWidth: lineWidth)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    /// Adds a static colored border with a pulsing outer glow.
    ///
    /// - Parameters:
    ///   - shape: The shape to stroke (e.g., `Rectangle()`).
    ///   - color: Border and glow color.
    ///   - lineWidth: Border thickness. Defaults to 2.
    ///   - glowRadius: Shadow blur radius. Defaults to 6.
    func glowBorder<S: InsettableShape>(
        shape: S,
        color: Color,
        lineWidth: CGFloat = 2,
        glowRadius: CGFloat = 6
    ) -> some View {
        modifier(GlowBorderModifier(
            shape: shape,
            color: color,
            lineWidth: lineWidth,
            glowRadius: glowRadius
        ))
    }
}
