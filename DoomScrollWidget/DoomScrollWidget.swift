import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct DoomScrollEntry: TimelineEntry {
    let date: Date
    let expression: SquareEyesExpression
    let streak: Int
    let reclaimedPercent: Int      // 0–100
    let overridesLeftTotal: Int    // across all managed apps
    let relationalStake: String
}

// MARK: - Provider

struct DoomScrollProvider: TimelineProvider {

    func placeholder(in context: Context) -> DoomScrollEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (DoomScrollEntry) -> Void) {
        completion(context.isPreview ? .preview : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoomScrollEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 15 minutes so streak and usage data stay current.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    // MARK: - Entry construction

    private func currentEntry() -> DoomScrollEntry {
        let streak = SharedDefaults.store.integer(forKey: "currentStreak")
        let reclaimed = SharedDefaults.store.integer(forKey: "reclaimedPercent")
        let overridesLeft = SharedDefaults.store.integer(forKey: "overridesLeftTotal")

        let profile = UserProfile.load()
        let stake: String = {
            guard let profile else { return "Make today count." }
            switch profile.ageGroup {
            case .teen:     return "What do you actually want to do today?"
            case .youngAdult: return "Make the time count."
            case .midLife:  return "Be here. Not there."
            }
        }()

        let expression: SquareEyesExpression = {
            if streak > 6  { return .proud }
            if streak > 2  { return .happy }
            if reclaimed > 70 { return .happy }
            if overridesLeft == 0 { return .sleepy }
            return .idle
        }()

        return DoomScrollEntry(
            date: Date(),
            expression: expression,
            streak: streak,
            reclaimedPercent: reclaimed,
            overridesLeftTotal: overridesLeft,
            relationalStake: stake
        )
    }
}

extension DoomScrollEntry {
    static let preview = DoomScrollEntry(
        date: Date(),
        expression: .happy,
        streak: 4,
        reclaimedPercent: 62,
        overridesLeftTotal: 3,
        relationalStake: "Make the time count."
    )
}

// MARK: - Widget declaration

struct DoomScrollWidget: Widget {
    let kind = "DoomScrollWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoomScrollProvider()) { entry in
            DoomScrollWidgetView(entry: entry)
                .containerBackground(DS.Color.background, for: .widget)
        }
        .configurationDisplayName("DoomScroll")
        .description("Square Eyes keeps an eye on your screen time.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget bundle

@main
struct DoomScrollWidgetBundle: WidgetBundle {
    var body: some Widget {
        DoomScrollWidget()
    }
}

// MARK: - Widget view (routes small / medium)

struct DoomScrollWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: DoomScrollEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        default:            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small widget
// Square Eyes expression + streak flame. Glanceable at 1 second.

struct SmallWidgetView: View {
    let entry: DoomScrollEntry

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            SquareEyesView(expression: entry.expression, size: 70, animated: false)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(DS.Color.accent)
                    .font(.caption)
                Text("\(entry.streak)d")
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textPrimary)
            }

            Text("\(entry.reclaimedPercent)% reclaimed")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .padding(DS.Spacing.sm)
    }
}

// MARK: - Medium widget
// Square Eyes + relational stake + streak + override dots.

struct MediumWidgetView: View {
    let entry: DoomScrollEntry

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Left: mascot
            VStack(spacing: DS.Spacing.sm) {
                SquareEyesView(expression: entry.expression, size: 80, animated: false)

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(DS.Color.accent)
                        .font(.caption)
                    Text("\(entry.streak)d")
                        .font(DS.Font.headline)
                        .foregroundStyle(DS.Color.textPrimary)
                }
            }

            // Right: stats
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(entry.relationalStake)
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Progress ring row
                HStack(spacing: DS.Spacing.sm) {
                    progressRing(percent: entry.reclaimedPercent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.reclaimedPercent)%")
                            .font(DS.Font.title2)
                            .foregroundStyle(DS.Color.textPrimary)
                        Text("reclaimed today")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }

                // Override dots
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(i < entry.overridesLeftTotal
                                  ? DS.Color.success
                                  : DS.Color.backgroundMuted)
                            .frame(width: 7, height: 7)
                    }
                    Text("overrides left")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }
            }
        }
        .padding(DS.Spacing.md)
    }

    private func progressRing(percent: Int) -> some View {
        ZStack {
            Circle()
                .stroke(DS.Color.backgroundMuted, lineWidth: 5)
                .frame(width: 36, height: 36)

            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(DS.Color.success,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    DoomScrollWidget()
} timeline: {
    DoomScrollEntry.preview
}

#Preview(as: .systemMedium) {
    DoomScrollWidget()
} timeline: {
    DoomScrollEntry.preview
}
