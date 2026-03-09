import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to QuickType")
                .font(.title2.bold())
            Text("Create or import a text/markdown file and start capturing notes from anywhere.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Create Note") { model.createNoteTarget() }
                    .glassControl()
                Button("Import Note") { model.importNoteTarget() }
                    .glassControl()
            }

            Text("No telemetry is sent by default. Data is local-first.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .glassCard()
        .padding()
        .glassBackground()
    }
}
