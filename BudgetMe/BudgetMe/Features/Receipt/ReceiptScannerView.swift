import SwiftUI
import PhotosUI
import Vision

/// Scan a receipt photo, OCR it on-device with the Vision framework (works on every iPhone,
/// no Apple Intelligence required), and pre-fill a transaction the user confirms.
struct ReceiptScannerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private enum Stage { case pick, scanning, review }
    @State private var stage: Stage = .pick
    @State private var photoItem: PhotosPickerItem?
    @State private var merchant = ""
    @State private var amount = ""
    @State private var category: Category = .uncategorized
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .pick: pickStage
                case .scanning: scanningStage
                case .review: reviewStage
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if stage == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(merchant.isEmpty || (Double(amount) ?? 0) <= 0)
                    }
                }
            }
        }
        .onChange(of: photoItem) { item in handlePick(item) }
    }

    private var pickStage: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "doc.viewfinder").font(.system(size: 60)).foregroundStyle(Theme.primary)
            Text("Scan a receipt").font(.title2.bold())
            Text("Pick a photo of a receipt. BudgetMe reads the merchant and total on your device — great for cash and other spending Apple Pay misses.")
                .font(.subheadline).foregroundStyle(Theme.subtleText)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
            PhotosPicker(selection: $photoItem, matching: .images) {
                Text("Choose receipt photo").font(.headline)
                    .frame(maxWidth: .infinity).padding()
                    .background(Theme.primary).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal)
            Spacer().frame(height: 16)
        }
        .padding()
    }

    private var scanningStage: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.4)
            Text("Reading your receipt…").font(.headline)
            Spacer()
        }
    }

    private var reviewStage: some View {
        Form {
            Section {
                TextField("Merchant", text: $merchant)
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                NavigationLink {
                    CategoryPickerView(selected: $category)
                } label: {
                    HStack {
                        Text("Category")
                        Spacer()
                        Text(category.displayName).foregroundStyle(Theme.subtleText)
                    }
                }
                DatePicker("Date", selection: $date, displayedComponents: .date)
            } header: {
                Text("Details")
            } footer: {
                Text("Check the details and fix anything the scan got wrong.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func handlePick(_ item: PhotosPickerItem?) {
        guard let item else { return }
        stage = .scanning
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                await MainActor.run { stage = .pick }
                return
            }
            let text = await Self.recognizeText(image)
            let parsed = ReceiptParser.parse(text)
            await MainActor.run {
                merchant = parsed.merchant
                amount = parsed.amount > 0 ? String(format: "%.2f", parsed.amount) : ""
                category = CategorizationService().categorize(merchant: parsed.merchant).category
                stage = .review
            }
        }
    }

    private func save() {
        let tx = Transaction(
            merchant: merchant, amount: Double(amount) ?? 0, date: date,
            category: category, source: .receipt, isAutoCategorized: false
        )
        store.addTransactions([tx])
        dismiss()
    }

    /// On-device OCR of a receipt image.
    static func recognizeText(_ image: UIImage) async -> String {
        await withCheckedContinuation { continuation in
            guard let cg = image.cgImage else {
                continuation.resume(returning: "")
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { req, _ in
                    let text = (req.results as? [VNRecognizedTextObservation])?
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n") ?? ""
                    continuation.resume(returning: text)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                do { try handler.perform([request]) }
                catch { continuation.resume(returning: "") }
            }
        }
    }
}

/// Extracts the merchant (top-of-receipt name) and total from OCR'd receipt text.
enum ReceiptParser {
    struct Result { var merchant: String; var amount: Double }

    static func parse(_ text: String) -> Result {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Merchant is usually the first substantial text line at the top of the receipt.
        let merchant = lines.first(where: {
            $0.filter { $0.isLetter }.count >= 3 && !$0.lowercased().contains("receipt")
        }) ?? "Receipt"

        let numberPattern = #"[0-9][0-9,]*\.[0-9]{2}"#
        var amount = 0.0
        // Prefer the amount on a line that mentions "total" (but not subtotal).
        if let totalLine = lines.last(where: {
            let l = $0.lowercased()
            return l.contains("total") && !l.contains("subtotal") && !l.contains("sub total")
        }), let amt = matches(numberPattern, in: totalLine).last {
            amount = Double(amt.replacingOccurrences(of: ",", with: "")) ?? 0
        }
        // Fallback: the largest amount on the receipt (totals are usually the biggest).
        if amount == 0 {
            amount = lines.flatMap { matches(numberPattern, in: $0) }
                .compactMap { Double($0.replacingOccurrences(of: ",", with: "")) }
                .max() ?? 0
        }
        return Result(merchant: merchant, amount: amount)
    }

    static func matches(_ pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
    }
}
