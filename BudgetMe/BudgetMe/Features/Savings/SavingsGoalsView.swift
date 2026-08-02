import SwiftUI

/// A simple circular progress ring.
struct ProgressRing: View {
    let progress: Double
    var color: Color = Theme.primary
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(Color(.tertiarySystemFill), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((min(max(progress, 0), 1)) * 100))%").font(.caption.bold())
        }
    }
}

/// Pushed inside Settings' NavigationStack.
struct SavingsGoalsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingAdd = false
    @State private var contributionGoal: SavingsGoal?
    @State private var contributionText = ""

    private var code: String { store.profile.currencyCode }

    var body: some View {
        List {
            if store.savingsGoals.isEmpty {
                Section { emergencyFundCard }
            }
            ForEach(store.savingsGoals) { goal in
                goalCard(goal)
            }
            .onDelete { idx in idx.map { store.savingsGoals[$0] }.forEach(store.deleteGoal) }
        }
        .navigationTitle("Savings Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) { AddGoalView() }
        .alert("Log contribution", isPresented: Binding(
            get: { contributionGoal != nil },
            set: { if !$0 { contributionGoal = nil } }
        )) {
            TextField("Amount", text: $contributionText)
            Button("Add") {
                if let goal = contributionGoal, let amount = Double(contributionText), amount > 0 {
                    store.logContribution(amount, to: goal)
                }
                contributionText = ""
                contributionGoal = nil
            }
            Button("Cancel", role: .cancel) { contributionText = ""; contributionGoal = nil }
        } message: {
            Text("How much did you save toward this goal?")
        }
    }

    private func goalCard(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ProgressRing(progress: goal.progress).frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.name).font(.subheadline.weight(.medium))
                    Text("\(Money.format(goal.saved, code: code)) of \(Money.format(goal.target, code: code))")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                    Text("Save \(Money.format(goal.requiredMonthly, code: code))/mo to reach it by \(goal.targetDate.formatted(.dateTime.month().year()))")
                        .font(.caption2).foregroundStyle(Theme.subtleText)
                }
                Spacer()
            }
            Button("Log contribution") {
                contributionText = ""
                contributionGoal = goal
            }
            .font(.caption.bold())
        }
        .padding(.vertical, 4)
    }

    private var emergencyFundCard: some View {
        let avg = store.averageMonthlySpend
        return VStack(alignment: .leading, spacing: 6) {
            Text("Start an emergency fund").font(.subheadline.bold())
            if avg > 0 {
                Text("Experts suggest 3–6 months of expenses. Based on your spending that's about \(Money.format(avg * 3, code: code))–\(Money.format(avg * 6, code: code)).")
                    .font(.caption).foregroundStyle(Theme.subtleText)
            } else {
                Text("Set a target and track your progress toward peace of mind.")
                    .font(.caption).foregroundStyle(Theme.subtleText)
            }
            Button("Create a goal") { showingAdd = true }
                .font(.caption.bold()).padding(.top, 2)
        }
    }
}

struct AddGoalView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var target = ""
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Name (e.g. New laptop)", text: $name)
                    TextField("Target amount", text: $target).keyboardType(.decimalPad)
                    DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.isEmpty || (Double(target) ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        store.addGoal(SavingsGoal(
            name: name,
            target: Double(target) ?? 0,
            targetDate: targetDate
        ))
        dismiss()
    }
}
