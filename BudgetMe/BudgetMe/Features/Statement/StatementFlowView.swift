import SwiftUI
import UniformTypeIdentifiers

/// Three-step "Analyze a statement with AI" flow:
/// 1) upload a PDF  2) analysis progress ring  3) review + remove suspected duplicates.
struct StatementFlowView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var progress: Double = 0
    @State private var suspectedDupes: [Transaction] = []
    @State private var removed: [(tx: Transaction, wasDupe: Bool)] = []
    @State private var showImporter = false
    @State private var showDone = false
    @State private var contentOpacity: Double = 1
    @State private var errorMessage: String?
    @State private var pendingURL: URL?
    @State private var needsPassword = false
    @State private var passwordText = ""
    @State private var usedAI = false

    private var code: String { store.profile.currencyCode }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content.opacity(contentOpacity)
            if showDone { doneOverlay }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                pendingURL = url
                if StatementAnalyzer.isLocked(url: url) {
                    needsPassword = true
                } else {
                    startAnalysis(url, password: nil)
                }
            case .failure: errorMessage = "Couldn't open that file."
            }
        }
        .alert("Statement password", isPresented: $needsPassword) {
            SecureField("Password", text: $passwordText)
            Button("Unlock") {
                if let url = pendingURL { startAnalysis(url, password: passwordText) }
                passwordText = ""
            }
            Button("Cancel", role: .cancel) { passwordText = "" }
        } message: {
            Text("This PDF is password-protected. Enter its password to read it (often your ID number or date of birth).")
        }
        .alert("Import", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0: uploadStep
        case 1: progressStep
        default: reviewStep
        }
    }

    // MARK: Step 1 — upload

    private var uploadStep: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64)).foregroundStyle(Theme.primary)
            Text("Analyze your statement").font(.title.bold())
            Text("Upload a bank statement PDF. It's read on your device to find charges Apple Pay didn't capture — and to flag anything already logged.")
                .font(.subheadline).foregroundStyle(Theme.subtleText)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
            Button { showImporter = true } label: {
                Text("Choose PDF statement").font(.headline)
                    .frame(maxWidth: .infinity).padding()
                    .background(Theme.primary).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal)
            Button("Cancel") { dismiss() }
                .font(.subheadline).foregroundStyle(Theme.subtleText)
            Spacer().frame(height: 16)
        }
        .padding()
    }

    // MARK: Step 2 — progress

    private var progressStep: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().stroke(Color(.tertiarySystemFill), lineWidth: 14)
                Circle().trim(from: 0, to: progress)
                    .stroke(Theme.primary, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
            }
            .frame(width: 180, height: 180)
            Text("Analyzing your statement…").font(.headline)
            Text("Reading transactions and checking for duplicates.")
                .font(.caption).foregroundStyle(Theme.subtleText)
            Spacer()
        }
        .padding()
    }

    // MARK: Step 3 — review

    private var reviewStep: some View {
        VStack(spacing: 0) {
            HStack {
                Button { undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(removed.isEmpty)
                Spacer()
            }
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if usedAI {
                        Label("Parsed with on-device AI", systemImage: "sparkles")
                            .font(.caption).foregroundStyle(Theme.primary)
                    } else {
                        Text("Read with the basic parser. For accurate merchant names and credits vs debits, turn on Apple Intelligence (Settings → Apple Intelligence & Siri), then try again.")
                            .font(.caption).foregroundStyle(Theme.warning)
                    }

                    Text("Suspected duplicates").font(.title3.bold())
                    Text("These look already logged. Tap to remove them.")
                        .font(.caption).foregroundStyle(Theme.subtleText)

                    if suspectedDupes.isEmpty {
                        Text("No duplicates found — everything imported is new.")
                            .font(.subheadline).foregroundStyle(Theme.subtleText)
                            .padding(.vertical, 12)
                    }
                    ForEach(suspectedDupes) { tx in
                        dupeRow(tx).transition(.scale.combined(with: .opacity))
                    }

                    Divider().padding(.vertical, 10)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("All transactions").font(.subheadline.bold()).foregroundStyle(Theme.subtleText)
                        Text("Scroll to remove anything else.")
                            .font(.caption2).foregroundStyle(Theme.subtleText)
                        ForEach(store.transactions) { tx in
                            fullRow(tx).transition(.opacity)
                        }
                    }
                    .opacity(0.5)
                }
                .padding()
            }

            Button { finish() } label: {
                Text("Done").font(.headline)
                    .frame(maxWidth: .infinity).padding()
                    .background(Theme.primary).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding()
        }
    }

    private func dupeRow(_ tx: Transaction) -> some View {
        Button { removeDupe(tx) } label: {
            CardView(padding: 12) {
                HStack(spacing: 12) {
                    CategoryIcon(category: tx.category, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tx.merchant).font(.subheadline.weight(.medium))
                        Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2).foregroundStyle(Theme.subtleText)
                    }
                    Spacer()
                    Text(Money.format(tx.amount, code: code)).font(.subheadline.weight(.semibold))
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.danger)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func fullRow(_ tx: Transaction) -> some View {
        Button { removeOther(tx) } label: {
            HStack(spacing: 10) {
                CategoryIcon(category: tx.category, size: 26)
                Text(tx.merchant).font(.caption).lineLimit(1)
                Spacer()
                Text(Money.format(tx.amount, code: code)).font(.caption)
                Image(systemName: "minus.circle").font(.caption).foregroundStyle(Theme.subtleText)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var doneOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 76)).foregroundStyle(Theme.primary)
            Text("All done").font(.title2.bold())
        }
        .transition(.opacity)
    }

    // MARK: Actions

    private func startAnalysis(_ url: URL, password: String?) {
        step = 1
        progress = 0
        withAnimation(.easeInOut(duration: 1.6)) { progress = 1.0 }
        let existing = store.transactions
        Task {
            let result = await StatementAnalyzer.analyzeAsync(url: url, password: password, existing: existing)
            await MainActor.run {
                guard !result.imported.isEmpty else {
                    step = 0
                    progress = 0
                    errorMessage = "Couldn't read any transactions from that statement. It may be a scanned image, an unusual layout, or the password was wrong."
                    return
                }
                store.addTransactions(result.imported)
                usedAI = result.usedAI
                let dupes = result.imported.filter { result.suspectedDupeIDs.contains($0.id) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    suspectedDupes = dupes
                    withAnimation { step = 2 }
                }
            }
        }
    }

    private func removeDupe(_ tx: Transaction) {
        withAnimation(.easeInOut(duration: 0.3)) {
            suspectedDupes.removeAll { $0.id == tx.id }
        }
        store.delete(tx)
        removed.append((tx, true))
    }

    private func removeOther(_ tx: Transaction) {
        withAnimation(.easeInOut(duration: 0.3)) { store.delete(tx) }
        suspectedDupes.removeAll { $0.id == tx.id }
        removed.append((tx, false))
    }

    private func undo() {
        guard let last = removed.popLast() else { return }
        store.addTransactions([last.tx])
        if last.wasDupe {
            withAnimation { suspectedDupes.insert(last.tx, at: 0) }
        }
    }

    private func finish() {
        withAnimation(.easeInOut(duration: 0.35)) { showDone = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.4)) { contentOpacity = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { dismiss() }
    }
}
