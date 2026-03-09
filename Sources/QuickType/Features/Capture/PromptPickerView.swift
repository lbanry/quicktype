import AppKit
import Carbon
import SwiftUI

struct PromptPickerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedPromptID: UUID?
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Prompt")
                .font(.title3.bold())

            Text("Press Return to use the default prompt, or pick a prompt below.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if model.prompts.isEmpty {
                Text("No prompts available. Add one in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            } else {
                List(model.prompts, selection: $selectedPromptID) { prompt in
                    Button {
                        model.submitPendingSelection(with: prompt.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(prompt.title)
                                        .font(.headline)
                                    if model.settings.defaultPromptID == prompt.id {
                                        Text("Default")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.thinMaterial, in: Capsule())
                                    }
                                }
                                Text(prompt.body)
                                    .font(.body.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .tag(prompt.id)
                }
                .scrollContentBackground(.hidden)
                .glassCard()
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    model.dismissPromptPicker()
                }
                Button("Use Default") {
                    model.submitPendingSelectionWithDefaultPrompt()
                }
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 360)
        .glassBackground()
        .onAppear {
            selectedPromptID = model.settings.defaultPromptID ?? model.prompts.first?.id
            installKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }

    private func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == UInt16(kVK_Return) || event.keyCode == UInt16(kVK_ANSI_KeypadEnter) else {
                return event
            }
            model.submitPendingSelectionWithDefaultPrompt()
            return nil
        }
    }

    private func removeKeyboardMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}
