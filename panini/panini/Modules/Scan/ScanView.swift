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
    @Environment(SyncEngine.self) private var syncEngine

    @State private var mode: ScanMode = .back
    @State private var pending: String? = nil         // stickerID awaiting confirm
    @State private var hintMessage: String? = nil
    @State private var showManualAdd = false

    var body: some View {
        ZStack {
            scannerLayer
            overlayLayer
        }
        .ignoresSafeArea()
        .sheet(item: Binding(
            get: { pending.map { ScanMatch(id: $0) } },
            set: { pending = $0?.id }
        )) { match in
            ScanConfirmView(stickerID: match.id)
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showManualAdd = true } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
        .sheet(isPresented: $showManualAdd) { ManualAddView() }
    }

    // MARK: Scanner

    @ViewBuilder
    private var scannerLayer: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            DataScannerRepresentable(mode: mode, onResult: handleResult)
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

    // MARK: Overlay (mode toggle + hint)

    @ViewBuilder
    private var overlayLayer: some View {
        VStack {
            if let hint = hintMessage {
                Text(hint)
                    .bodyStyle(size: 14, weight: .medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Spacer()
            modeToggle
                .padding(.bottom, 40)
        }
        .animation(.easeInOut(duration: 0.25), value: hintMessage)
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

    // MARK: Parse handler

    private func handleResult(_ text: String) {
        guard pending == nil else { return }

        let knownTeams: [String] = {
            let stickers = (try? context.fetch(FetchDescriptor<Sticker>())) ?? []
            return Array(Set(stickers.map { $0.countryCode }))
        }()

        let result: OCRParserResult
        switch mode {
        case .back:
            result = OCRParser.parseBack(text)
        case .front:
            result = OCRParser.parseFront(text, knownTeams: knownTeams)
        case .both:
            let back = OCRParser.parseBack(text)
            result = back.confidence >= 0.7 ? back : OCRParser.parseFront(text, knownTeams: knownTeams)
        }

        if let id = result.stickerID {
            if result.confidence >= 0.7 {
                hintMessage = nil
                pending = id
            } else {
                hintMessage = "Point at the sticker code more clearly"
            }
        } else {
            hintMessage = nil
        }
    }
}

// MARK: - ScanMatch (Identifiable wrapper for sheet binding)

private struct ScanMatch: Identifiable {
    let id: String
}

// MARK: - DataScannerRepresentable

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let mode: ScanMode
    let onResult: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .fast,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        context.coordinator.onResult = onResult
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onResult: (String) -> Void
        private var lastFiredAt: Date = .distantPast

        init(onResult: @escaping (String) -> Void) {
            self.onResult = onResult
        }

        func dataScanner(
            _ scanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            // Throttle to ~2 parses/second so we don't hammer OCRParser.
            guard Date().timeIntervalSince(lastFiredAt) > 0.5 else { return }
            lastFiredAt = Date()
            fire(allItems: allItems)
        }

        func dataScanner(
            _ scanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard Date().timeIntervalSince(lastFiredAt) > 0.5 else { return }
            lastFiredAt = Date()
            fire(allItems: allItems)
        }

        private func fire(allItems: [RecognizedItem]) {
            let text = allItems.compactMap { item -> String? in
                guard case .text(let t) = item else { return nil }
                return t.transcript
            }.joined(separator: "\n")

            guard !text.isEmpty else { return }
            onResult(text)
        }
    }
}
