import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var step = 0

    @State private var name = ""
    @State private var currency: SupportedCurrency = .AED
    @State private var income = ""

    var body: some View {
        VStack {
            TabView(selection: $step) {
                welcome.tag(0)
                profile.tag(1)
                applePay.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(step < 2 ? "Continue" : "Start budgeting") {
                hideKeyboard()
                if step < 2 { withAnimation { step += 1 } } else { finish() }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding()
            .disabled(step == 1 && income.isEmpty)
        }
        .background(Theme.background.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { hideKeyboard() }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 72)).foregroundStyle(Theme.primary)
            Text("BudgetMe").font(.largeTitle.bold())
            Text("The budgeting app built for the rest of the world.")
                .font(.title3).foregroundStyle(Theme.subtleText)
                .multilineTextAlignment(.center)
            Text("Track spending, pick a budgeting style, and see where you're headed — with pricing that fits your region.")
                .font(.subheadline).foregroundStyle(Theme.subtleText)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer(); Spacer()
        }
        .padding()
    }

    private var profile: some View {
        Form {
            Section("About you") {
                TextField("First name (optional)", text: $name)
            }
            Section("Currency") {
                Picker("Currency", selection: $currency) {
                    ForEach(SupportedCurrency.allCases) { c in
                        Text(c.label).tag(c)
                    }
                }
            }
            Section {
                TextField("e.g. 12000", text: $income)
                    .keyboardType(.decimalPad)
            } header: {
                Text("Monthly take-home income")
            } footer: {
                Text("Used to build your 50/30/20 budget. You can change it anytime.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
    }

    private var applePay: some View {
        ScrollView {
            AutoTrackSetupContent()
                .padding()
        }
        .background(Theme.background)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func finish() {
        store.profile.name = name
        store.profile.currencyCode = currency.rawValue
        store.profile.monthlyIncome = Double(income) ?? 0
        store.profile.hasCompletedOnboarding = true
    }
}
