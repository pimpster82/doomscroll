import SwiftUI

struct AuthorizationView: View {
    @EnvironmentObject var authManager: AuthorizationManager

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "hourglass.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.8))

                VStack(spacing: 12) {
                    Text("DoomScroll needs one permission")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Screen Time access lets DoomScroll track which apps you use and apply friction when you open them. Nothing leaves your device.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                Button("Grant permission") {
                    Task { await authManager.requestAuthorization() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .padding(32)
        }
        .preferredColorScheme(.dark)
    }
}
