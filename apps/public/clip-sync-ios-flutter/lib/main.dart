import 'dart:async';

import 'package:clip_sync_client_core/clip_sync_client_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  const apiUrl = String.fromEnvironment(
    'CLIP_SYNC_API_URL',
    defaultValue: 'http://127.0.0.1:4200',
  );
  final sessionStore = SessionStore();
  final controller = ClipSyncController(
    apiClient: ClipSyncApiClient(baseUrl: apiUrl),
    sessionStore: sessionStore,
    googleAuthService: GoogleAuthService(sessionStore: sessionStore),
    clipboard: ClipboardAdapter(),
    shareReceiver: ShareReceiver(),
    platform: 'ios',
    isDesktop: false,
  );

  runApp(ClipSyncMobileApp(controller: controller, platformName: 'iOS'));
  unawaited(controller.initialize());
}

class ClipSyncMobileApp extends StatelessWidget {
  const ClipSyncMobileApp({
    required this.controller,
    required this.platformName,
    super.key,
  });

  final ClipSyncController controller;
  final String platformName;

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
            ? _MobileHistoryScreen(
                controller: controller,
                platformName: platformName,
              )
            : _MobileSignInScreen(controller: controller);
      },
    ),
  );
}

class _MobileSignInScreen extends StatefulWidget {
  const _MobileSignInScreen({required this.controller});

  final ClipSyncController controller;

  @override
  State<_MobileSignInScreen> createState() => _MobileSignInScreenState();
}

class _MobileSignInScreenState extends State<_MobileSignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            const Icon(
              Icons.content_paste_rounded,
              size: 64,
              color: Color(0xFF00BFA6),
            ),
            const SizedBox(height: 20),
            Text(
              'Clip Sync',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              awaitingCode
                  ? 'Enter the code sent to your email.'
                  : 'Your private clipboard history, wherever you are.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            if (!awaitingCode)
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email address'),
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
                          : controller.requestEmailCode(_email.text.trim()),
                    ),
              child: Text(awaitingCode ? 'Verify code' : 'Email me a code'),
            ),
            if (!awaitingCode) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
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
              const SizedBox(height: 20),
              Text(
                controller.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MobileHistoryScreen extends StatelessWidget {
  const _MobileHistoryScreen({
    required this.controller,
    required this.platformName,
  });

  final ClipSyncController controller;
  final String platformName;

  Future<void> _refresh() async {
    try {
      await controller.refreshHistory();
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    try {
      await controller.loadMoreHistory();
    } catch (_) {}
  }

  Future<void> _signOut() async {
    try {
      await controller.signOut();
    } catch (_) {}
  }

  Future<void> _copy(BuildContext context, ClipItem item) async {
    try {
      await controller.copyItem(item);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Copied to this device.')));
      }
    } catch (_) {}
  }

  Future<void> _delete(BuildContext context, ClipItem item) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete history item?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'This removes the item from your persisted clipboard history.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await controller.deleteItem(item);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Clipboard history'),
      actions: [
        IconButton(
          onPressed: controller.isBusy ? null : _refresh,
          tooltip: 'Refresh history',
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: _signOut,
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF151F31),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '$platformName uses manual copy only. Incoming items never replace your mobile clipboard.',
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
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: controller.items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('No clipboard history yet.')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount:
                          controller.items.length +
                          (controller.hasMoreHistory ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == controller.items.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: OutlinedButton(
                              onPressed: _loadMore,
                              child: const Text('Load older items'),
                            ),
                          );
                        }
                        final item = controller.items[index];
                        return ListTile(
                          minTileHeight: 78,
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
                          onTap: () => _copy(context, item),
                          onLongPress: () => _delete(context, item),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) => action == 'copy'
                                ? _copy(context, item)
                                : _delete(context, item),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'copy', child: Text('Copy')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
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
