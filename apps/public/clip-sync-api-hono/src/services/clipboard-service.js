import { IMAGE_MIME_TYPES, MAX_IMAGE_BYTES, MAX_TEXT_BYTES, PLATFORMS } from '../constants.js';
import { compensateClipboardItemCreate } from '../data/db.js';
import { clipboardItems, deliveryEvents } from '../data/repos/index.js';
import { AppError, ERROR_CODES } from '../errors.js';

export function clipboardImageBuffer(value) {
  if (Buffer.isBuffer(value)) return value;
  if (value?.buffer instanceof Uint8Array) {
    const bytes = Buffer.from(value.buffer);
    return bytes.subarray(0, Number.isInteger(value.position) ? value.position : bytes.length);
  }
  throw new Error('Persisted image bytes are unavailable.');
}

function publicItem(document, { includeContent = false } = {}) {
  const item = {
    uid: document.uid,
    kind: document.kind,
    mimeType: document.mimeType,
    sizeBytes: document.sizeBytes,
    sourcePlatform: document.sourcePlatform,
    createdAt: new Date(document.createdAt).toISOString(),
  };
  if (document.kind === 'text') item.text = document.text;
  if (includeContent && document.kind === 'image') {
    item.imageBase64 = clipboardImageBuffer(document.imageData).toString('base64');
  }
  return item;
}

export function prepareContent({ kind, text, imageBase64, mimeType }) {
  if (kind === 'text') {
    const sizeBytes = Buffer.byteLength(text, 'utf8');
    if (sizeBytes < 1 || sizeBytes > MAX_TEXT_BYTES) {
      throw new AppError(
        413,
        ERROR_CODES.contentTooLarge,
        `Text must contain between 1 and ${MAX_TEXT_BYTES} UTF-8 bytes.`,
      );
    }
    return { text, mimeType: 'text/plain', sizeBytes };
  }

  if (!IMAGE_MIME_TYPES.includes(mimeType)) {
    throw new AppError(415, ERROR_CODES.unsupportedContent, 'Photos must be PNG, JPEG, or WebP.');
  }
  const imageData = Buffer.from(imageBase64, 'base64');
  if (imageData.length < 1 || imageData.length > MAX_IMAGE_BYTES) {
    throw new AppError(
      413,
      ERROR_CODES.contentTooLarge,
      `Photos must contain between 1 and ${MAX_IMAGE_BYTES} bytes.`,
    );
  }
  const signatureMatches =
    (mimeType === 'image/png' &&
      imageData.subarray(0, 8).equals(Buffer.from('89504E470D0A1A0A', 'hex'))) ||
    (mimeType === 'image/jpeg' && imageData.subarray(0, 3).equals(Buffer.from('FFD8FF', 'hex'))) ||
    (mimeType === 'image/webp' &&
      imageData.subarray(0, 4).toString('ascii') === 'RIFF' &&
      imageData.subarray(8, 12).toString('ascii') === 'WEBP');
  if (!signatureMatches) {
    throw new AppError(
      415,
      ERROR_CODES.unsupportedContent,
      'Photo bytes do not match the declared PNG, JPEG, or WebP type.',
    );
  }
  return { imageData, mimeType, sizeBytes: imageData.length };
}

/** Creates owner-scoped clipboard history operations and live desktop delivery. */
export function createClipboardService({ realtimeHub }) {
  return {
    /** Stores one item, records its event, then notifies other online desktop clients. */
    async createItem({ auth, clientUid, sourcePlatform, kind, text, imageBase64, mimeType }) {
      if (!PLATFORMS.includes(sourcePlatform)) {
        throw new AppError(
          400,
          ERROR_CODES.invalidRequest,
          'A supported source platform is required.',
        );
      }
      const content = prepareContent({ kind, text, imageBase64, mimeType });
      const document = await clipboardItems.createClipboardItem({
        accountUid: auth.accountUid,
        clipboardUid: auth.clipboardUid,
        kind,
        sourcePlatform,
        ...content,
      });
      try {
        await deliveryEvents.createDeliveryEvent({
          accountUid: auth.accountUid,
          clipboardUid: auth.clipboardUid,
          itemUid: document.uid,
          sourceClientUid: clientUid,
          contentKind: kind,
        });
      } catch (error) {
        await compensateClipboardItemCreate({ accountUid: auth.accountUid, itemUid: document.uid });
        throw error;
      }
      const item = publicItem(document, { includeContent: true });
      realtimeHub.broadcast({
        accountUid: auth.accountUid,
        sourceClientUid: clientUid,
        item,
      });
      return item;
    },

    /** Returns one page of the authenticated account's complete persisted history. */
    async listItems({ auth, page, pageSize }) {
      const { items, total } = await clipboardItems.listClipboardItems({
        accountUid: auth.accountUid,
        page,
        pageSize,
      });
      return {
        items: items.map((item) => publicItem(item)),
        pagination: {
          page,
          pageSize,
          total,
          totalPages: Math.ceil(total / pageSize),
        },
      };
    },

    /** Returns one owner-scoped item including image bytes when needed for manual copy. */
    async getItem({ auth, itemUid }) {
      const document = await clipboardItems.findClipboardItem({
        accountUid: auth.accountUid,
        itemUid,
      });
      if (!document) {
        throw new AppError(404, ERROR_CODES.itemNotFound, 'Clipboard item was not found.');
      }
      return publicItem(document, { includeContent: true });
    },

    /** Soft deletes one owner-scoped history item. */
    async deleteItem({ auth, itemUid }) {
      const document = await clipboardItems.deleteClipboardItem({
        accountUid: auth.accountUid,
        itemUid,
      });
      if (!document) {
        throw new AppError(404, ERROR_CODES.itemNotFound, 'Clipboard item was not found.');
      }
    },
  };
}
