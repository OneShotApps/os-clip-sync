import { describe, expect, it } from 'vitest';

import { clipboardImageBuffer, prepareContent } from '../src/services/clipboard-service.js';

describe('clipboard content validation', () => {
  it('accepts bytes that match the declared photo type', () => {
    const imageData = Buffer.from('89504E470D0A1A0A00000000', 'hex');

    const prepared = prepareContent({
      kind: 'image',
      imageBase64: imageData.toString('base64'),
      mimeType: 'image/png',
    });

    expect(prepared.imageData).toEqual(imageData);
    expect(prepared.sizeBytes).toBe(imageData.length);
  });

  it('rejects arbitrary bytes labeled as a photo', () => {
    expect(() =>
      prepareContent({
        kind: 'image',
        imageBase64: Buffer.from('not a photo').toString('base64'),
        mimeType: 'image/png',
      }),
    ).toThrow('Photo bytes do not match');
  });

  it('normalizes BSON Binary values returned by lean MongoDB reads', () => {
    const backingBytes = Uint8Array.from([1, 2, 3, 0, 0]);

    expect(clipboardImageBuffer({ buffer: backingBytes, position: 3 })).toEqual(
      Buffer.from([1, 2, 3]),
    );
  });
});
