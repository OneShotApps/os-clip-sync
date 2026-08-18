import { describe, expect, it, vi } from 'vitest';

import { createRealtimeHub } from '../src/services/realtime-hub.js';

function socket() {
  return { readyState: 1, send: vi.fn(), close: vi.fn() };
}

describe('real-time hub', () => {
  it('delivers only to other online desktop clients', () => {
    const hub = createRealtimeHub();
    const source = socket();
    const receiver = socket();
    hub.register({ accountUid: 'account-a', clientUid: 'source', socket: source });
    hub.register({ accountUid: 'account-a', clientUid: 'receiver', socket: receiver });
    source.send.mockClear();
    receiver.send.mockClear();

    const delivered = hub.broadcast({
      accountUid: 'account-a',
      sourceClientUid: 'source',
      item: { uid: 'item' },
    });

    expect(delivered).toBe(1);
    expect(source.send).not.toHaveBeenCalled();
    expect(receiver.send).toHaveBeenCalledOnce();
  });

  it('does not retain a replay queue for offline clients', () => {
    const hub = createRealtimeHub();

    expect(
      hub.broadcast({ accountUid: 'offline-account', sourceClientUid: 'source', item: {} }),
    ).toBe(0);
    expect(hub.connectionCount('offline-account')).toBe(0);
  });
});
