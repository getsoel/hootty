import SwiftUI

/// Animated border that sweeps a gradient around the perimeter of a shape.
///
/// Usage:
///     RoundedRectangle(cornerRadius: 8)
///         .fill(.black)
///         .animatedBorder(shape: RoundedRectangle(cornerRadius: 8), colors: [.blue, .purple, .pink])
///
///     // Or with defaults:
///     myView.animatedBorder(shape: Circle())
///
struct AnimatedBorderModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let colors: [Color]
    let lineWidth: CGFloat
    let duration: Double
    let glowRadius: CGFloat?

    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if let glowRadius {
                    insetShape
                        .stroke(gradient, lineWidth: lineWidth)
                        .blur(radius: glowRadius)
                }
            }
            .overlay {
                insetShape
                    .stroke(gradient, lineWidth: lineWidth)
            }
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }

    private var insetShape: some Shape {
        shape.inset(by: lineWidth / 2)
    }

    private var gradient: AngularGradient {
        AngularGradient(
            colors: colors + [colors[0]],
            center: .center,
            angle: .degrees(rotation)
        )
    }
}

/// Animated border showing only a short segment sweeping around the perimeter.
///
/// Uses `trim(from:to:)` to parameterize the shape's perimeter linearly,
/// giving constant speed regardless of shape (no speed-up at corners).
///
/// Usage:
///     myView.animatedBorderSegment(shape: RoundedRectangle(cornerRadius: 8))
///
struct AnimatedBorderSegmentModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let color: Color
    let lineWidth: CGFloat
    let segmentLength: CGFloat
    let duration: Double
    let glowRadius: CGFloat?

    /// Number of slices per snake. More slices = smoother gradient.
    private let sliceCount = 16

    func body(content: Content) -> some View {
        content
            .overlay {
                TimelineView(.animation) { context in
                    let phase = (context.date.timeIntervalSinceReferenceDate / duration)
                        .truncatingRemainder(dividingBy: 1.0)
                    let inset = shape.inset(by: lineWidth / 2)

                    ZStack {
                        if let glowRadius {
                            snakeSlices(shape: inset, phase: phase)
                                .blur(radius: glowRadius)
                        }
                        snakeSlices(shape: inset, phase: phase)
                    }
                }
            }
    }

    /// Draws two snakes (180° apart on perimeter), each fading in from the
    /// leading edge, solid in the middle, and fading out at the trailing edge.
    private func snakeSlices<T: Shape>(shape: T, phase: Double) -> some View {
        let sliceLength = segmentLength / Double(sliceCount)
        return ZStack {
            ForEach(0..<2, id: \.self) { snakeIndex in
                let snakeOffset = Double(snakeIndex) * 0.5
                let center = (phase + snakeOffset).truncatingRemainder(dividingBy: 1.0)
                ForEach(0..<sliceCount, id: \.self) { i in
                    // Map slice index to -1...1 (tail to head), 0 = center
                    let t = (Double(i) + 0.5) / Double(sliceCount) * 2.0 - 1.0
                    // Symmetric fade: 1.0 at center (t=0), 0.0 at edges (|t|=1)
                    let opacity = 1.0 - t * t
                    let sliceStart = center - segmentLength / 2.0 + Double(i) * sliceLength
                    trimmedStroke(shape: shape, from: sliceStart, to: sliceStart + sliceLength)
                        .opacity(opacity)
                }
            }
        }
    }

    /// Strokes a trim segment, wrapping around 0/1 boundary.
    private func trimmedStroke<T: Shape>(shape: T, from: Double, to: Double) -> some View {
        let normFrom = from - floor(from)
        let normTo = to - floor(to)

        return ZStack {
            if normFrom < normTo {
                shape.trim(from: normFrom, to: normTo)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            } else {
                shape.trim(from: normFrom, to: 1.0)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                shape.trim(from: 0.0, to: normTo)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }
        }
    }
}

extension View {
    /// Adds a continuously rotating gradient border.
    ///
    /// - Parameters:
    ///   - shape: The shape to stroke (e.g., `RoundedRectangle(cornerRadius: 8)`).
    ///   - colors: Gradient colors. Defaults to blue-purple-pink.
    ///   - lineWidth: Border thickness. Defaults to 2.
    ///   - duration: Seconds per full rotation. Defaults to 2.
    ///   - glowRadius: Optional blur radius for a glow layer behind the border.
    func animatedBorder<S: InsettableShape>(
        shape: S,
        colors: [Color] = [.blue, .purple, .pink],
        lineWidth: CGFloat = 2,
        duration: Double = 2,
        glowRadius: CGFloat? = nil
    ) -> some View {
        modifier(AnimatedBorderModifier(
            shape: shape,
            colors: colors,
            lineWidth: lineWidth,
            duration: duration,
            glowRadius: glowRadius
        ))
    }

    /// Adds a short segment that sweeps continuously around the border.
    ///
    /// - Parameters:
    ///   - shape: The shape to stroke.
    ///   - color: Segment color. Defaults to blue.
    ///   - lineWidth: Border thickness. Defaults to 2.
    ///   - segmentLength: Fraction of the perimeter visible (0-1). Defaults to 0.3.
    ///   - duration: Seconds per full loop. Defaults to 2.
    ///   - glowRadius: Optional blur radius for a glow layer behind the segment.
    func animatedBorderSegment<S: InsettableShape>(
        shape: S,
        color: Color = .blue,
        lineWidth: CGFloat = 2,
        segmentLength: CGFloat = 0.3,
        duration: Double = 2,
        glowRadius: CGFloat? = nil
    ) -> some View {
        modifier(AnimatedBorderSegmentModifier(
            shape: shape,
            color: color,
            lineWidth: lineWidth,
            segmentLength: segmentLength,
            duration: duration,
            glowRadius: glowRadius
        ))
    }
}
