import { describe, expect, it, vi } from 'vitest';

import { createApp } from '../src/app.js';

function dependencies() {
  return {
    config: { corsOrigins: ['*'] },
    authService: {
      requestEmailCode: vi.fn(),
      verifyEmailCode: vi.fn(),
      signInWithGoogle: vi.fn(),
      verifyAccessToken: vi.fn().mockResolvedValue({
        accountUid: 'A'.repeat(32),
        clipboardUid: 'B'.repeat(32),
        email: 'person@example.com',
      }),
    },
    clipboardService: {
      listItems: vi.fn().mockResolvedValue({
        items: [],
        pagination: { page: 1, pageSize: 50, total: 0, totalPages: 0 },
      }),
      createItem: vi.fn(),
      getItem: vi.fn(),
      deleteItem: vi.fn(),
    },
    deviceService: {
      list: vi.fn().mockResolvedValue([]),
      register: vi.fn().mockImplementation(async ({ clientUid, platform, name }) => ({
        uid: clientUid,
        platform,
        name,
      })),
      rename: vi.fn().mockImplementation(async ({ deviceUid, name }) => ({
        uid: deviceUid,
        platform: 'macos',
        name,
      })),
    },
    realtimeHub: {},
    upgradeWebSocket: () => (context) => context.text('upgrade unavailable in unit tests', 501),
  };
}

describe('Clip Sync API', () => {
  it('returns package identity from the public health route', async () => {
    const response = await createApp(dependencies()).request('/');
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.name).toBe('clip-sync-api-hono');
    expect(body.serverTime).toBeTruthy();
  });

  it('validates email requests before calling the auth service', async () => {
    const values = dependencies();
    const response = await createApp(values).request('/ux/v1/auth/email/request', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'not-an-email' }),
    });

    expect(response.status).toBe(400);
    expect(values.authService.requestEmailCode).not.toHaveBeenCalled();
  });

  it('returns a structured client error for malformed JSON', async () => {
    const response = await createApp(dependencies()).request('/ux/v1/auth/email/request', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: '{',
    });
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body.code).toBe('CLIP_SYNC_INVALID_REQUEST');
  });

  it('requires a bearer token for private history', async () => {
    const response = await createApp(dependencies()).request('/ux/v1/history');
    const body = await response.json();

    expect(response.status).toBe(401);
    expect(body.code).toBe('CLIP_SYNC_AUTHENTICATION_REQUIRED');
  });

  it('registers the current device behind account authentication', async () => {
    const values = dependencies();
    const clientUid = 'C'.repeat(32);
    const response = await createApp(values).request('/ux/v1/devices/register', {
      method: 'POST',
      headers: {
        authorization: 'Bearer token',
        'content-type': 'application/json',
      },
      body: JSON.stringify({ clientUid, platform: 'macos', name: 'Studio Mac' }),
    });
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.device.name).toBe('Studio Mac');
    expect(values.deviceService.register).toHaveBeenCalledWith(
      expect.objectContaining({ clientUid, platform: 'macos', name: 'Studio Mac' }),
    );
  });

  it('validates device names before attempting a rename', async () => {
    const values = dependencies();
    const response = await createApp(values).request(`/ux/v1/devices/${'D'.repeat(32)}`, {
      method: 'PATCH',
      headers: {
        authorization: 'Bearer token',
        'content-type': 'application/json',
      },
      body: JSON.stringify({ name: '   ' }),
    });

    expect(response.status).toBe(400);
    expect(values.deviceService.rename).not.toHaveBeenCalled();
  });
});
