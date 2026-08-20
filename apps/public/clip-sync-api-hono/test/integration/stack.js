import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';

import mongoose from 'mongoose';

const apiUrl = process.env.CLIP_SYNC_INTEGRATION_API_URL ?? 'http://127.0.0.1:4200';
const mailpitUrl = process.env.CLIP_SYNC_INTEGRATION_MAILPIT_URL ?? 'http://127.0.0.1:8025';
const mongoUrl =
  process.env.CLIP_SYNC_INTEGRATION_MONGO_URL ??
  'mongodb://clip_sync:local-mongo-password@127.0.0.1:27017/clip_sync?authSource=admin';

async function request(path, { token, expected = 200, ...options } = {}) {
  const response = await fetch(`${apiUrl}${path}`, {
    ...options,
    headers: {
      ...(options.body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  });
  assert.equal(
    response.status,
    expected,
    `${options.method ?? 'GET'} ${path} returned ${response.status}`,
  );
  return response.status === 204 ? null : response.json();
}

async function sleep(milliseconds) {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function findCode(email) {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const list = await fetch(`${mailpitUrl}/api/v1/messages`).then((response) => response.json());
    for (const message of list.messages ?? []) {
      if (!JSON.stringify(message).includes(email)) continue;
      const detail = await fetch(`${mailpitUrl}/api/v1/message/${message.ID}`).then((response) =>
        response.json(),
      );
      const match = `${detail.Text ?? ''} ${detail.HTML ?? ''}`.match(/\b(\d{6})\b/);
      if (match) return match[1];
    }
    await sleep(200);
  }
  throw new Error(`Mailpit did not receive a sign-in code for ${email}.`);
}

async function signIn(email) {
  const challenge = await request('/ux/v1/auth/email/request', {
    method: 'POST',
    expected: 202,
    body: JSON.stringify({ email }),
  });
  const code = await findCode(email);
  return request('/ux/v1/auth/email/verify', {
    method: 'POST',
    body: JSON.stringify({ challengeUid: challenge.challengeUid, code }),
  });
}

async function simulateLegacyClipboardItem(itemUid) {
  await mongoose.connect(mongoUrl);
  try {
    await mongoose.connection
      .collection('clipboard_items')
      .updateOne({ uid: itemUid }, { $unset: { sourceClientUid: '' } });
  } finally {
    await mongoose.disconnect();
  }
}

function openSocket({ token, clientUid }) {
  const url = apiUrl.replace(/^http/, 'ws');
  const socket = new WebSocket(`${url}/ux/v1/realtime?clientUid=${clientUid}&platform=macos`, {
    headers: { authorization: `Bearer ${token}` },
  });
  const messages = [];
  socket.addEventListener('message', (event) => messages.push(JSON.parse(event.data)));
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('WebSocket did not connect.')), 5000);
    socket.addEventListener('open', () => {
      clearTimeout(timeout);
      resolve({ socket, messages });
    });
    socket.addEventListener('error', () => reject(new Error('WebSocket connection failed.')));
  });
}

async function waitForMessage(messages, type) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const message = messages.find((candidate) => candidate.type === type);
    if (message) return message;
    await sleep(100);
  }
  throw new Error(`WebSocket did not receive ${type}.`);
}

const suffix = `${Date.now()}-${randomBytes(3).toString('hex')}`;
const owner = await signIn(`owner-${suffix}@example.test`);
const stranger = await signIn(`stranger-${suffix}@example.test`);
assert.notEqual(owner.account.uid, stranger.account.uid);
assert.notEqual(owner.account.clipboardUid, stranger.account.clipboardUid);

const sourceClientUid = randomBytes(16).toString('hex').toUpperCase();
const receiverClientUid = randomBytes(16).toString('hex').toUpperCase();
await request('/ux/v1/devices/register', {
  token: owner.accessToken,
  method: 'POST',
  body: JSON.stringify({
    clientUid: sourceClientUid,
    platform: 'macos',
    name: 'Integration Mac',
  }),
});
await request('/ux/v1/devices/register', {
  token: owner.accessToken,
  method: 'POST',
  body: JSON.stringify({
    clientUid: receiverClientUid,
    platform: 'macos',
    name: 'Integration Receiver',
  }),
});
const source = await openSocket({ token: owner.accessToken, clientUid: sourceClientUid });
const receiver = await openSocket({ token: owner.accessToken, clientUid: receiverClientUid });
await waitForMessage(source.messages, 'connected');
await waitForMessage(receiver.messages, 'connected');

const created = await request('/ux/v1/items', {
  token: owner.accessToken,
  method: 'POST',
  expected: 201,
  body: JSON.stringify({
    clientUid: sourceClientUid,
    sourcePlatform: 'macos',
    kind: 'text',
    text: `integration item ${suffix}`,
  }),
});
assert.equal(created.item.text, `integration item ${suffix}`);
assert.equal(created.item.sourceDeviceName, 'Integration Mac');
const delivered = await waitForMessage(receiver.messages, 'clipboard-item');
assert.equal(delivered.item.uid, created.item.uid);
await sleep(250);
assert.equal(
  source.messages.some((message) => message.type === 'clipboard-item'),
  false,
);

await simulateLegacyClipboardItem(created.item.uid);
const history = await request('/ux/v1/history?page=1&pageSize=50', { token: owner.accessToken });
assert.equal(history.items[0].uid, created.item.uid);
assert.equal(history.items[0].sourceDeviceName, 'Integration Mac');
const renamedDevice = await request(`/ux/v1/devices/${sourceClientUid}`, {
  token: owner.accessToken,
  method: 'PATCH',
  body: JSON.stringify({ name: 'Renamed Integration Mac' }),
});
assert.equal(renamedDevice.device.name, 'Renamed Integration Mac');
const reregisteredDevice = await request('/ux/v1/devices/register', {
  token: owner.accessToken,
  method: 'POST',
  body: JSON.stringify({
    clientUid: sourceClientUid,
    platform: 'macos',
    name: 'Updated OS Computer Name',
  }),
});
assert.equal(reregisteredDevice.device.name, 'Renamed Integration Mac');
const renamedHistory = await request('/ux/v1/history?page=1&pageSize=50', {
  token: owner.accessToken,
});
assert.equal(renamedHistory.items[0].sourceDeviceName, 'Renamed Integration Mac');
const item = await request(`/ux/v1/items/${created.item.uid}`, { token: owner.accessToken });
assert.equal(item.item.text, created.item.text);

const imageBase64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zlq8AAAAASUVORK5CYII=';
const image = await request('/ux/v1/items', {
  token: owner.accessToken,
  method: 'POST',
  expected: 201,
  body: JSON.stringify({
    clientUid: sourceClientUid,
    sourcePlatform: 'macos',
    kind: 'image',
    imageBase64,
    mimeType: 'image/png',
  }),
});
const imageDetail = await request(`/ux/v1/items/${image.item.uid}`, {
  token: owner.accessToken,
});
assert.equal(imageDetail.item.imageBase64, imageBase64);

await request(`/ux/v1/items/${created.item.uid}`, { token: stranger.accessToken, expected: 404 });
await request(`/ux/v1/items/${image.item.uid}`, { token: stranger.accessToken, expected: 404 });
const strangerHistory = await request('/ux/v1/history', { token: stranger.accessToken });
assert.equal(strangerHistory.items.length, 0);
await request(`/ux/v1/devices/${sourceClientUid}`, {
  token: stranger.accessToken,
  method: 'PATCH',
  expected: 404,
  body: JSON.stringify({ name: 'Unauthorized rename' }),
});
const strangerDevice = await request('/ux/v1/devices/register', {
  token: stranger.accessToken,
  method: 'POST',
  body: JSON.stringify({
    clientUid: sourceClientUid,
    platform: 'android',
    name: 'Integration Android',
  }),
});
assert.equal(strangerDevice.device.name, 'Integration Android');
const ownerDevices = await request('/ux/v1/devices', { token: owner.accessToken });
const strangerDevices = await request('/ux/v1/devices', { token: stranger.accessToken });
assert.equal(
  ownerDevices.devices.find((device) => device.uid === sourceClientUid).name,
  'Renamed Integration Mac',
);
assert.equal(
  strangerDevices.devices.find((device) => device.uid === sourceClientUid).name,
  'Integration Android',
);

source.socket.close();
receiver.socket.close();
await request(`/ux/v1/items/${created.item.uid}`, {
  token: owner.accessToken,
  method: 'DELETE',
  expected: 204,
});
await request(`/ux/v1/items/${image.item.uid}`, {
  token: owner.accessToken,
  method: 'DELETE',
  expected: 204,
});
const emptyHistory = await request('/ux/v1/history', { token: owner.accessToken });
assert.equal(emptyHistory.items.length, 0);

const reconnected = await openSocket({ token: owner.accessToken, clientUid: receiverClientUid });
await waitForMessage(reconnected.messages, 'connected');
await sleep(250);
assert.equal(
  reconnected.messages.some((message) => message.type === 'clipboard-item'),
  false,
);
reconnected.socket.close();

console.log('Clip Sync stack integration checks passed.');
