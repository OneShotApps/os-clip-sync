import 'package:clip_sync_client_core/clip_sync_client_core.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// macOS presentation shell. Domain and transport behavior remain in client core.
class ClipSyncApp extends StatelessWidget {
  const ClipSyncApp({required this.controller, super.key});

  final ClipSyncController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Clip Sync',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00BFA6),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      cardTheme: const CardThemeData(color: Color(0xFF151F31)),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      useMaterial3: true,
    ),
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isBusy && !controller.isAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return controller.isAuthenticated
            ? _HistoryScreen(controller: controller)
            : _SignInScreen(controller: controller);
      },
    ),
  );
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen({required this.controller});

  final ClipSyncController controller;

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // The controller exposes a sanitized error message to this screen.
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final awaitingCode = controller.emailChallengeUid != null;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.content_paste_rounded,
                    size: 48,
                    color: Color(0xFF00BFA6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Clip Sync',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    awaitingCode
                        ? 'Enter the six-digit code sent to your email.'
                        : 'Sign in to your private clipboard.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (!awaitingCode)
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                      ),
                    )
                  else
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Six-digit code',
                        counterText: '',
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.isBusy
                        ? null
                        : () => _perform(
                            () => awaitingCode
                                ? controller.verifyEmailCode(_code.text.trim())
                                : controller.requestEmailCode(
                                    _email.text.trim(),
                                  ),
                          ),
                    child: Text(
                      awaitingCode ? 'Verify code' : 'Email me a code',
                    ),
                  ),
                  if (!awaitingCode) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.isBusy
                          ? null
                          : () => _perform(controller.signInWithGoogle),
                      icon: const Icon(Icons.login),
                      label: const Text('Continue with Google'),
                    ),
                  ],
                  if (controller.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      controller.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryScreen extends StatefulWidget {
  const _HistoryScreen({required this.controller});

  final ClipSyncController controller;

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> with WindowListener {
  late final HistoryRefreshScheduler _refreshScheduler;

  ClipSyncController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _refreshScheduler = HistoryRefreshScheduler(onRefresh: _refreshHistory)
      ..addListener(_refreshStatusChanged)
      ..start();
  }

  void _refreshStatusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshHistory() async {
    if (controller.isBusy) return;
    try {
      await controller.refreshHistory();
    } catch (_) {
      // The controller displays the sanitized API error.
    }
  }

  Future<void> _manualRefresh() async {
    if (controller.isBusy) return;
    await _refreshScheduler.refreshNow();
  }

  Future<void> _loadMore() async {
    try {
      await controller.loadMoreHistory();
    } catch (_) {
      // The controller displays the sanitized API error.
    }
  }

  Future<void> _signOut() async {
    _refreshScheduler.stop();
    try {
      await controller.signOut();
    } catch (_) {
      // The controller displays the sanitized error.
    }
  }

  @override
  void onWindowClose() => _refreshScheduler.stop();

  @override
  void onWindowMinimize() => _refreshScheduler.stop();

  @override
  void onWindowFocus() => _refreshScheduler.start();

  @override
  void onWindowRestore() => _refreshScheduler.start();

  @override
  void dispose() {
    windowManager.removeListener(this);
    _refreshScheduler
      ..removeListener(_refreshStatusChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _delete(BuildContext context, ClipItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete history item?'),
        content: const Text(
          'This removes the item from your persisted clipboard history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await controller.deleteItem(item);
      } catch (_) {
        // The controller displays the sanitized API error.
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Clip Sync'),
      actions: [
        Tooltip(
          message: controller.isPaused
              ? 'Resume synchronization'
              : 'Pause synchronization',
          child: Switch(
            value: !controller.isPaused,
            onChanged: (active) => controller.setPaused(!active),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _signOut,
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: Row(
      children: [
        SizedBox(
          width: 240,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MAC DESKTOP',
                  style: TextStyle(
                    color: Color(0xFF00BFA6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  controller.isPaused
                      ? 'Synchronization paused'
                      : 'Synchronization active',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  controller.isPaused ? 'New copies stay only on this Mac.' : 'New text and photos are sent to your private clipboard.',
                ),
                const Spacer(),
                Text(
                  controller.session!.email,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Clipboard history',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (_refreshScheduler.isPaused) ...[
                      Container(
                        key: const ValueKey('history-refresh-paused'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B2F13),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause_circle_outline, size: 18),
                            SizedBox(width: 6),
                            Text('Automatic refresh paused'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      onPressed: controller.isBusy ? null : _manualRefresh,
                      tooltip: 'Refresh history',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              if (controller.errorMessage != null)
                MaterialBanner(
                  content: Text(controller.errorMessage!),
                  actions: [
                    TextButton(
                      onPressed: controller.clearError,
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              Expanded(
                child: controller.items.isEmpty
                    ? const Center(
                        child: Text(
                          'Copy text or a photo to create your first item.',
                        ),
                      )
                    : ListView.builder(
                        itemCount:
                            controller.items.length +
                            (controller.hasMoreHistory ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == controller.items.length) {
                            return Center(
                              child: TextButton(
                                onPressed: _loadMore,
                                child: const Text('Load older items'),
                              ),
                            );
                          }
                          final item = controller.items[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                item.isImage
                                    ? Icons.image_outlined
                                    : Icons.text_snippet_outlined,
                              ),
                            ),
                            title: Text(
                              item.preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${item.sourcePlatform} • ${item.createdAt}',
                            ),
                            onTap: () async {
                              try {
                                await controller.copyItem(item);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Copied to this Mac.'),
                                    ),
                                  );
                                }
                              } catch (_) {
                                // The controller displays the sanitized API error.
                              }
                            },
                            trailing: IconButton(
                              onPressed: () => _delete(context, item),
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
