import SwiftUI
import VisionKit
import SwiftData

// MARK: - Scan mode

enum ScanMode: String, CaseIterable {
    case back  = "Back"
    case front = "Front"
    case both  = "Both"
}

// MARK: - ScanView

struct ScanView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context

    @State private var mode: ScanMode = .back
    @State private var pending: String? = nil
    @State private var hintMessage: String? = nil
    @State private var showManualAdd = false
    @State private var scanPulse = false
    @State private var knownTeams: Set<String> = []
    @State private var resumeToken: Bool = false
    @State private var scannerActive: Bool = true

    var body: some View {
        ZStack {
            // Camera fills entire screen including under nav/tab bars.
            scannerLayer.ignoresSafeArea()
            // Overlay is constrained by safe area so controls sit above the tab bar.
            overlayLayer
        }
        .sheet(item: Binding(
            get: { pending.map { ScanMatch(id: $0) } },
            set: { pending = $0?.id }
        ), onDismiss: {
            // Flip the token so updateUIViewController fires, restarting the scanner
            // and resetting the throttle so the same sticker doesn't re-fire instantly.
            resumeToken.toggle()
        }) { match in
            ScanConfirmView(stickerID: match.id)
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Button {
                        resumeToken.toggle()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    Button { showManualAdd = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
        }
        .sheet(isPresented: $showManualAdd) { ManualAddView() }
        .task {
            let stickers = (try? context.fetch(FetchDescriptor<Sticker>())) ?? []
            knownTeams = Set(stickers.map { $0.countryCode })
        }
    }

    // MARK: - Scanner layer

    @ViewBuilder
    private var scannerLayer: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            DataScannerRepresentable(
                mode: mode,
                knownTeams: knownTeams,
                resumeToken: resumeToken,
                onMatch: { id in
                    guard pending == nil else { return }
                    hintMessage = nil
                    pending = id
                },
                onHint: { msg in hintMessage = msg },
                onStatusChange: { active in scannerActive = active }
            )
        } else {
            unsupportedPlaceholder
        }
    }

    @ViewBuilder
    private var unsupportedPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.inkMuted)
            Text("Camera scanning not available on this device.")
                .bodyStyle(size: 15)
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
    }

    // MARK: - Overlay layer

    @ViewBuilder
    private var overlayLayer: some View {
        VStack(spacing: 0) {
            HStack {
                scannerStatusPill
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            if let hint = hintMessage {
                Text(hint)
                    .bodyStyle(size: 14, weight: .medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            viewfinderFrame

            Spacer()

            VStack(spacing: 10) {
                Text("POINT AT THE \(mode == .front ? "FRONT" : "BACK") OF THE STICKER")
                    .monoStyle(size: 10)
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(1.5)
                modeToggle
            }
            .padding(.bottom, 12)
        }
        .animation(.easeInOut(duration: 0.25), value: hintMessage)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                scanPulse = true
            }
        }
    }

    private var scannerStatusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(scannerActive ? Color.green : Color.red)
                .frame(width: 7, height: 7)
                .opacity(scannerActive ? (scanPulse ? 1.0 : 0.45) : 1.0)
            Text(scannerActive ? "LIVE" : "STOPPED")
                .monoStyle(size: 9)
                .foregroundStyle(.white)
                .tracking(1.2)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.black.opacity(0.5), in: Capsule())
        .animation(.easeInOut(duration: 0.3), value: scannerActive)
    }

    private var viewfinderFrame: some View {
        ScannerCornerBrackets(armLength: 28)
            .stroke(theme.primary,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: 240, height: 178)
            .scaleEffect(scanPulse ? 1.04 : 1.0)
            .opacity(scanPulse ? 1.0 : 0.45)
    }

    private var modeToggle: some View {
        Picker("Scan mode", selection: $mode) {
            ForEach(ScanMode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 240)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - ScannerCornerBrackets Shape

private struct ScannerCornerBrackets: Shape {
    let armLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let a = armLength
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + a))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + a, y: rect.minY))

        p.move(to: CGPoint(x: rect.maxX - a, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + a))

        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - a))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - a, y: rect.maxY))

        p.move(to: CGPoint(x: rect.minX + a, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - a))
        return p
    }
}

// MARK: - ScanMatch

private struct ScanMatch: Identifiable {
    let id: String
}

// MARK: - DataScannerRepresentable

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let mode: ScanMode
    let knownTeams: Set<String>
    let resumeToken: Bool
    let onMatch: (String) -> Void
    let onHint: (String?) -> Void
    let onStatusChange: (Bool) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: false  // We draw our own highlight on matches.
        )
        vc.delegate = context.coordinator
        context.coordinator.scanner = vc
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        let c = context.coordinator
        c.onMatch = onMatch
        c.onHint = onHint
        c.onStatusChange = onStatusChange
        c.knownTeams = knownTeams
        c.mode = mode
        if c.lastResumeToken != resumeToken {
            c.lastResumeToken = resumeToken
            c.resetAfterDismiss()
            if !vc.isScanning { try? vc.startScanning() }
        }
        onStatusChange(vc.isScanning)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode, knownTeams: knownTeams, onMatch: onMatch, onHint: onHint)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var mode: ScanMode
        var knownTeams: Set<String>
        var onMatch: (String) -> Void
        var onHint: (String?) -> Void
        var onStatusChange: (Bool) -> Void = { _ in }
        weak var scanner: DataScannerViewController?
        var lastResumeToken: Bool = false

        private var lastFiredAt: Date = .distantPast
        private var isPendingMatch = false
        private var glowView: UIView?

        func resetAfterDismiss() {
            isPendingMatch = false
            removeGlow()
            // Give the user 1.5 s to move the camera before the throttle reopens,
            // preventing the same sticker from immediately re-triggering the sheet.
            lastFiredAt = Date(timeIntervalSinceNow: 1.0)
        }

        init(mode: ScanMode, knownTeams: Set<String>,
             onMatch: @escaping (String) -> Void,
             onHint: @escaping (String?) -> Void) {
            self.mode = mode
            self.knownTeams = knownTeams
            self.onMatch = onMatch
            self.onHint = onHint
        }

        func dataScanner(_ scanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            self.scanner = scanner
            throttle(allItems: allItems, scanner: scanner)
        }

        func dataScanner(_ scanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            throttle(allItems: allItems, scanner: scanner)
        }

        private func throttle(allItems: [RecognizedItem], scanner: DataScannerViewController) {
            guard !isPendingMatch else { return }
            guard Date().timeIntervalSince(lastFiredAt) > 0.5 else { return }
            lastFiredAt = Date()
            fire(allItems: allItems, scanner: scanner)
        }

        private func fire(allItems: [RecognizedItem], scanner: DataScannerViewController) {
            let textItems: [(String, RecognizedItem.Bounds)] = allItems.compactMap {
                guard case .text(let t) = $0 else { return nil }
                return (t.transcript, t.bounds)
            }
            guard !textItems.isEmpty else { return }

            let tokens = textItems.map { "\"\($0.0)\"" }.joined(separator: ", ")
            print("[Scanner] \(textItems.count) item(s): \(tokens)  mode=\(mode.rawValue)")

            // Per-item parse: find the specific block that matches so we can glow it.
            for (transcript, bounds) in textItems {
                let result = parse(transcript)
                if let sid = result.stickerID {
                    let conf = String(format: "%.2f", result.confidence)
                    let flag = result.confidence >= 0.7 ? " OK" : " low"
                    print("[Scanner]   parse(\"\(transcript)\") -> \(sid) @ \(conf)\(flag)")
                }
                if let id = result.stickerID, result.confidence >= 0.7 {
                    print("[Scanner] MATCH \(id) via per-item")
                    isPendingMatch = true
                    showGlow(at: bounds, in: scanner)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                        self?.removeGlow()
                        self?.isPendingMatch = false
                        self?.onMatch(id)
                    }
                    return
                }
            }

            // No individual item matched — try combined text (catches codes split across OCR items).
            let combined = textItems.map { $0.0 }.joined(separator: "\n")
            let combined_result = parse(combined)
            let displayCombined = textItems.map { $0.0 }.joined(separator: " | ")
            let combConf = String(format: "%.2f", combined_result.confidence)
            print("[Scanner]   combined(\"\(displayCombined)\") -> \(combined_result.stickerID ?? "nil") @ \(combConf)")

            if let id = combined_result.stickerID {
                if combined_result.confidence >= 0.7 {
                    print("[Scanner] MATCH \(id) via combined")
                    isPendingMatch = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.isPendingMatch = false
                        self?.onMatch(id)
                    }
                } else {
                    onHint("Point at the sticker code more clearly")
                }
            } else {
                onHint(nil)
            }
        }

        private func parse(_ text: String) -> OCRParserResult {
            switch mode {
            case .back:
                return OCRParser.parseBack(text, knownTeams: knownTeams)
            case .front:
                return OCRParser.parseFront(text, knownTeams: Array(knownTeams))
            case .both:
                let back = OCRParser.parseBack(text, knownTeams: knownTeams)
                return back.confidence >= 0.7
                    ? back
                    : OCRParser.parseFront(text, knownTeams: Array(knownTeams))
            }
        }

        // MARK: Glow overlay

        private func showGlow(at bounds: RecognizedItem.Bounds, in scanner: DataScannerViewController) {
            let b = bounds
            let minX = min(b.topLeft.x, b.bottomLeft.x)
            let maxX = max(b.topRight.x, b.bottomRight.x)
            let minY = min(b.topLeft.y, b.topRight.y)
            let maxY = max(b.bottomLeft.y, b.bottomRight.y)
            let padded = CGRect(x: minX, y: minY,
                                width: maxX - minX,
                                height: maxY - minY).insetBy(dx: -14, dy: -10)

            let orange = UIColor(red: 0.85, green: 0.35, blue: 0.10, alpha: 1)
            let view = UIView(frame: padded)
            view.layer.cornerRadius = 10
            view.layer.borderColor = orange.cgColor
            view.layer.borderWidth = 2.5
            view.layer.shadowColor = orange.cgColor
            view.layer.shadowRadius = 14
            view.layer.shadowOpacity = 1.0
            view.layer.shadowOffset = .zero
            view.backgroundColor = UIColor(red: 0.85, green: 0.35, blue: 0.10, alpha: 0.15)
            view.alpha = 0

            scanner.overlayContainerView.addSubview(view)
            glowView = view
            UIView.animate(withDuration: 0.18) { view.alpha = 1 }
        }

        private func removeGlow() {
            UIView.animate(withDuration: 0.15, animations: {
                self.glowView?.alpha = 0
            }, completion: { _ in
                self.glowView?.removeFromSuperview()
                self.glowView = nil
            })
        }
    }
}
