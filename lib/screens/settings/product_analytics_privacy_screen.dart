import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learning_pwa/services/analytics/product_analytics_privacy_service.dart';
import 'package:learning_pwa/services/analytics/product_event_outbox.dart';
import 'package:learning_pwa/services/analytics/product_event_rpc_sink.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Optional telemetry controls. No event emitter is mounted here. Client
/// collection remains off until trusted server policy and release gates pass.
class ProductAnalyticsPrivacyScreen extends StatefulWidget {
  final ProductAnalyticsPrivacyService? service;
  final Future<int> Function()? clearLocalEvents;
  final String? Function()? currentUserId;

  const ProductAnalyticsPrivacyScreen({
    super.key,
    this.service,
    this.clearLocalEvents,
    this.currentUserId,
  });

  @override
  State<ProductAnalyticsPrivacyScreen> createState() =>
      _ProductAnalyticsPrivacyScreenState();
}

class _ProductAnalyticsPrivacyScreenState
    extends State<ProductAnalyticsPrivacyScreen> {
  late final ProductAnalyticsPrivacyService _privacy;
  late final String? Function() _getUserId;
  StreamSubscription<AuthState>? _authChanges;
  String? _mountedUser;
  ProductAnalyticsPrivacyStatus? _status;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _privacy = widget.service ?? ProductAnalyticsPrivacyService();
    _getUserId = widget.currentUserId ??
        (() => Supabase.instance.client.auth.currentUser?.id);
    _mountedUser = _getUserId();
    if (widget.currentUserId == null) {
      _authChanges = Supabase.instance.client.auth.onAuthStateChange
          .listen((_) => _checkIdentity());
    }
    if (_mountedUser == null) {
      _loading = false;
    } else {
      unawaited(_refresh());
    }
  }

  void _checkIdentity() {
    if (!mounted || _mountedUser == _getUserId()) return;
    setState(() {
      _mountedUser = _getUserId();
      _status = null;
      _loading = false;
      _busy = false;
      _message = null;
      _error = 'Account changed. Reopen privacy settings to continue.';
    });
  }

  bool get _sameUser => _getUserId() != null &&
      _getUserId() == _mountedUser;

  Future<void> _refresh() async {
    if (!mounted || !_sameUser) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = await _privacy.status();
      if (!mounted || !_sameUser) return;
      setState(() {
        _status = next;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || !_sameUser) return;
      setState(() {
        _status = null;
        _loading = false;
        _error = 'Product analytics privacy controls are unavailable. '
            'Collection remains disabled. Try again later.';
      });
    }
  }

  Future<int> _eraseLocal() async {
    if (!_sameUser) {
      throw StateError('Account changed before local privacy erasure.');
    }
    if (widget.clearLocalEvents case final action?) return action();
    return ProductEventOutbox(
      sender: AckedProductEventSink.supabase(
          Supabase.instance.client),
      getPrivacy: _privacy.status,
    ).clearCurrentAccount();
  }

  Future<void> _perform(Future<void> Function() task) async {
    if (_busy || !_sameUser) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await task();
    } catch (_) {
      if (mounted && _sameUser) {
        setState(() {
          _error = 'Action could not be confirmed. No additional product '
              'tracking was enabled. Retry when connectivity is restored.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
      }
    } finally {
      if (mounted && _sameUser) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() => _perform(() async {
    // Delete this device's pending data BEFORE the remote withdrawal, so
    // nothing can be replayed after consent is revoked.
    final cleared = await _eraseLocal();
    final next = await _privacy.chooseConsent(false);
    if (!mounted || !_sameUser) return;
    setState(() {
      _status = next;
      _message = 'Consent withdrawn. Server-stored product events were '
          'erased and $cleared queued item(s) cleared on this device.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_message!)),
    );
  });

  Future<void> _enroll() async {
    final current = _status;
    if (_busy || current == null || !current.canOptIn) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Optional product analytics'),
        content: const Text(
          'If you opt in, LearningApp may record limited feature usage '
          'categories, resource opens and referral clicks. It does not '
          'record search text, assessment answers, payment data or '
          'the content of your notes. Data can be withdrawn and deleted. '
          'This is separate from saving your learning progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context,false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context,true),
            child: const Text('Explicitly opt in'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_sameUser) return;
    await _perform(() async {
      final next = await _privacy.chooseConsent(true);
      if (!mounted || !_sameUser) return;
      setState(() {
        _status = next;
        _message = 'Consent saved. Optional telemetry still depends on '
            'the separately approved release controls.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message!)),
      );
    });
  }

  Future<void> _export() => _perform(() async {
    final json = await _privacy.exportJson();
    if (!mounted || !_sameUser) return;
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted || !_sameUser) return;
    setState(() {
      _message = 'Your product event export was copied to the clipboard. '
          'Save it privately, then clear the clipboard on a shared device.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_message!)),
    );
  });

  Future<void> _clearDevice() => _perform(() async {
    final count = await _eraseLocal();
    if (!mounted || !_sameUser) return;
    setState(() {
      _message = 'Cleared $count queued product event(s) on this device. '
          'Server records were not changed by this local action.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_message!)),
    );
  });

  @override
  void dispose() {
    _authChanges?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Analytics Privacy'),
        actions: [
          IconButton(
            tooltip: 'Refresh privacy status',
            onPressed: _busy || !_sameUser ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _mountedUser == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Sign in to manage optional product analytics.'),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Product analytics is optional and off by default. '
                      'It is separate from learning progress, scored '
                      'assessments and study-time records.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'If enabled after a privacy review, it covers '
                      'categorical app surfaces, feature usage, resource '
                      'opens and external-link clicks. Raw search text, '
                      'notes, answers and payment information are excluded.',
                    ),
                    const SizedBox(height: 12),
                    if (_error case final error?)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(error),
                        ),
                      ),
                    if (_message case final message?)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(message),
                        ),
                      ),
                    if (status != null) ...[
                      ListTile(
                        title: const Text('Current collection'),
                        subtitle: Text(status.canCollect
                            ? 'Approved and consented'
                            : 'Off — not collecting product events'),
                      ),
                      ListTile(
                        title: const Text('Consent status'),
                        subtitle: Text(status.consented
                            ? 'Opted in (server confirmed)'
                            : 'Not opted in'),
                      ),
                      ListTile(
                        title: const Text('Account eligibility'),
                        subtitle: Text(status.eligible && !status.isAnonymous
                            ? 'Reviewed eligible account'
                            : 'Not eligible or eligibility not reviewed'),
                      ),
                      if (!status.canOptIn)
                        const ListTile(
                          title: Text('Enrollment not yet available'),
                          subtitle: Text(
                            'The privacy policy and activation controls '
                            'require a separate approval. Consent cannot '
                            'be inferred from account creation.',
                          ),
                        ),
                      FilledButton(
                        onPressed: !_busy && status.canOptIn &&
                                !status.consented
                            ? _enroll : null,
                        child: const Text('Opt in to optional analytics'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy ? null : _withdraw,
                        child: const Text(
                          'Withdraw consent and erase server events'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : _export,
                        child: const Text('Export my product events'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : _clearDevice,
                      child: const Text('Erase queued events on this device'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Server events have a proposed 90-day maximum '
                      'retention period, pending operational approval. '
                      'Withdrawal deletes server-stored product events; '
                      'it does not delete your learning progress. '
                      'Exported data may contain personal activity history.',
                    ),
                  ],
                ),
    );
  }
}
