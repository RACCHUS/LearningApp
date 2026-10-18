import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../providers/auth_provider.dart';
import '../../services/word_learning_transfer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User-controlled backup for moving private word lists from an anonymous
/// session to a Google account that already exists. Prefer direct Google
/// linking for new identities. This transfer never requires privileged SQL.
/// Auth transitions key this entire subtree by the active account.
/// Exported backup text and pending imports are disposed on sign-out/switch.
class WordTransferScreen extends ConsumerWidget {
  const WordTransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userId = authState is AuthSuccess ? authState.user.id : null;
    return _WordTransferSession(
      key: ValueKey('word-transfer:${userId ?? 'signed-out'}'),
    );
  }
}

class _WordTransferSession extends ConsumerStatefulWidget {
  const _WordTransferSession({super.key});

  @override
  ConsumerState<_WordTransferSession> createState() => _WordTransferScreenState();
}

class _WordTransferScreenState extends ConsumerState<_WordTransferSession> {
  final _transfer = WordLearningTransfer();
  final _export = TextEditingController();
  final _import = TextEditingController();
  bool _busy = false;
  bool _savedBackup = false;
  bool _copiedBackup = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _export.dispose();
    _import.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        final message = e is FormatException
            ? 'The backup format is invalid or incomplete. No data was imported.'
            : 'The transfer did not finish. Some new records may already have '
                'been saved. It is safe to retry; existing records are not '
                'overwritten.';
        setState(() => _error = message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportBackup() async => _run(() async {
        final text = await _transfer.exportJson();
        if (!mounted) return;
        _export.text = text;
        setState(() {
          _savedBackup = false;
          _copiedBackup = false;
        });
      });

  Future<void> _copyBackup() async {
    if (_export.text.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: _export.text));
      if (mounted) setState(() {
        // Clipboard success does not prove there is a recoverable copy.
        // Switching accounts requires a separate affirmative acknowledgement.
        _copiedBackup = true;
        _savedBackup = false;
        _message = 'Copied. Save the backup somewhere private, then confirm below.';
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() =>
          _error = 'Clipboard unavailable. Manually select and copy the backup text.');
    }
  }

  Future<void> _importBackup() async => _run(() async {
        final answer = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import this word backup?'),
            content: const Text(
              'Only word lists and spelling-review history will be imported. '
              'Existing account data wins if there is a conflict. '
              'The source backup remains unchanged.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text('Import')),
            ],
          ),
        );
        if (answer != true) return;
        final result = await _transfer.importJson(_import.text);
        if (mounted) {
          setState(() => _message =
              'Imported ${result.listsCreated} lists, '
              '${result.wordsCreated} words and '
              '${result.reviewsCreated} review records. '
              '${result.destinationConflictsPreserved} existing items '
              'were kept unchanged.');
          _import.clear();
        }
      });

  Future<void> _switchExistingAccount() async {
    if (!_savedBackup || !_copiedBackup || _export.text.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch to your existing Google account?'),
        content: const Text(
          'This ends access to the current anonymous session. '
          'Your guest data remains on the server, but may be inaccessible '
          'after sign-out. Make sure the copied word backup is saved privately '
          'before continuing. After Google sign-in, return to Word Learning '
          'and import the backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay as Guest')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch accounts')),
        ],
      ),
    );
    if (confirm != true) return;
    await _run(() async {
      final auth = ref.read(authProvider.notifier);
      await auth.signOut();
      await auth.signInWithGoogle();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      final prevUser = previous is AuthSuccess ? previous.user.id : null;
      final nextUser = next is AuthSuccess ? next.user.id : null;
      if (prevUser != nextUser) {
        setState(() {
          _export.clear();
          _import.clear();
          _savedBackup = false;
          _copiedBackup = false;
          _message = null;
          _error = null;
        });
      }
    });

    final user = Supabase.instance.client.auth.currentUser;
    final isGuest = user?.isAnonymous ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer spelling lists')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Back up and transfer your personal spelling lists',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'This backup can include personal names and spelling history. '
            'Keep it private. You control when it is copied or imported. '
            'Do not share it publicly or leave it on a shared clipboard.'),
          const SizedBox(height: 14),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: TextStyle(
              color: Theme.of(context).colorScheme.error)),
          if (_message != null) Text(_message!),
          if (user == null)
            FilledButton(onPressed: () => context.go('/login'),
              child: const Text('Sign in or Continue as Guest'))
          else ...[
            FilledButton.icon(
              onPressed: _busy ? null : _exportBackup,
              icon: const Icon(Icons.ios_share),
              label: const Text('Prepare a private backup'),
            ),
            if (_export.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _export,
                readOnly: true,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Your private backup text',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _copyBackup,
                icon: const Icon(Icons.copy),
                label: const Text('Copy backup'),
              ),
              if (isGuest) ...[
                CheckboxListTile(
                  value: _savedBackup,
                  onChanged: !_copiedBackup
                      ? null : (value) => setState(
                          () => _savedBackup = value ?? false),
                  title: const Text('I saved a private copy outside this app'),
                  subtitle: const Text(
                    'Signing out of an anonymous account may permanently '
                    'remove access to its learning data. Copying alone is '
                    'not sufficient; save the backup somewhere safe first.'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                FilledButton(
                  onPressed: _busy || !_savedBackup || !_copiedBackup
                      ? null : _switchExistingAccount,
                  child: const Text('Switch to existing Google account'),
                ),
              ],
            ],
            const Divider(height: 36),
            const Text('Import a backup into the current account',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _import,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Paste your saved backup',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _importBackup,
              icon: const Icon(Icons.file_download),
              label: const Text('Review and import backup'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: ''));
                if (mounted) setState(() => _message =
                    'Clipboard cleared. Keep your private saved copy.');
              },
              child: const Text('Clear clipboard'),
            ),
          ],
        ]),
      ))),
    );
  }
}
