import SwiftUI
import StoreKit

// Paywall — shown after onboarding completes, once the user has set their first limit
// (so they've had a win and understand the value before being asked to pay).
// Hard paywall with 14-day free trial; no free tier per conversion data.
struct PaywallView: View {
    @ObservedObject private var manager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTier: Tier = .family
    @State private var selectedPeriod: Period = .annual
    @State private var isPurchasing = false
    @State private var errorMessage: String? = nil
    @State private var mascotExpression: SquareEyesExpression = .idle
    @State private var isEligibleForTrial = true

    enum Tier { case individual, family }
    enum Period { case monthly, annual }

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    header
                    tierPicker
                    periodPicker
                    selectedProductCard
                    featureList
                    ctaSection
                    footer
                }
                .padding(DS.Spacing.lg)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedProductID) {
            guard let product = selectedProduct,
                  let info = product.subscription else { return }
            isEligibleForTrial = await info.isEligibleForIntroOffer
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Restore") {
                    Task { await manager.restorePurchases() }
                }
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: DS.Spacing.md) {
            SquareEyesView(expression: mascotExpression, size: 100)
                .padding(.top, DS.Spacing.sm)

            Text("You're in control now.")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(isEligibleForTrial
                 ? "14 days free, then choose your plan. Cancel anytime."
                 : "Choose your plan. Cancel anytime.")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var tierPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionLabel(text: "Who's it for?")

            HStack(spacing: DS.Spacing.sm) {
                tierButton(.individual,
                    icon: "person",
                    title: "Just me",
                    subtitle: "1 device")
                tierButton(.family,
                    icon: "person.3",
                    title: "Family",
                    subtitle: "Up to 6 devices")
            }
        }
    }

    private func tierButton(_ tier: Tier, icon: String, title: String, subtitle: String) -> some View {
        Button { withAnimation { selectedTier = tier; updateMascot() } } label: {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title).font(DS.Font.headline)
                Text(subtitle).font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(selectedTier == tier ? DS.Color.accent : DS.Color.backgroundCard)
                    .shadow(color: DS.Color.textPrimary.opacity(0.06), radius: 8, x: 0, y: 2)
            )
            .foregroundStyle(selectedTier == tier ? .white : DS.Color.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private var periodPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionLabel(text: "Billing period")

            HStack(spacing: DS.Spacing.sm) {
                periodButton(.annual, label: "Annual", badge: "Save 40%")
                periodButton(.monthly, label: "Monthly", badge: nil)
            }
        }
    }

    private func periodButton(_ period: Period, label: String, badge: String?) -> some View {
        Button { withAnimation { selectedPeriod = period } } label: {
            HStack {
                Text(label).font(DS.Font.headline)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(DS.Font.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DS.Color.success, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(selectedPeriod == period ? DS.Color.accentMuted : DS.Color.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(selectedPeriod == period ? DS.Color.accent : Color.clear, lineWidth: 2)
                    )
            )
            .foregroundStyle(DS.Color.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private var selectedProductCard: some View {
        DSCard {
            VStack(spacing: DS.Spacing.sm) {
                if let product = selectedProduct {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.displayName)
                                .font(DS.Font.headline)
                                .foregroundStyle(DS.Color.textPrimary)
                            Text(annualEquivalent(for: product))
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                        Spacer()
                        Text(product.displayPrice)
                            .font(DS.Font.title2)
                            .foregroundStyle(DS.Color.accent)
                    }
                    .padding(DS.Spacing.md)
                } else {
                    ProgressView()
                        .padding(DS.Spacing.md)
                }
            }
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionLabel(text: "What you get")

            let features: [(String, String)] = [
                ("hand.raised.fill",     "Friction conversations before every override"),
                ("arrow.counterclockwise","2 overrides per app, per day"),
                ("chart.bar.fill",       "Lifetime impact dashboard"),
                ("person.3.fill",        selectedTier == .family ? "Full family coverage — up to 6 people" : "Personal screen time control"),
                ("lock.shield.fill",     "System-level blocking — apps can't override it"),
            ]

            ForEach(features, id: \.0) { icon, text in
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: icon)
                        .foregroundStyle(DS.Color.accent)
                        .frame(width: 20)
                    Text(text)
                        .font(DS.Font.callout)
                        .foregroundStyle(DS.Color.textPrimary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var ctaSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            if let errorMessage {
                Text(errorMessage)
                    .font(DS.Font.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await purchase() }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        let label = isEligibleForTrial
                            ? "Start 14-day free trial"
                            : "Subscribe — \(selectedProduct?.displayPrice ?? "")"
                        Text(label)
                            .font(DS.Font.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Color.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .foregroundStyle(.white)
            }
            .disabled(isPurchasing || selectedProduct == nil)
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Required Apple auto-renewal disclosure (App Store guideline 3.1.1)
            if let product = selectedProduct {
                Text("Payment of \(product.displayPrice) will be charged to your Apple ID at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in App Store account settings. Any unused portion of a free trial is forfeited on purchase.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textTertiary)
                    .multilineTextAlignment(.center)
            }

            if selectedTier == .family {
                Text("Family plan is shared automatically via Apple Family Sharing — no extra steps needed.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, DS.Spacing.lg)
    }

    // MARK: - Logic

    private var selectedProductID: String {
        switch (selectedTier, selectedPeriod) {
        case (.individual, .monthly): return SubscriptionManager.ProductID.individualMonthly
        case (.individual, .annual):  return SubscriptionManager.ProductID.individualAnnual
        case (.family,     .monthly): return SubscriptionManager.ProductID.familyMonthly
        case (.family,     .annual):  return SubscriptionManager.ProductID.familyAnnual
        }
    }

    private var selectedProduct: Product? {
        manager.product(for: selectedProductID)
    }

    private func annualEquivalent(for product: Product) -> String {
        guard selectedPeriod == .annual else {
            return "billed monthly"
        }
        let monthly = (product.price as Decimal) / 12
        let formatted = product.priceFormatStyle.format(monthly)
        return "\(formatted)/month, billed annually"
    }

    private func purchase() async {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await manager.purchase(product)
            switch result {
            case .success:
                mascotExpression = .happy
                dismiss()
            case .cancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval."
            }
        } catch {
            errorMessage = "Something went wrong. Please try again."
            mascotExpression = .concerned
        }
    }

    private func updateMascot() {
        mascotExpression = selectedTier == .family ? .happy : .idle
    }
}
