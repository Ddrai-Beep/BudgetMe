import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("autoDetectRecurringIncome") private var autoDetectIncome = true
    @AppStorage("csvImportCount") private var csvImportCount = 0
    @State private var showResetConfirm = false
    @State private var showImporter = false
    @State private var importResult: String?
    @State private var showPaywall = false
    @State private var highlightImport = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    profileSection
                    budgetSection
                    forecastSection
                    applePaySection
                    planSection
                    dataSection
                    aboutSection
                }
                .navigationTitle("Settings")
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { hideKeyboard() }
                    }
                }
                .sheet(isPresented: $showPaywall) { PaywallView() }
                .onAppear { handlePendingScroll(proxy) }
                .onChange(of: store.pendingScrollToImport) { _ in handlePendingScroll(proxy) }
            }
        }
    }

    /// When the home banner sends the user here, scroll to and briefly highlight the import row.
    private func handlePendingScroll(_ proxy: ScrollViewProxy) {
        guard store.pendingScrollToImport else { return }
        store.pendingScrollToImport = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { proxy.scrollTo("csvImport", anchor: .center) }
            highlightImport = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation { highlightImport = false }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var forecastSection: some View {
        Section {
            Toggle("Auto-detect recurring income", isOn: $autoDetectIncome)
        } header: {
            Text("Forecast")
        } footer: {
            Text("When on, BudgetMe treats your income as a monthly deposit so your forecast reflects money coming in. Turn off if your income is irregular.")
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            TextField("Name", text: $store.profile.name)
            Picker("Currency", selection: currencyBinding) {
                ForEach(SupportedCurrency.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            HStack {
                Text("Monthly income")
                Spacer()
                TextField("0", value: $store.profile.monthlyIncome, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
            }
        }
    }

    private var currencyBinding: Binding<String> {
        Binding(get: { store.profile.currencyCode }, set: { store.profile.currencyCode = $0 })
    }

    private var budgetSection: some View {
        Section("Budget framework") {
            ForEach(BudgetFramework.allCases) { fw in
                Button {
                    if fw.isFree { store.profile.framework = fw }
                } label: {
                    HStack {
                        Text(fw.rawValue).foregroundStyle(.primary)
                        Spacer()
                        if fw == store.profile.framework { Image(systemName: "checkmark").foregroundStyle(Theme.primary) }
                        if !fw.isFree { PaidBadge() }
                    }
                }
                .disabled(!fw.isFree)
            }
        }
    }

    private var applePaySection: some View {
        Section("Apple Pay auto-tracking") {
            NavigationLink {
                ShortcutSetupView()
            } label: {
                Label("Set up automatic logging", systemImage: "wave.3.right")
            }
        }
    }

    private var planSection: some View {
        Section("Plan") {
            HStack {
                Text("Current plan")
                Spacer()
                Text(store.profile.tier == .paid ? "Paid" : "Free")
                    .foregroundStyle(Theme.subtleText)
            }
            if store.profile.tier != .paid {
                Button {
                    showPaywall = true
                } label: {
                    Label("Upgrade to Paid", systemImage: "crown.fill")
                }
            }
            // Dev toggle to preview paid features until StoreKit lands (iteration 2).
            Toggle("Simulate Paid (dev)", isOn: Binding(
                get: { store.profile.tier == .paid },
                set: { store.profile.tier = $0 ? .paid : .free }
            ))
            if store.profile.tier == .free {
                Text("\(store.remainingFreeTransactions) of \(UserProfile.freeTransactionCap) transactions left this week.")
                    .font(.caption).foregroundStyle(Theme.subtleText)
            }
        }
    }

    private var canImport: Bool {
        store.profile.tier == .paid || csvImportCount < 2
    }

    /// Writes the CSV to a temp file so the share sheet offers a real .csv to save/send.
    private var exportedCSVFile: URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BudgetMe-transactions.csv")
        try? store.exportCSV().data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private var dataSection: some View {
        Section {
            Button {
                if canImport { showImporter = true }
            } label: {
                HStack {
                    Label("Import transactions (CSV)", systemImage: "square.and.arrow.down")
                        .foregroundStyle(.primary)
                    Spacer()
                    if !canImport { PaidBadge() }
                }
            }
            .disabled(!canImport)
            .id("csvImport")
            .listRowBackground(highlightImport
                               ? Theme.primary.opacity(0.18)
                               : Color(.secondarySystemGroupedBackground))

            ShareLink(item: exportedCSVFile) {
                Label("Export transactions (CSV)", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) { showResetConfirm = true } label: {
                Label("Delete all data", systemImage: "trash")
            }
        } header: {
            Text("Data")
        } footer: {
            Text(canImport
                 ? "Import past spending from a bank CSV. First 2 imports are free."
                 : "You've used your 2 free imports. Upgrade to import more.")
        }
        .confirmationDialog("Delete all data? This can't be undone.",
                            isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { store.clearAllData() }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            switch result {
            case .success(let url): importFile(url)
            case .failure: importResult = "Couldn't open that file."
            }
        }
        .alert("Import", isPresented: Binding(
            get: { importResult != nil },
            set: { if !$0 { importResult = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResult ?? "")
        }
    }

    private func importFile(_ url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            importResult = "Couldn't read that file."
            return
        }
        let count = store.importCSV(text)
        if count > 0 { csvImportCount += 1 }
        importResult = count > 0
            ? "Imported \(count) transaction\(count == 1 ? "" : "s")."
            : "No transactions found. Check the file has date, merchant and amount columns."
    }

    private var aboutSection: some View {
        Section {
            Label("Your transaction data stays on your device.", systemImage: "lock.shield")
                .font(.caption).foregroundStyle(Theme.subtleText)
        } footer: {
            Text("BudgetMe v0.1.0 · MVP")
        }
    }
}

/// Step-by-step guide for the one-time Shortcuts personal automation.
struct ShortcutSetupView: View {
    var body: some View {
        ScrollView {
            AutoTrackSetupContent(showsHeader: false)
                .padding()
        }
        .background(Theme.background)
        .navigationTitle("Auto-tracking")
        .navigationBarTitleDisplayMode(.inline)
    }
}
