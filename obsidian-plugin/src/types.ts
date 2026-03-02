export type RequestedAction = 'save' | 'summarize_then_save';

export interface AttachmentInput {
  name: string;
  mimeType: string;
  sourcePath?: string;
  bytes?: string;
  sha256?: string;
}

export interface TargetHint {
  vaultName?: string;
  folderPath?: string;
}

export interface QuickTypeClipPayloadV1 {
  version: 1;
  clipId: string;
  capturedAt: string;
  sourceAppName: string;
  sourceBundleId: string;
  sourceWindowTitle?: string;
  sourceUrl?: string;
  contentText: string;
  attachments?: AttachmentInput[];
  requestedAction: RequestedAction;
  targetHint?: TargetHint;
}

export interface SaveTarget {
  vaultName: string;
  folderPath: string;
  attachmentFolderPath: string;
}

export interface SummaryResult {
  text: string;
  model?: string;
}

export interface ClipSaveResult {
  notePath: string;
  attachmentsSaved: string[];
  summaryIncluded: boolean;
}

export interface PluginSettings {
  defaultFolderPath: string;
  attachmentSubfolder: string;
  askFolderOnSave: boolean;
  defaultSummarizeBeforeSave: boolean;
  pinnedVaultName: string;
  aiEnabled: boolean;
  aiEndpoint: string;
  aiModel: string;
  aiApiKey: string;
  aiMaxTokens: number;
  aiTemperature: number;
}

export const DEFAULT_SETTINGS: PluginSettings = {
  defaultFolderPath: '',
  attachmentSubfolder: 'Attachments/QuickType',
  askFolderOnSave: true,
  defaultSummarizeBeforeSave: false,
  pinnedVaultName: '',
  aiEnabled: false,
  aiEndpoint: 'https://api.openai.com/v1/chat/completions',
  aiModel: 'gpt-4o-mini',
  aiApiKey: '',
  aiMaxTokens: 220,
  aiTemperature: 0.2
};
