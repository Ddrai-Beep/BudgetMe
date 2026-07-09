import SwiftUI

// MARK: - Card container

struct CardView<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Donut / ring chart (iOS 16 safe, no Swift Charts dependency)

struct RingSlice: Identifiable {
    let id = UUID()
    let value: Double
    let color: Color
    let label: String
}

struct DonutChart: View {
    let slices: [RingSlice]
    var lineWidth: CGFloat = 22
    var centerTitle: String = ""
    var centerSubtitle: String = ""

    private var total: Double { max(slices.reduce(0) { $0 + $1.value }, 0.0001) }

    var body: some View {
        ZStack {
            ForEach(Array(cumulative().enumerated()), id: \.offset) { _, seg in
                Circle()
                    .trim(from: seg.start, to: seg.end)
                    .stroke(seg.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 2) {
                Text(centerTitle).font(.title3.bold())
                if !centerSubtitle.isEmpty {
                    Text(centerSubtitle).font(.caption).foregroundStyle(Theme.subtleText)
                }
            }
        }
        .padding(lineWidth / 2)
    }

    private func cumulative() -> [(start: CGFloat, end: CGFloat, color: Color)] {
        var running: Double = 0
        return slices.map { slice in
            let start = running / total
            running += slice.value
            let end = running / total
            return (CGFloat(start), CGFloat(end), slice.color)
        }
    }
}

// MARK: - Horizontal budget progress bar

struct BudgetBar: View {
    let spent: Double
    let limit: Double
    var tint: Color = Theme.primary

    private var fraction: Double { limit <= 0 ? 0 : min(spent / limit, 1) }
    private var isOver: Bool { spent > limit && limit > 0 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(isOver ? Theme.danger : tint)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action).font(.subheadline)
            }
        }
    }
}

// MARK: - Category chip / icon

struct CategoryIcon: View {
    let category: Category
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            Circle().fill(category.color.opacity(0.18))
            Image(systemName: category.systemImage)
                .foregroundStyle(category.color)
                .font(.system(size: size * 0.42, weight: .semibold))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Locked (paid) badge

struct PaidBadge: View {
    var body: some View {
        Text("PAID")
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.accent.opacity(0.2))
            .foregroundStyle(Theme.accent)
            .clipShape(Capsule())
    }
}
