import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                budgetSection
                applePaySection
                planSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
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
            // Dev toggle to preview paid features until StoreKit lands (iteration 2).
            Toggle("Simulate Paid (dev)", isOn: Binding(
                get: { store.profile.tier == .paid },
                set: { store.profile.tier = $0 ? .paid : .free }
            ))
            if store.profile.tier == .free {
                Text("\(store.remainingFreeTransactions) of \(UserProfile.freeTransactionCap) free transactions left.")
                    .font(.caption).foregroundStyle(Theme.subtleText)
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            ShareLink(item: store.exportCSV()) {
                Label("Export transactions (CSV)", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) { showResetConfirm = true } label: {
                Label("Delete all data", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete all data? This can't be undone.",
                            isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { store.clearAllData() }
            Button("Cancel", role: .cancel) {}
        }
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
    private let steps: [(String, String)] = [
        ("1. Open the Shortcuts app", "It comes preinstalled on iOS."),
        ("2. Go to Automation → New (+)", "Choose 'Create Personal Automation'."),
        ("3. Pick 'Transaction'", "Select the Apple Wallet cards you want tracked and leave all categories on."),
        ("4. Add action 'Log a Transaction in BudgetMe'", "Map Merchant → Merchant and Amount → Amount."),
        ("5. Turn on 'Run Immediately'", "Turn off 'Notify When Run' so it's fully automatic.")
    ]

    var body: some View {
        List {
            Section {
                Text("BudgetMe logs each Apple Pay tap through a one-time Shortcut. Set it up once and forget it.")
                    .font(.subheadline).foregroundStyle(Theme.subtleText)
            }
            Section("Steps") {
                ForEach(steps, id: \.0) { step in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.0).font(.subheadline.weight(.medium))
                        Text(step.1).font(.caption).foregroundStyle(Theme.subtleText)
                    }
                }
            }
            Section {
                Label("Only Apple Pay (NFC) transactions are captured. Add anything else manually.",
                      systemImage: "info.circle")
                    .font(.caption).foregroundStyle(Theme.subtleText)
            }
        }
        .navigationTitle("Auto-tracking")
        .navigationBarTitleDisplayMode(.inline)
    }
}
