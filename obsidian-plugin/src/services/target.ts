import { FuzzySuggestModal, Notice, TFolder, normalizePath, type App } from 'obsidian';
import type { PluginSettings, SaveTarget } from '../types';

class FolderSuggestModal extends FuzzySuggestModal<TFolder> {
  private readonly folders: TFolder[];
  private resolver: ((value: TFolder | null) => void) | null = null;

  constructor(app: App) {
    super(app);
    this.folders = app.vault.getAllLoadedFiles().filter((f): f is TFolder => f instanceof TFolder);
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

export async function resolveSaveTarget(app: App, settings: PluginSettings, hintedFolder?: string): Promise<SaveTarget | null> {
  const vaultName = app.vault.getName();
  const defaultFolder = hintedFolder ?? settings.defaultFolderPath;

  let folderPath = normalizePath(defaultFolder || '/').replace(/^\/$/, '');
  if (settings.askFolderOnSave) {
    const chosen = await new FolderSuggestModal(app).choose();
    if (!chosen) return null;
    folderPath = chosen.path;
  }

  if (folderPath.length > 0) {
    const exists = app.vault.getAbstractFileByPath(folderPath);
    if (!(exists instanceof TFolder)) {
      new Notice(`Folder does not exist: ${folderPath}`);
      return null;
    }
  }

  const attachmentFolderPath = normalizePath(
    folderPath.length > 0
      ? `${folderPath}/${settings.attachmentSubfolder}`
      : settings.attachmentSubfolder
  );

  return {
    vaultName,
    folderPath,
    attachmentFolderPath
  };
}
