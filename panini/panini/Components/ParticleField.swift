import SwiftUI
import UIKit

// MARK: - ParticleLayer

private enum ParticleLayer { case burst, fountain, mote }

// MARK: - RevealParticle

private struct RevealParticle {
    let id: Int
    let layer: ParticleLayer
    let origin: CGPoint
    let velocity: CGPoint       // pt/s  (negative y = upward)
    let birthDate: Date
    let lifetime: Double
    let size: CGFloat
    let initialRotation: Double // degrees
    let spin: Double            // degrees/s
    let color: Color
    // Mote-only: horizontal sine-wave drift
    let sineAmplitude: CGFloat
    let sineFrequency: Double   // Hz
    let sinePhase: Double       // radians
}

// MARK: - ParticleField

/// Three-layer legendary particle system.
///
/// - Burst    — 150 fast diamonds from card centre, one-shot, lifetime ~1s
/// - Fountain — 120 small glints from card bottom, staggered over 4 s, drift upward
/// - Motes    — 18 ambient hovering dots near the card, slow sine-wave drift, lifetime ~4 s
///
/// All particles are pre-generated with staggered `birthDate`s so no continuous
/// emission loop is needed — the Canvas simply skips particles not yet born or dead.
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
                    guard elapsed > 0, elapsed < p.lifetime else { continue }

                    let progress = elapsed / p.lifetime
                    let alpha: CGFloat
                    let x: CGFloat
                    let y: CGFloat

                    switch p.layer {
                    case .burst:
                        // Fast outward, gravity 200 pt/s², fade out in the last 30 %
                        alpha = progress < 0.70 ? 1.0
                              : CGFloat(1 - (progress - 0.70) / 0.30)
                        x = p.origin.x + p.velocity.x * CGFloat(elapsed)
                        y = p.origin.y + p.velocity.y * CGFloat(elapsed)
                              + 0.5 * 200 * CGFloat(elapsed * elapsed)

                    case .fountain:
                        // Slow upward with no gravity; quadratic fade
                        alpha = CGFloat((1 - progress) * (1 - progress))
                        x = p.origin.x + p.velocity.x * CGFloat(elapsed)
                        y = p.origin.y + p.velocity.y * CGFloat(elapsed) // negative = up

                    case .mote:
                        // Sine-wave horizontal hover, slow upward drift, fade in + out
                        let fadeIn  = min(1.0, progress / 0.20)
                        let fadeOut = max(0.0, 1.0 - (progress - 0.80) / 0.20)
                        alpha = CGFloat(min(fadeIn, fadeOut))
                        x = p.origin.x
                              + sin(elapsed * p.sineFrequency + p.sinePhase) * p.sineAmplitude
                        y = p.origin.y + p.velocity.y * CGFloat(elapsed)
                    }

                    let deg = p.initialRotation + p.spin * elapsed
                    var gctx = ctx
                    gctx.translateBy(x: x, y: y)
                    gctx.rotate(by: .degrees(deg))
                    gctx.opacity = alpha

                    // Diamond shape centred at origin
                    let h = p.size / 2
                    var shape = Path()
                    shape.move(to:    CGPoint(x:  0,  y: -h))
                    shape.addLine(to: CGPoint(x:  h,  y:  0))
                    shape.addLine(to: CGPoint(x:  0,  y:  h))
                    shape.addLine(to: CGPoint(x: -h,  y:  0))
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

    // MARK: - Spawn

    private func spawn() {
        let screen     = UIScreen.main.bounds
        let cardCenter = CGPoint(x: screen.width / 2, y: screen.height * 0.38)
        // Card is 200 wide → 280 tall; bottom edge ≈ centre + 140
        let cardBottom = CGPoint(x: screen.width / 2, y: cardCenter.y + 140)

        var all: [RevealParticle] = []
        let now = Date()

        // ── Layer 1: Burst ────────────────────────────────────────────────
        for i in 0..<150 {
            let angle = Double.random(in: -.pi ... .pi)
            let speed = CGFloat.random(in: 300...700)
            all.append(RevealParticle(
                id: i, layer: .burst,
                origin: cardCenter,
                velocity: CGPoint(x: cos(angle) * speed,
                                  y: sin(angle) * speed - 60),   // slight upward bias
                birthDate: now,
                lifetime: Double.random(in: 0.6...1.2),
                size: CGFloat.random(in: 4...10),
                initialRotation: Double.random(in: 0...360),
                spin: Double.random(in: -240...240),
                color: colors[i % colors.count],
                sineAmplitude: 0, sineFrequency: 0, sinePhase: 0
            ))
        }

        // ── Layer 2: Fountain ─────────────────────────────────────────────
        // 120 glints staggered over 4 s (30 per second)
        for i in 0..<120 {
            let delay = Double(i) / 30.0
            all.append(RevealParticle(
                id: 150 + i, layer: .fountain,
                origin: CGPoint(
                    x: cardBottom.x + CGFloat.random(in: -80...80),
                    y: cardBottom.y
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -40...40),
                    y: -CGFloat.random(in: 80...160)              // upward
                ),
                birthDate: now.addingTimeInterval(delay),
                lifetime: Double.random(in: 1.5...2.5),
                size: CGFloat.random(in: 2...4),
                initialRotation: Double.random(in: 0...360),
                spin: Double.random(in: -180...180),
                color: colors[(150 + i) % colors.count],
                sineAmplitude: 0, sineFrequency: 0, sinePhase: 0
            ))
        }

        // ── Layer 3: Motes ────────────────────────────────────────────────
        // 18 ambient hovering dots, staggered over 6 s (3 per second)
        let moteColors: [Color] = [
            Color(hex: "F0E8FF").opacity(0.85),
            Color.white.opacity(0.75),
        ]
        for i in 0..<18 {
            let delay = Double(i) / 3.0
            all.append(RevealParticle(
                id: 270 + i, layer: .mote,
                origin: CGPoint(
                    x: cardCenter.x + CGFloat.random(in: -120...120),
                    y: cardCenter.y + CGFloat.random(in: -160...110)
                ),
                velocity: CGPoint(x: 0, y: -CGFloat.random(in: 4...10)), // very slow up
                birthDate: now.addingTimeInterval(delay),
                lifetime: Double.random(in: 3.5...5.0),
                size: CGFloat.random(in: 1.0...2.5),
                initialRotation: 0, spin: 0,
                color: moteColors[i % moteColors.count],
                sineAmplitude: CGFloat.random(in: 6...14),
                sineFrequency: Double.random(in: 0.20...0.40),
                sinePhase: Double.random(in: 0...(2 * .pi))
            ))
        }

        particles = all
    }
}
