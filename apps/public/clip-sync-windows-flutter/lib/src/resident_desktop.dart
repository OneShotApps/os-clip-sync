import 'dart:io';

import 'package:clip_sync_client_core/clip_sync_client_core.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Keeps Clip Sync resident in the Windows system tray when its window is closed.
class ResidentDesktop with TrayListener, WindowListener {
  ResidentDesktop(this.controller);

  final ClipSyncController controller;
  bool _quitting = false;

  Future<void> initialize() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    controller.addListener(_refreshMenu);
    await windowManager.setPreventClose(true);
    await trayManager.setIcon('windows/runner/resources/app_icon.ico');
    await trayManager.setToolTip('Clip Sync');
    await _refreshMenu();
  }

  Future<void> _refreshMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Open Clip Sync'),
          MenuItem.checkbox(
            key: 'paused',
            label: 'Pause synchronization',
            checked: controller.isPaused,
          ),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit Clip Sync'),
        ],
      ),
    );
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
      case 'paused':
        controller.setPaused(!controller.isPaused);
      case 'quit':
        _quitting = true;
        controller.dispose();
        exit(0);
    }
  }

  @override
  void onWindowClose() {
    if (_quitting) return;
    windowManager.hide();
  }
}
