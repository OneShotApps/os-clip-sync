/** Creates the authenticated account device-list handler. */
export function listDevices(deviceService) {
  return async (context) => {
    const devices = await deviceService.list({ auth: context.get('auth') });
    return context.json({ devices });
  };
}
