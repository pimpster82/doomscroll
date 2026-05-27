import SwiftUI

struct SettingsView: View {
    @State private var profile = UserProfile.load() ?? UserProfile(birthYear: 1990, gender: .preferNotToSay)
    @State private var saved = false

    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

            Form {
                Section("Your profile") {
                    Picker("Birth year", selection: $profile.birthYear) {
                        ForEach((1940...currentYear - 10).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }

                    Picker("Gender", selection: $profile.gender) {
                        ForEach(UserProfile.Gender.allCases, id: \.self) { g in
                            Text(g.displayName).tag(g)
                        }
                    }

                    Stepper("Life expectancy: \(profile.lifeExpectancy) yrs", value: $profile.lifeExpectancy, in: 60...100)
                }

                Section {
                    Button("Save") {
                        profile.save()
                        withAnimation { saved = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                    }
                    .foregroundStyle(.white)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) {
            if saved {
                Text("Saved")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
            }
        }
        .animation(.easeInOut, value: saved)
    }
}
