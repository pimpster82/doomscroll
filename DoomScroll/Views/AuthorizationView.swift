import SwiftUI

struct AuthorizationView: View {
    @EnvironmentObject var authManager: AuthorizationManager

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.xl) {
                Spacer()

                SquareEyesView(expression: .concerned, size: 120)

                VStack(spacing: DS.Spacing.md) {
                    Text("One permission to get started")
                        .font(DS.Font.title)
                        .foregroundStyle(DS.Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Screen Time access lets DoomScroll track which apps you use and apply friction when you open them. Nothing leaves your device.")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, DS.Spacing.md)

                VStack(spacing: DS.Spacing.sm) {
                    permissionRow(icon: "eye.slash",    text: "No data leaves your device")
                    permissionRow(icon: "person.slash", text: "No account required")
                    permissionRow(icon: "lock.shield",  text: "Restrictions you set, not Apple's")
                }
                .padding(DS.Spacing.md)
                .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .shadow(color: DS.Color.textPrimary.opacity(0.05), radius: 6, x: 0, y: 2)
                .padding(.horizontal, DS.Spacing.lg)

                Spacer()

                VStack(spacing: DS.Spacing.sm) {
                    DSPrimaryButton(label: "Grant Screen Time access") {
                        Task { await authManager.requestAuthorization() }
                    }

                    if let error = authManager.authorizationError {
                        Text(error)
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.warning)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.md)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)
            }
            .padding(DS.Spacing.lg)
        }
    }

    private func permissionRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(DS.Color.accent)
                .frame(width: 20)
            Text(text)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.textPrimary)
            Spacer()
        }
    }
}
