import SwiftUI

struct AddSubscriptionView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount = ""
    @State private var cycle: BillingCycle = .monthly
    @State private var renewal = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Subscription") {
                    TextField("Name (e.g. Netflix)", text: $name)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    Picker("Billing cycle", selection: $cycle) {
                        ForEach(BillingCycle.allCases) { Text($0.label).tag($0) }
                    }
                    DatePicker("Next renewal", selection: $renewal, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
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

    private var canSave: Bool {
        !name.isEmpty && (Double(amount) ?? 0) > 0
    }

    private func save() {
        store.addSubscription(Subscription(
            name: name, amount: Double(amount) ?? 0, cycle: cycle, renewalDate: renewal
        ))
        dismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
