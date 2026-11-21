import 'dart:convert';

import 'package:learning_pwa/services/content_generation/la_gen_parser.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/model_capability_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Opt-in prompt-quality telemetry (master plan v2.6 §5.7.6, signal 1).
///
/// Shares, for each AI reply checked in the generator, the same codes and
/// counts the device-local capability profile already keeps: prompt pack
/// version, the AI label the learner picked, size tier, output mode,
/// outcome, first error code, slots requested and accepted, end marker.
/// Never prompt or reply text, subjects, concepts or answers. The server
/// (migration 20261121010000) enforces the switch, base analytics consent,
/// eligibility and this feature's own opt-in; this client sends nothing
/// unless the status says the learner opted in.
class PromptQualityStatus {
  const PromptQualityStatus({
    this.enabled = false,
    this.available = false,
    this.consented = false,
    this.storedEvents = 0,
  });

  /// The `analytics.prompt_quality` switch is on.
  final bool enabled;

  /// This account may opt in (eligible and base analytics consent given).
  final bool available;

  /// The learner opted in to sharing prompt-quality codes. Reported even
  /// while the switch is off, so withdrawal is always possible.
  final bool consented;

  /// Rows stored for this account on the server.
  final int storedEvents;

  /// Show the opt-in: when it can be turned on, or to let it be turned off.
  bool get showControl => (enabled && available) || consented || storedEvents > 0;

  static const off = PromptQualityStatus();

  factory PromptQualityStatus.fromJson(Map<String, dynamic> json) =>
      PromptQualityStatus(
        enabled: json['enabled'] == true,
        available: json['available'] == true,
        consented: json['consented'] == true,
        storedEvents: json['stored_events'] is int ? json['stored_events'] as int : 0,
      );
}

/// One checked reply, as codes and counts.
class PromptQualityEvent {
  PromptQualityEvent({
    String? eventId,
    required this.aiLabel,
    required this.tier,
    required this.mode,
    required this.outcome,
    required this.errorCode,
    required this.requested,
    required this.accepted,
    required this.sentinel,
  }) : eventId = eventId ?? const Uuid().v4();

  /// Built from the same observation the local capability profile records.
  factory PromptQualityEvent.fromReply({
    required AiChatLabel aiLabel,
    required ModelSizeTier tier,
    required ReplyObservation observation,
    required PasteOutcome outcome,
  }) {
    final firstError = outcome.result.fatal ?? (outcome.result.errors.isEmpty
        ? null
        : outcome.result.errors.first);
    return PromptQualityEvent(
      aiLabel: aiLabel,
      tier: tier,
      mode: _snake(observation.mode.name),
      outcome: observation.unreadable
          ? 'refused'
          : observation.clean
              ? 'clean'
              : 'partial',
      errorCode: firstError?.errorCode.code ?? 'none',
      requested: observation.requested.clamp(0, 50),
      accepted: observation.filled.clamp(0, 50),
      sentinel: observation.endMarker,
    );
  }

  /// Prompt pack version, from the output schema id (`la-gen/1.1`).
  static final String packVersion =
      LaGenParser.schemaId.replaceAll('/', '-');

  final String eventId;
  final AiChatLabel aiLabel;
  final ModelSizeTier tier;
  final String mode;
  final String outcome;
  final String errorCode;
  final int requested;
  final int accepted;
  final bool sentinel;

  Map<String, Object> toJson() => {
    'event_id': eventId,
    'pack_version': packVersion,
    'ai_label': aiLabel.wire,
    'tier': tier.name,
    'mode': mode,
    'outcome': outcome,
    'error_code': errorCode,
    'requested': requested,
    'accepted': accepted,
    'sentinel': sentinel,
  };

  static String _snake(String camel) => camel.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );
}

abstract class PromptQualityApi {
  Future<PromptQualityStatus> status();
  Future<void> setConsent(bool consent);
  Future<void> record(List<PromptQualityEvent> events);

  /// The learner's own stored rows, as JSON text.
  Future<String> export();
}

class SupabasePromptQualityApi implements PromptQualityApi {
  SupabasePromptQualityApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<PromptQualityStatus> status() async {
    final res = await _client.rpc('get_prompt_quality_status');
    return PromptQualityStatus.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<void> setConsent(bool consent) =>
      _client.rpc('set_prompt_quality_consent', params: {'p_consent': consent});

  @override
  Future<void> record(List<PromptQualityEvent> events) => _client.rpc(
    'record_prompt_quality_events',
    params: {'p_events': [for (final e in events) e.toJson()]},
  );

  @override
  Future<String> export() async {
    final res = await _client.rpc('export_my_prompt_quality_events');
    return const JsonEncoder.withIndent('  ').convert(res);
  }
}
