import 'package:clip_sync_client_core/clip_sync_client_core.dart';
import 'package:flutter/material.dart';

/// Loads and displays every device owned by the signed-in account.
Future<void> showDeviceManagerDialog(
  BuildContext context,
  ClipSyncController controller,
) async {
  try {
    await controller.refreshDevices();
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _DeviceManagerDialog(controller: controller),
  );
}

class _DeviceManagerDialog extends StatelessWidget {
  const _DeviceManagerDialog({required this.controller});

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
      // The controller exposes the sanitized API error in the main window.
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Devices'),
    content: SizedBox(
      width: 440,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView.separated(
          shrinkWrap: true,
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
