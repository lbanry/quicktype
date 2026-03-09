import SwiftUI

struct NotesManagementView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Note Targets")
                    .font(.title3.bold())
                Spacer()
                Button("Create") { model.createNoteTarget() }
                    .glassControl()
                Button("Import") { model.importNoteTarget() }
                    .glassControl()
            }

            List(selection: Binding(get: { model.selectedNoteID }, set: { model.selectedNoteID = $0 })) {
                ForEach(model.noteTargets) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.displayName)
                        Text(note.filePath)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .tag(note.id)
                }
            }
            .frame(minHeight: 220)
            .scrollContentBackground(.hidden)
            .glassCard()

            HStack {
                Button("Open") { model.openSelectedInExternalApp() }
                    .glassControl()
                Button("Reveal in Finder") { model.revealSelectedNoteInFinder() }
                    .glassControl()
                Button("Set External App") { model.selectExternalAppForSelectedNote() }
                    .glassControl()
                Spacer()
                Button("Remove") { model.removeSelectedNote() }
                    .glassControl()
            }
        }
        .padding()
        .glassBackground()
    }
}
