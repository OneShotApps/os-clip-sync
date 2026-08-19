import { accounts, devices } from '../data/repos/index.js';
import { AppError, ERROR_CODES } from '../errors.js';

/** Returns a human-readable platform name for legacy or unregistered devices. */
export function platformDisplayName(platform) {
  return (
    {
      android: 'Android',
      ios: 'iOS',
      macos: 'macOS',
      windows: 'Windows',
    }[platform] ?? platform
  );
}

function publicDevice(device) {
  return {
    uid: device.uid,
    name: device.customName ?? device.reportedName,
    platform: device.platform,
  };
}

/** Creates account-scoped device registration, listing, and rename operations. */
export function createDeviceService() {
  async function accountIdFor(auth) {
    const account = await accounts.findAccountByUid({ accountUid: auth.accountUid });
    if (!account) throw new Error('Authenticated account is missing.');
    return account.id;
  }

  async function listAccountDevices(auth) {
    const records = await devices.listDevices({ accountId: await accountIdFor(auth) });
    return records.map(publicDevice).sort((left, right) => left.name.localeCompare(right.name));
  }

  return {
    /** Registers the current installation and preserves any user-assigned name. */
    async register({ auth, clientUid, platform, name }) {
      const device = await devices.registerDevice({
        accountId: await accountIdFor(auth),
        deviceUid: clientUid,
        platform,
        reportedName: name.trim(),
      });
      return publicDevice(device);
    },

    /** Lists the authenticated account's devices with effective display names. */
    async list({ auth }) {
      return listAccountDevices(auth);
    },

    /** Renames one device only when it belongs to the authenticated account. */
    async rename({ auth, deviceUid, name }) {
      const device = await devices.renameDevice({
        accountId: await accountIdFor(auth),
        deviceUid,
        customName: name.trim(),
      });
      if (!device) {
        throw new AppError(404, ERROR_CODES.deviceNotFound, 'Device was not found.');
      }
      return publicDevice(device);
    },

    /** Builds a UID-to-name map used to shape current history responses. */
    async nameMap({ auth }) {
      const accountDevices = await listAccountDevices(auth);
      return new Map(accountDevices.map((device) => [device.uid, device.name]));
    },
  };
}
