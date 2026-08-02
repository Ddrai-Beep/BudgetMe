import SwiftUI

struct AddPlannedEntryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount = ""
    @State private var isIncome = false
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("One-time entry") {
                    Picker("Type", selection: $isIncome) {
                        Text("Expense").tag(false)
                        Text("Income").tag(true)
                    }
                    .pickerStyle(.segmented)
                    TextField("Name (e.g. Freelance payment)", text: $name)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Planned Entry")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addPlannedEntry(PlannedEntry(
                            name: name, amount: Double(amount) ?? 0, date: date, isIncome: isIncome
                        ))
                        dismiss()
                    }
                    .disabled(name.isEmpty || (Double(amount) ?? 0) <= 0)
                }
            }
        }
    }
}
