import SwiftUI

/// A category chooser ordered by most-used, with custom categories and a paid "add custom" action.
/// Pushed inside an existing NavigationStack.
struct CategoryPickerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: Category

    @State private var showingAddCustom = false
    @State private var newCustomName = ""
    @State private var showPaywall = false

    var body: some View {
        List {
            Section {
                ForEach(store.categoriesByUsage()) { category in
                    Button {
                        selected = category
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            CategoryIcon(category: category, size: 30)
                            Text(category.displayName).foregroundStyle(.primary)
                            if category.isCustom {
                                Text("Custom").font(.caption2).foregroundStyle(Theme.subtleText)
                            }
                            Spacer()
                            if category.id == selected.id {
                                Image(systemName: "checkmark").foregroundStyle(Theme.primary)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    if store.profile.tier == .paid {
                        showingAddCustom = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack {
                        Label("Add custom category", systemImage: "plus.circle")
                        Spacer()
                        if store.profile.tier != .paid { PaidBadge() }
                    }
                }
            } footer: {
                Text("Create your own categories to track spending your way.")
            }
        }
        .navigationTitle("Category")
        .navigationBarTitleDisplayMode(.inline)
        .alert("New category", isPresented: $showingAddCustom) {
            TextField("Name", text: $newCustomName)
            Button("Add") {
                let name = newCustomName.trimmingCharacters(in: .whitespaces)
                newCustomName = ""
                guard !name.isEmpty else { return }
                store.addCustomCategory(name)
                selected = Category(name)
                dismiss()
            }
            Button("Cancel", role: .cancel) { newCustomName = "" }
        } message: {
            Text("Name your custom category.")
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}
