import { App, Modal, Notice, Plugin } from 'obsidian';
import { DEFAULT_SETTINGS, type ClipSaveResult, type PluginSettings, type QuickTypeClipPayloadV1 } from './types';
import { QuickTypeSettingTab } from './settings';
import { decodeQuickTypePayload } from './services/payload';
import { resolveSaveTarget } from './services/target';
import { summarizeClip } from './services/ai';
import { importAttachments } from './services/attachments';
import { writeClipNote } from './services/writer';

class SummaryFailureModal extends Modal {
  private resolver: ((saveWithoutSummary: boolean) => void) | null = null;

  constructor(app: App, message: string) {
    super(app);
    this.setTitle('AI summary failed');
    this.contentEl.createEl('p', { text: message });
  }

  async ask(): Promise<boolean> {
    return new Promise((resolve) => {
      this.resolver = resolve;
      const buttonRow = this.contentEl.createDiv({ cls: 'quicktype-modal-buttons' });

      const saveButton = buttonRow.createEl('button', { text: 'Save original clip' });
      saveButton.onclick = () => {
        this.resolver?.(true);
        this.close();
      };

      const cancelButton = buttonRow.createEl('button', { text: 'Cancel' });
      cancelButton.onclick = () => {
        this.resolver?.(false);
        this.close();
      };

      this.open();
    });
  }

  onClose(): void {
    super.onClose();
    if (this.resolver) {
      this.resolver(false);
      this.resolver = null;
    }
  }
}

export default class QuickTypeClipPlugin extends Plugin {
  settings: PluginSettings = DEFAULT_SETTINGS;

  async onload(): Promise<void> {
    await this.loadSettings();

    this.addSettingTab(new QuickTypeSettingTab(this.app, this));

    this.registerObsidianProtocolHandler('quicktype-clip', async (params) => {
      await this.handleProtocolClip(params);
    });

    this.addCommand({
      id: 'quicktype-handle-protocol-payload',
      name: 'Process QuickType payload from URI clipboard',
      callback: async () => {
        const clipboard = await navigator.clipboard.readText();
        const url = new URL(clipboard);
        if (url.protocol !== 'obsidian:' || url.hostname !== 'quicktype-clip') {
          new Notice('Clipboard does not contain a quicktype protocol URL.');
          return;
        }
        const params = Object.fromEntries(url.searchParams.entries());
        await this.handleProtocolClip(params);
      }
    });
  }

  async handleProtocolClip(params: Record<string, string>): Promise<ClipSaveResult | null> {
    const payload = decodeQuickTypePayload(params);
    if (!payload) return null;

    const target = await resolveSaveTarget(
      this.app,
      this.settings,
      payload.targetHint?.folderPath
    );
    if (!target) {
      new Notice('QuickType clip save canceled.');
      return null;
    }

    const shouldSummarize = this.shouldSummarize(payload);
    let summary = null;

    if (shouldSummarize) {
      summary = await summarizeClip(this.settings, payload);
      if (!summary) {
        const shouldContinue = await new SummaryFailureModal(
          this.app,
          'Would you like to save the original clip without a summary?'
        ).ask();
        if (!shouldContinue) {
          new Notice('Canceled clip save.');
          return null;
        }
      }
    }

    const attachmentImport = await importAttachments(
      this.app,
      payload.attachments,
      target.attachmentFolderPath
    );

    const result = await writeClipNote(
      this.app,
      payload,
      target,
      summary,
      attachmentImport.savedPaths,
      attachmentImport.embedLines
    );

    return result;
  }

  private shouldSummarize(payload: QuickTypeClipPayloadV1): boolean {
    if (payload.requestedAction === 'summarize_then_save') return true;
    return this.settings.defaultSummarizeBeforeSave;
  }

  async loadSettings(): Promise<void> {
    this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
  }

  async saveSettings(): Promise<void> {
    await this.saveData(this.settings);
  }
}
