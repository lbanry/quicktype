import { App, FuzzySuggestModal, PluginSettingTab, Setting, TFolder } from 'obsidian';
import type QuickTypeClipPlugin from './main';

class FolderSelectModal extends FuzzySuggestModal<TFolder> {
  private folders: TFolder[];
  private resolver: ((value: TFolder | null) => void) | null = null;

  constructor(app: App) {
    super(app);
    this.folders = app.vault.getAllLoadedFiles().filter((f: unknown): f is TFolder => f instanceof TFolder);
  }

  getItems(): TFolder[] {
    return this.folders;
  }

  getItemText(item: TFolder): string {
    return item.path;
  }

  onChooseItem(item: TFolder): void {
    this.resolver?.(item);
  }

  async choose(): Promise<TFolder | null> {
    return new Promise((resolve) => {
      this.resolver = resolve;
      this.open();
    });
  }

  onClose(): void {
    super.onClose();
    if (this.resolver) {
      this.resolver(null);
      this.resolver = null;
    }
  }
}

export class QuickTypeSettingTab extends PluginSettingTab {
  plugin: QuickTypeClipPlugin;

  constructor(app: App, plugin: QuickTypeClipPlugin) {
    super(app, plugin);
    this.plugin = plugin;
  }

  display(): void {
    const { containerEl } = this;
    containerEl.empty();

    containerEl.createEl('h2', { text: 'QuickType Clip Inbox' });

    new Setting(containerEl)
      .setName('Default folder')
      .setDesc('Existing folder path for clip notes when folder picker is not used.')
      .addText((text) => text
        .setPlaceholder('Clips')
        .setValue(this.plugin.settings.defaultFolderPath)
        .onChange(async (value) => {
          this.plugin.settings.defaultFolderPath = value.trim();
          await this.plugin.saveSettings();
        }))
      .addButton((button) => button
        .setButtonText('Choose')
        .onClick(async () => {
          const choice = await new FolderSelectModal(this.app).choose();
          if (!choice) return;
          this.plugin.settings.defaultFolderPath = choice.path;
          await this.plugin.saveSettings();
          this.display();
        }));

    new Setting(containerEl)
      .setName('Ask folder on every save')
      .setDesc('If enabled, prompt for an existing folder before writing each clip.')
      .addToggle((toggle) => toggle
        .setValue(this.plugin.settings.askFolderOnSave)
        .onChange(async (value) => {
          this.plugin.settings.askFolderOnSave = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Attachment subfolder')
      .setDesc('Relative subfolder under chosen clip folder for image/PDF attachments.')
      .addText((text) => text
        .setValue(this.plugin.settings.attachmentSubfolder)
        .onChange(async (value) => {
          this.plugin.settings.attachmentSubfolder = value.trim();
          await this.plugin.saveSettings();
        }));

    containerEl.createEl('h3', { text: 'AI Summarization (BYO Key)' });

    new Setting(containerEl)
      .setName('Enable AI summaries')
      .setDesc('When enabled, clip content can be summarized before save.')
      .addToggle((toggle) => toggle
        .setValue(this.plugin.settings.aiEnabled)
        .onChange(async (value) => {
          this.plugin.settings.aiEnabled = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Default summarize before save')
      .setDesc('Apply summary by default unless QuickType requests save-only.')
      .addToggle((toggle) => toggle
        .setValue(this.plugin.settings.defaultSummarizeBeforeSave)
        .onChange(async (value) => {
          this.plugin.settings.defaultSummarizeBeforeSave = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('AI endpoint')
      .setDesc('OpenAI-compatible chat completions endpoint.')
      .addText((text) => text
        .setValue(this.plugin.settings.aiEndpoint)
        .onChange(async (value) => {
          this.plugin.settings.aiEndpoint = value.trim();
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Model')
      .setDesc('Model name used for summarization.')
      .addText((text) => text
        .setValue(this.plugin.settings.aiModel)
        .onChange(async (value) => {
          this.plugin.settings.aiModel = value.trim();
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('API key')
      .setDesc('Stored in plugin settings. Keep your vault/device secure.')
      .addText((text) => text
        .setValue(this.plugin.settings.aiApiKey)
        .onChange(async (value) => {
          this.plugin.settings.aiApiKey = value.trim();
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Max tokens')
      .addText((text) => text
        .setValue(String(this.plugin.settings.aiMaxTokens))
        .onChange(async (value) => {
          const parsed = Number(value);
          if (Number.isFinite(parsed) && parsed > 0) {
            this.plugin.settings.aiMaxTokens = parsed;
            await this.plugin.saveSettings();
          }
        }));

    new Setting(containerEl)
      .setName('Temperature')
      .addText((text) => text
        .setValue(String(this.plugin.settings.aiTemperature))
        .onChange(async (value) => {
          const parsed = Number(value);
          if (Number.isFinite(parsed) && parsed >= 0) {
            this.plugin.settings.aiTemperature = parsed;
            await this.plugin.saveSettings();
          }
        }));

    containerEl.createEl('p', {
      text: 'Privacy: AI summary sends clip text and source metadata to your configured provider when enabled.'
    });
  }
}
