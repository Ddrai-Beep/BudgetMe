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
    var amountText: String = ""      // shown as the big number when this slice is touched
    var subtitleText: String = ""    // e.g. "45% of July"
}

struct DonutChart: View {
    let slices: [RingSlice]
    var lineWidth: CGFloat = 22
    // Default center content, shown when no segment is being touched.
    var centerLabel: String = ""
    var centerTitle: String = ""
    var centerSubtitle: String = ""

    @State private var selectedID: UUID?

    private var total: Double { max(slices.reduce(0) { $0 + $1.value }, 0.0001) }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(Array(slices.enumerated()), id: \.element.id) { idx, slice in
                    let seg = fractions(at: idx)
                    Circle()
                        .trim(from: seg.start, to: seg.end)
                        .stroke(slice.color.opacity(dimmed(slice.id) ? 0.3 : 1),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                centerContent
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { updateSelection(at: $0.location, size: size) }
                    .onEnded { _ in selectedID = nil }
            )
            .animation(.easeInOut(duration: 0.15), value: selectedID)
        }
        .padding(lineWidth / 2)
    }

    private var centerContent: some View {
        let selected = slices.first { $0.id == selectedID }
        let label = selected?.label ?? centerLabel
        let title = selected?.amountText ?? centerTitle
        let subtitle = selected?.subtitleText ?? centerSubtitle
        return VStack(spacing: 1) {
            if !label.isEmpty {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(selected?.color ?? Theme.subtleText)
                    .lineLimit(1)
            }
            Text(title)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.subtleText)
                    .lineLimit(1)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, lineWidth)
    }

    private func dimmed(_ id: UUID) -> Bool {
        selectedID != nil && selectedID != id
    }

    private func fractions(at index: Int) -> (start: CGFloat, end: CGFloat) {
        var running: Double = 0
        for (i, slice) in slices.enumerated() {
            let start = running / total
            running += slice.value
            let end = running / total
            if i == index { return (CGFloat(start), CGFloat(end)) }
        }
        return (0, 0)
    }

    /// Maps a touch point to the slice under it (nil if in the hole or outside the ring band).
    private func updateSelection(at location: CGPoint, size: CGFloat) {
        let center = CGPoint(x: size / 2, y: size / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = sqrt(dx * dx + dy * dy)
        let outer = size / 2
        let inner = outer - lineWidth
        guard dist >= inner * 0.55, dist <= outer + lineWidth else {
            selectedID = nil
            return
        }
        var angle = atan2(dx, -dy)          // 0 at top, increasing clockwise
        if angle < 0 { angle += 2 * .pi }
        let frac = angle / (2 * .pi)
        var running: Double = 0
        for slice in slices {
            let start = running / total
            running += slice.value
            let end = running / total
            if frac >= start && frac < end {
                selectedID = slice.id
                return
            }
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
