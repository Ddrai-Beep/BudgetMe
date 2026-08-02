import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var purchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    if storeManager.products.isEmpty {
                        ProgressView().padding(.vertical, 24)
                        Text("Loading plans…")
                            .font(.caption).foregroundStyle(Theme.subtleText)
                    } else {
                        ForEach(storeManager.products, id: \.id) { product in
                            productCard(product)
                        }
                    }
                    Button("Restore purchases") {
                        Task { await storeManager.restore() }
                    }
                    .font(.subheadline)
                    Text("Cancel anytime in your App Store settings.")
                        .font(.caption2).foregroundStyle(Theme.subtleText)
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("BudgetMe Paid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .onChange(of: storeManager.isSubscribed) { subscribed in
                if subscribed { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill").font(.system(size: 44)).foregroundStyle(Theme.accent)
            Text("Unlock everything").font(.title2.bold())
            Text("All budget frameworks, the subscription manager, debt planner, savings goals, unlimited history, CSV imports and 90-day forecasts.")
                .font(.subheadline).foregroundStyle(Theme.subtleText)
                .multilineTextAlignment(.center)
        }
    }

    private func productCard(_ product: Product) -> some View {
        Button {
            Task {
                purchasing = true
                _ = await storeManager.purchase(product)
                purchasing = false
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName).font(.headline)
                    Text(product.description).font(.caption).foregroundStyle(Theme.subtleText)
                }
                Spacer()
                Text(product.displayPrice).font(.headline)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(purchasing)
    }
}
