import 'package:clip_sync_client_core/clip_sync_client_core.dart';
import 'package:flutter/material.dart';

/// Loads and displays account devices in a phone-sized management sheet.
Future<void> showDeviceManagerSheet(
  BuildContext context,
  ClipSyncController controller,
) async {
  try {
    await controller.refreshDevices();
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _DeviceManagerSheet(controller: controller),
  );
}

class _DeviceManagerSheet extends StatelessWidget {
  const _DeviceManagerSheet({required this.controller});

  final ClipSyncController controller;

  Future<void> _rename(BuildContext context, SyncDevice device) async {
    var editedName = device.name;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename device'),
        content: TextFormField(
          initialValue: device.name,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Device name'),
          onChanged: (value) => editedName = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, editedName.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == device.name) return;
    try {
      await controller.renameDevice(device, name);
    } catch (_) {
      // The controller exposes the sanitized API error on the history screen.
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Devices',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => ListView.separated(
                itemCount: controller.devices.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final device = controller.devices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text(
                      controller.isCurrentDevice(device)
                          ? '${device.platformName} • This device'
                          : device.platformName,
                    ),
                    trailing: IconButton(
                      onPressed: controller.isBusy
                          ? null
                          : () => _rename(context, device),
                      tooltip: 'Rename ${device.name}',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
