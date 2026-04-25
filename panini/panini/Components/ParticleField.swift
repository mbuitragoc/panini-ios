import SwiftUI
import UIKit

// MARK: - RevealParticle

private struct RevealParticle {
    let id: Int
    let origin: CGPoint
    let velocity: CGPoint    // pt/s
    let birthDate: Date
    let lifetime: Double     // seconds
    let size: CGFloat
    let initialRotation: Double  // degrees
    let spin: Double             // degrees/s
    let color: Color
}

// MARK: - ParticleField

/// Canvas-based particle burst used for the legendary sticker reveal.
/// Spawns once when `isActive` flips to true, then fades naturally.
struct ParticleField: View {
    let colors: [Color]
    @Binding var isActive: Bool

    @State private var particles: [RevealParticle] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, _ in
                let now = timeline.date
                for p in particles {
                    let elapsed = now.timeIntervalSince(p.birthDate)
                    guard elapsed < p.lifetime else { continue }

                    let progress  = elapsed / p.lifetime
                    let alpha     = CGFloat((1 - progress) * (1 - progress)) // quadratic fade

                    let x = p.origin.x + p.velocity.x * CGFloat(elapsed)
                    // Gravity: 160 pt/s² pulling down
                    let y = p.origin.y + p.velocity.y * CGFloat(elapsed)
                              + 0.5 * 160 * CGFloat(elapsed * elapsed)
                    let deg = p.initialRotation + p.spin * elapsed

                    var gctx = ctx
                    gctx.translateBy(x: x, y: y)
                    gctx.rotate(by: .degrees(deg))
                    gctx.opacity = alpha

                    // Diamond shape centered at origin
                    let h = p.size / 2
                    var shape = Path()
                    shape.move(to: CGPoint(x: 0,  y: -h))
                    shape.addLine(to: CGPoint(x: h,  y: 0))
                    shape.addLine(to: CGPoint(x: 0,  y: h))
                    shape.addLine(to: CGPoint(x: -h, y: 0))
                    shape.closeSubpath()

                    gctx.fill(shape, with: .color(p.color))
                }
            }
        }
        .onChange(of: isActive) { _, active in
            if active { spawn() }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func spawn(count: Int = 80) {
        let screen = UIScreen.main.bounds
        // Cards sit roughly at 38% from top in the reveal layout
        let origin = CGPoint(x: screen.width / 2, y: screen.height * 0.38)

        particles = (0..<count).map { i in
            let angle  = Double.random(in: -.pi ... .pi)
            let speed  = CGFloat.random(in: 60...260)
            let color  = colors[i % colors.count]
            return RevealParticle(
                id: i,
                origin: origin,
                velocity: CGPoint(
                    x: cos(angle) * speed,
                    y: sin(angle) * speed - 80   // slight upward bias
                ),
                birthDate: .now,
                lifetime: Double.random(in: 0.8...1.8),
                size: CGFloat.random(in: 4...10),
                initialRotation: Double.random(in: 0...360),
                spin: Double.random(in: -240...240),
                color: color
            )
        }
    }
}
