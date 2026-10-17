import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

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
