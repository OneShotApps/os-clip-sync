import mongoose from 'mongoose';

const clipboardItemSchema = new mongoose.Schema(
  {
    uid: { type: String, required: true, immutable: true },
    accountUid: { type: String, required: true, immutable: true },
    clipboardUid: { type: String, required: true, immutable: true },
    kind: { type: String, required: true, enum: ['text', 'image'], immutable: true },
    text: { type: String, maxlength: 262144 },
    imageData: { type: Buffer },
    mimeType: {
      type: String,
      required: true,
      enum: ['text/plain', 'image/png', 'image/jpeg', 'image/webp'],
      immutable: true,
    },
    sizeBytes: { type: Number, required: true, min: 1, max: 10485760, immutable: true },
    sourcePlatform: {
      type: String,
      required: true,
      enum: ['windows', 'macos', 'ios', 'android'],
      immutable: true,
    },
    sourceClientUid: { type: String, immutable: true },
    createdAt: { type: Number, required: true, min: 1, immutable: true },
    deletedAt: { type: Number, required: true, min: 0 },
  },
  {
    collection: 'clipboard_items',
    strict: 'throw',
    versionKey: false,
  },
);

clipboardItemSchema.index({ uid: 1 }, { unique: true, name: 'uk_clipboard_items_uid' });
clipboardItemSchema.index(
  { accountUid: 1, deletedAt: 1, createdAt: -1 },
  { name: 'idx_clipboard_items_account_deleted_created' },
);
clipboardItemSchema.index(
  { clipboardUid: 1, deletedAt: 1, createdAt: -1 },
  { name: 'idx_clipboard_items_clipboard_deleted_created' },
);

export const ClipboardItem = mongoose.model('ClipboardItem', clipboardItemSchema);
