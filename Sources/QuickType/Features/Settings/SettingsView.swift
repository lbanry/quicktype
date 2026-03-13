import Carbon
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            generalTab
                .tabItem { Text("General") }
            featuresTab
                .tabItem { Text("Features") }
            PromptLibraryView()
                .environmentObject(model)
                .tabItem { Text("Prompts") }
            reliabilityTab
                .tabItem { Text("Reliability") }
            NotesManagementView()
                .environmentObject(model)
                .tabItem { Text("Notes") }
        }
        .frame(minWidth: 700, minHeight: 520)
        .padding()
        .glassBackground()
    }

    private var generalTab: some View {
        Form {
            Picker("Insertion Position", selection: Binding(
                get: { model.settings.insertionPosition },
                set: { newValue in model.updateSettings { $0.insertionPosition = newValue } }
            )) {
                Text("Top").tag(InsertionPosition.top)
                Text("Bottom").tag(InsertionPosition.bottom)
            }

            Picker("Timestamp Mode", selection: Binding(
                get: { model.settings.timestampMode },
                set: { newValue in model.updateSettings { $0.timestampMode = newValue } }
            )) {
                Text("Date + Time").tag(TimestampMode.dateTime)
                Text("Date Only").tag(TimestampMode.dateOnly)
                Text("Time Only").tag(TimestampMode.timeOnly)
                Text("Custom").tag(TimestampMode.custom)
            }

            TextField("Custom Date Format", text: Binding(
                get: { model.settings.customDateFormat },
                set: { newValue in model.updateSettings { $0.customDateFormat = newValue } }
            ))
            .disabled(model.settings.timestampMode != .custom)

            TextField("Date Locale", text: Binding(
                get: { model.settings.dateLocaleIdentifier },
                set: { newValue in model.updateSettings { $0.dateLocaleIdentifier = newValue } }
            ))

            Toggle("Use UTC Time Zone", isOn: Binding(
                get: { model.settings.useUTC },
                set: { newValue in model.updateSettings { $0.useUTC = newValue } }
            ))

            Picker("Submit Behavior", selection: Binding(
                get: { model.settings.submitBehavior },
                set: { newValue in model.updateSettings { $0.submitBehavior = newValue } }
            )) {
                Text("Dismiss Window").tag(SubmitBehavior.dismissWindow)
                Text("Keep Window Visible").tag(SubmitBehavior.keepWindowVisible)
            }

            Picker("Stay On Top", selection: Binding(
                get: { model.settings.stayOnTopPolicy },
                set: { newValue in model.updateSettings { $0.stayOnTopPolicy = newValue } }
            )) {
                Text("Always").tag(StayOnTopPolicy.always)
                Text("Only When Active").tag(StayOnTopPolicy.onlyWhenActive)
            }

            Toggle("Show Menu Bar Icon", isOn: Binding(
                get: { model.settings.showMenuBarIcon },
                set: { newValue in model.updateSettings { $0.showMenuBarIcon = newValue } }
            ))

            Toggle("Launch At Login", isOn: Binding(
                get: { model.settings.launchAtLogin },
                set: { newValue in model.updateSettings { $0.launchAtLogin = newValue } }
            ))

            Divider()
            Text("AI Automation")
                .font(.headline)

            HStack {
                Text("AI App")
                Spacer()
                Text(model.settings.aiAppPath.isEmpty ? "Not selected" : URL(fileURLWithPath: model.settings.aiAppPath).lastPathComponent)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button("Choose") { model.selectAIApplication() }
                    .glassControl()
                if !model.settings.aiAppPath.isEmpty {
                    Button("Clear") { model.clearAIApplication() }
                        .glassControl()
                }
            }

            TextField("AI app path", text: Binding(
                get: { model.settings.aiAppPath },
                set: { newValue in model.updateSettings { $0.aiAppPath = newValue } }
            ))

            Toggle("Auto-submit after paste", isOn: Binding(
                get: { model.settings.aiAutoSubmit },
                set: { newValue in model.updateSettings { $0.aiAutoSubmit = newValue } }
            ))

            Text("Manage reusable prompts in the Prompts tab. Shortcuts start disabled until you assign them.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()
            Text("Obsidian Integration")
                .font(.headline)

            Toggle("Enable Obsidian integration", isOn: Binding(
                get: { model.settings.obsidianIntegrationEnabled },
                set: { newValue in model.updateSettings { $0.obsidianIntegrationEnabled = newValue } }
            ))

            HStack {
                TextField("Obsidian default folder path", text: Binding(
                    get: { model.settings.obsidianDefaultFolderPath },
                    set: { newValue in model.updateSettings { $0.obsidianDefaultFolderPath = newValue } }
                ))
                Button("Select Path") { model.selectObsidianFolderPath() }
                    .glassControl()
            }

            TextField("Obsidian target vault name (optional)", text: Binding(
                get: { model.settings.obsidianTargetVaultName },
                set: { newValue in model.updateSettings { $0.obsidianTargetVaultName = newValue } }
            ))

            Toggle("Default to summarize before Obsidian save", isOn: Binding(
                get: { model.settings.obsidianDefaultSummarizeBeforeSave },
                set: { newValue in model.updateSettings { $0.obsidianDefaultSummarizeBeforeSave = newValue } }
            ))
        }
        .padding(8)
        .scrollContentBackground(.hidden)
        .glassCard()
    }

    private var featuresTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Features")
                        .font(.headline)

                    featureToggleRow("Track clipboard changes", isOn: Binding(
                        get: { model.settings.clipboardMonitoringEnabled },
                        set: { newValue in model.updateSettings { $0.clipboardMonitoringEnabled = newValue } }
                    ))

                    featureToggleRow("Capture copied links automatically", isOn: Binding(
                        get: { model.settings.automaticLinkCaptureEnabled },
                        set: { newValue in model.updateSettings { $0.automaticLinkCaptureEnabled = newValue } }
                    ))

                    featureToggleRow("Enable AI features", isOn: Binding(
                        get: { model.settings.aiFeaturesEnabled },
                        set: { newValue in model.updateSettings { $0.aiFeaturesEnabled = newValue } }
                    ))

                    Text("New links now default into the Recent folder. Disable auto-capture if you want clipboard text without link extraction.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("Feature Shortcuts")
                        .font(.subheadline.weight(.semibold))
                    Text("Captured shortcuts appear here immediately. Press Escape while recording to clear one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    shortcutRow("Open Capture", keyPath: \.hotkey)
                    shortcutRow("Send Selection to AI", keyPath: \.aiCaptureHotkey)
                    shortcutRow("Open Settings", keyPath: \.openSettingsHotkey)
                }
                .padding(16)
                .glassCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Navigation Shortcuts")
                        .font(.headline)
                    Text("These drive in-app navigation for links, clips, and the capture header.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    shortcutRow("Next Item", keyPath: \.nextNavigationHotkey)
                    shortcutRow("Previous Item", keyPath: \.previousNavigationHotkey)
                    shortcutRow("Activate / Expand", keyPath: \.activateSelectionHotkey)
                    shortcutRow("Edit Selection", keyPath: \.editSelectionHotkey)
                    shortcutRow("Copy Selection", keyPath: \.copySelectionHotkey)
                    shortcutRow("Delete Selection", keyPath: \.deleteSelectionHotkey)
                    shortcutRow("Switch Pane / Section", keyPath: \.switchPaneHotkey)
                }
                .padding(16)
                .glassCard()
            }
            .padding(8)
        }
    }

    private var reliabilityTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper("Backup retention: \(model.settings.backupRetentionCount)", value: Binding(
                get: { model.settings.backupRetentionCount },
                set: { newValue in model.updateSettings { $0.backupRetentionCount = newValue } }
            ), in: 1...200)

            HStack {
                Button("Run Integrity Scan") { model.refreshRecoveryIssues() }
                    .glassControl()
                Button("Restore Latest Backup") { model.restoreLatestBackupForSelectedNote() }
                    .glassControl()
                Button("Copy Diagnostics") { model.copyDiagnostics() }
                    .glassControl()
                Button("Export Settings") { model.exportSettings() }
                    .glassControl()
                Spacer()
                Button("Delete App Metadata", role: .destructive) { model.deleteAllAppMetadata() }
                    .glassControl()
            }

            if model.recoveryIssues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No recovery issues")
                        .font(.headline)
                    Text("Your linked note targets are healthy.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassCard()
            } else {
                List(model.recoveryIssues) { issue in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(issue.issueType.rawValue)
                            Text("Note ID: \(issue.noteID.uuidString)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Relink") {
                            model.relinkNote(issue.noteID)
                        }
                        .glassControl()
                    }
                }
                .scrollContentBackground(.hidden)
                .glassCard()
            }
        }
        .padding(8)
    }

    private func shortcutRow(_ title: String, keyPath: WritableKeyPath<AppSettings, HotkeyDefinition>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(HotkeyRecorderView.describe(model.settings[keyPath: keyPath]))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
            HotkeyRecorderView(hotkey: Binding(
                get: { model.settings[keyPath: keyPath] },
                set: { newValue in
                    model.updateSettings { $0[keyPath: keyPath] = newValue }
                }
            ))
            Button("Clear") {
                model.updateSettings { $0[keyPath: keyPath] = .disabled }
            }
            .glassControl()
        }
    }

    private func featureToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
    }
}
