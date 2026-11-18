import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  // CI-only email sign-in against a loopback Supabase backend. No bypass:
  // the local GoTrue service still validates real credentials and issues the
  // session. The controls are absent from every ordinary web build.
  static const bool _e2eLocalAuthBuild = bool.fromEnvironment('E2E_LOCAL_AUTH');
  final _localEmail = TextEditingController();
  final _localPassword = TextEditingController();

  bool get _showLocalAuth =>
      _e2eLocalAuthBuild &&
      {'127.0.0.1', 'localhost', '::1'}
          .contains(Uri.tryParse(SupabaseConfig.url)?.host);

  @override
  void dispose() {
    _localEmail.dispose();
    _localPassword.dispose();
    super.dispose();
  }

  Future<void> _handleLocalAuth() async {
    if (!_showLocalAuth) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _localEmail.text.trim(),
        password: _localPassword.text,
      );
      if (mounted) context.go('/learn');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local test sign-in failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      if (ref.read(authProvider.notifier).isAnonymousSession) {
        await ref.read(authProvider.notifier).linkGuestToGoogle();
      } else {
        await ref.read(authProvider.notifier).signInWithGoogle();
      }
    } catch (_) {
      if (mounted) {
        final stillGuest = ref.read(authProvider.notifier).isAnonymousSession;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(stillGuest
                ? 'Google linking did not complete. Your guest session is still '
                  'available. If this Google account already exists, use '
                  'the private spelling backup option.'
                : 'Google sign-in did not complete. Check your connection '
                  'and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGuestSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signInAsGuest();
      if (mounted) {
        GoRouter.of(context).go('/');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start a guest session. '
                'Check your connection and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final isAnonymousGuest = ref.read(authProvider.notifier).isAnonymousSession;
    final profileNeedsRetry =
        auth is AuthError &&
        ref.read(authProvider.notifier).hasAuthenticatedSession;
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Logo/Title
              Column(
                children: [
                  Icon(
                    Icons.school_rounded,
                    size: 80,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Learning App',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Master new concepts at your own pace',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              
              const Spacer(),
              
              if (profileNeedsRetry) ...[
                Text(
                  auth.message,
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          await ref.read(authProvider.notifier)
                              .retryProfileProvisioning();
                        },
                  child: const Text('Retry profile synchronization'),
                ),
              ],
              if (GoRouterState.of(context).uri.queryParameters.containsKey('oauth_error')) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          GoRouterState.of(context).uri.queryParameters['oauth_error'] == 'access_denied'
                              ? 'Google sign-in was cancelled. Your guest session and data remain intact.'
                              : 'Google sign-in did not complete: ${GoRouterState.of(context).uri.queryParameters['oauth_error_description'] ?? GoRouterState.of(context).uri.queryParameters['oauth_error']}. Guest data is safe.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isAnonymousGuest) ...[
                const Text(
                  'You are using a guest account. Link Google to keep your '
                  'existing lists and progress. If this Google account already '
                  'exists, linking will not work; your guest data will remain '
                  'in place until a safe import is available.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              if (isAnonymousGuest)
                TextButton.icon(
                  onPressed: _isLoading
                      ? null : () => context.push('/words/transfer'),
                  icon: const Icon(Icons.ios_share),
                  label: const Text(
                    'Google account already exists? Back up spelling lists'),
                ),

              if (_showLocalAuth) ...[
                const Text('Local CI authentication (test build only)'),
                TextField(
                  controller: _localEmail,
                  decoration: const InputDecoration(labelText: 'Local test email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: _localPassword,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Local test password'),
                ),
                FilledButton(
                  onPressed: _isLoading ? null : _handleLocalAuth,
                  child: const Text('Sign in to local test account'),
                ),
                const SizedBox(height: 16),
              ],

              // Google Sign In Button
              FilledButton.icon(
                onPressed: _isLoading ? null : _handleSignIn,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                label: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Continue with Google',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              
              const SizedBox(height: 24),
              
              // Do not create a second anonymous UID on an existing guest.
              if (!isAnonymousGuest) OutlinedButton(
                onPressed: _isLoading ? null : _handleGuestSignIn,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: theme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue as Guest'),
              ),
              
              const SizedBox(height: 24),
              
              // Terms and Privacy Notice
              Text(
                'By signing in, you agree to our Terms of Service and Privacy Policy',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
