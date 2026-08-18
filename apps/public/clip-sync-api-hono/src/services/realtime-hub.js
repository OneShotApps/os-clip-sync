/**
 * Tracks only currently connected desktop clients. It intentionally keeps no replay queue.
 *
 * @returns {object} In-memory real-time connection hub.
 */
export function createRealtimeHub() {
  const accounts = new Map();

  function remove({ accountUid, clientUid, socket }) {
    const clients = accounts.get(accountUid);
    if (!clients || clients.get(clientUid) !== socket) return;
    clients.delete(clientUid);
    if (clients.size === 0) accounts.delete(accountUid);
  }

  return {
    /** Registers one online desktop socket until it closes. */
    register({ accountUid, clientUid, socket }) {
      let clients = accounts.get(accountUid);
      if (!clients) {
        clients = new Map();
        accounts.set(accountUid, clients);
      }
      const previous = clients.get(clientUid);
      if (previous && previous !== socket) previous.close(1000, 'Replaced by a newer connection.');
      clients.set(clientUid, socket);
      socket.send(JSON.stringify({ type: 'connected' }));
    },

    /** Removes one socket without affecting a newer connection using the same client UID. */
    remove,

    /** Sends a new item to other online desktops only; no event is queued for offline clients. */
    broadcast({ accountUid, sourceClientUid, item }) {
      const clients = accounts.get(accountUid);
      if (!clients) return 0;
      let delivered = 0;
      const message = JSON.stringify({ type: 'clipboard-item', item });
      for (const [clientUid, socket] of clients) {
        if (clientUid === sourceClientUid || socket.readyState !== 1) continue;
        socket.send(message);
        delivered += 1;
      }
      return delivered;
    },

    /** Returns current connection count for health diagnostics and tests. */
    connectionCount(accountUid) {
      return accounts.get(accountUid)?.size ?? 0;
    },
  };
}
