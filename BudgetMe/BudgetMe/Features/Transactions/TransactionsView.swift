import SwiftUI

// MARK: - Reusable row

struct TransactionRow: View {
    let tx: Transaction
    let code: String

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: tx.category)
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.merchant).font(.subheadline.weight(.medium)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(tx.category.displayName)
                    if tx.source == .applePay {
                        Image(systemName: "applelogo").font(.caption2)
                    }
                    if tx.isAutoCategorized && tx.category == .uncategorized {
                        Text("· needs review").foregroundStyle(Theme.warning)
                    }
                }
                .font(.caption).foregroundStyle(Theme.subtleText)
            }
            Spacer()
            Text(Money.format(tx.signedAmount, code: code, showSign: tx.isIncome))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tx.isIncome ? Theme.primary : .primary)
        }
    }
}

// MARK: - List

struct TransactionsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var showingAdd = false
    @State private var showingScan = false
    @State private var path: [Transaction] = []

    private var code: String { store.profile.currencyCode }

    private var filtered: [Transaction] {
        guard !search.isEmpty else { return store.transactions }
        return store.transactions.filter {
            $0.merchant.localizedCaseInsensitiveContains(search) ||
            $0.category.displayName.localizedCaseInsensitiveContains(search)
        }
    }

    private var grouped: [(day: Date, items: [Transaction])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.date) }
        return dict.map { ($0.key, $0.value) }.sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(grouped, id: \.day) { group in
                    Section(header: Text(sectionTitle(group.day))) {
                        ForEach(group.items) { tx in
                            NavigationLink(value: tx) {
                                TransactionRow(tx: tx, code: code)
                            }
                        }
                        .onDelete { idx in
                            idx.map { group.items[$0] }.forEach(store.delete)
                        }
                    }
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $search, prompt: "Search merchant or category")
            .navigationDestination(for: Transaction.self) { tx in
                TransactionDetailView(tx: tx)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showingScan = true } label: { Label("Scan a receipt", systemImage: "doc.viewfinder") }
                        Button { showingAdd = true } label: { Label("Add manually", systemImage: "square.and.pencil") }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddTransactionView()
            }
            .sheet(isPresented: $showingScan) {
                ReceiptScannerView()
            }
            .onChange(of: store.selectedTab) { tab in
                // Reset to the full list whenever the user leaves the Transactions tab.
                if tab != 1 {
                    path = []
                    search = ""
                }
            }
        }
    }

    private func sectionTitle(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMM"
        return f.string(from: date)
    }
}

// MARK: - Detail

struct TransactionDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let tx: Transaction

    private var code: String { store.profile.currencyCode }

    /// Live copy so category edits reflect immediately.
    private var live: Transaction { store.transactions.first { $0.id == tx.id } ?? tx }

    var body: some View {
        Form {
            Section {
                HStack {
                    CategoryIcon(category: live.category, size: 48)
                    VStack(alignment: .leading) {
                        Text(tx.merchant).font(.headline)
                        Text(tx.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(Theme.subtleText)
                    }
                    Spacer()
                    Text(Money.format(tx.signedAmount, code: code, showSign: tx.isIncome))
                        .font(.title3.bold())
                }
            }
            Section("Category") {
                NavigationLink {
                    CategoryPickerView(selected: Binding(
                        get: { live.category },
                        set: { store.recategorize(tx, to: $0) }
                    ))
                } label: {
                    HStack {
                        Text("Category")
                        Spacer()
                        Text(live.category.displayName).foregroundStyle(Theme.subtleText)
                    }
                }
            }
            if let note = tx.note, !note.isEmpty {
                Section("Note") { Text(note) }
            }
            Section {
                Label("Source: \(tx.source.rawValue)", systemImage: "creditcard")
                    .font(.subheadline).foregroundStyle(Theme.subtleText)
            }
            Section {
                Button(role: .destructive) {
                    store.delete(tx); dismiss()
                } label: {
                    Label("Delete transaction", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
