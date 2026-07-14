import SwiftUI

struct AddTransactionView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var merchant = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var category: Category = .uncategorized
    @State private var note = ""
    @State private var autoCategory = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction") {
                    TextField("Merchant", text: $merchant)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Category") {
                    Toggle("Auto-categorize", isOn: $autoCategory)
                    if !autoCategory {
                        NavigationLink {
                            CategoryPickerView(selected: $category)
                        } label: {
                            HStack {
                                Text("Category")
                                Spacer()
                                Text(category.displayName).foregroundStyle(Theme.subtleText)
                            }
                        }
                    }
                }
                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                }
                if store.isAtFreeCap {
                    Section {
                        Label("You've hit your weekly limit of \(UserProfile.freeTransactionCap) transactions. Upgrade to keep logging.",
                              systemImage: "lock.fill")
                            .font(.footnote).foregroundStyle(Theme.warning)
                    }
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var canSave: Bool {
        !merchant.isEmpty && (Double(amount) ?? 0) > 0 && !store.isAtFreeCap
    }

    private func save() {
        store.addTransaction(
            merchant: merchant,
            amount: Double(amount) ?? 0,
            date: date,
            category: autoCategory ? nil : category,
            note: note.isEmpty ? nil : note
        )
        dismiss()
    }
}
