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
                Button("Import") { model.importNoteTarget() }
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

            HStack {
                Button("Open") { model.openSelectedInExternalApp() }
                Button("Reveal in Finder") { model.revealSelectedNoteInFinder() }
                Button("Set External App") { model.selectExternalAppForSelectedNote() }
                Spacer()
                Button("Remove") { model.removeSelectedNote() }
            }
        }
        .padding()
    }
}
