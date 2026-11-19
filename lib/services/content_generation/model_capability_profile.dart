import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/manual_prompt_builder.dart';

/// The AI chats a learner can name (master plan v2.6 §5.3). These are
/// labels the learner picks; the app never contacts any of them.
enum AiChatLabel {
  chatgpt('chatgpt', 'ChatGPT'),
  gemini('gemini', 'Gemini'),
  claude('claude', 'Claude'),
  copilot('copilot', 'Copilot'),
  other('other', 'Other'),
  notSure('not_sure', 'Not sure');

  const AiChatLabel(this.wire, this.label);

  final String wire;
  final String label;

  static AiChatLabel? fromWire(Object? v) {
    for (final l in values) {
      if (l.wire == v) return l;
    }
    return null;
  }
}

/// Counts for one output mode. Only counts are kept, never reply text.
class ModeTally {
  const ModeTally({this.replies = 0, this.clean = 0});

  /// Replies checked in this mode.
  final int replies;

  /// Replies that filled every requested slot, had no item problems and
  /// ended with the end marker.
  final int clean;

  ModeTally add({required bool clean}) =>
      ModeTally(replies: replies + 1, clean: this.clean + (clean ? 1 : 0));

  Map<String, Object> toJson() => {'replies': replies, 'clean': clean};

  static ModeTally fromJson(Object? json) {
    if (json is! Map) return const ModeTally();
    final r = json['replies'];
    final c = json['clean'];
    if (r is! int || c is! int || r < 0 || c < 0 || c > r) {
      return const ModeTally();
    }
    return ModeTally(replies: r, clean: c);
  }
}

/// What one checked reply showed. Built from the parse outcome only.
class ReplyObservation {
  const ReplyObservation({
    required this.mode,
    required this.requested,
    required this.filled,
    required this.itemProblems,
    required this.unreadable,
    required this.endMarker,
  });

  /// Builds an observation for a reply to a prompt that asked for
  /// [requested] slots. [nowAccepted] is the job's accepted slots after
  /// the paste was applied.
  factory ReplyObservation.from({
    required ManualOutputMode mode,
    required List<String> requested,
    required PasteOutcome outcome,
    required Set<String> nowAccepted,
  }) => ReplyObservation(
    mode: mode,
    requested: requested.length,
    filled: requested.where(nowAccepted.contains).length,
    itemProblems: outcome.result.errors.length,
    unreadable: outcome.result.fatal != null,
    endMarker: outcome.result.sentinelPresent,
  );

  final ManualOutputMode mode;
  final int requested;
  final int filled;
  final int itemProblems;

  /// Nothing in the reply could be read in the requested format.
  final bool unreadable;
  final bool endMarker;

  bool get clean =>
      !unreadable &&
      itemProblems == 0 &&
      endMarker &&
      requested > 0 &&
      filled == requested;
}

/// A learner-owned, device-local record of how replies from one AI chat
/// have gone (master plan v2.6 §5.3). It *suggests* a batch size and an
/// output mode; it never proves a provider limit, never leaves the device
/// and starts at [ModelSizeTier.compact] when nothing is known.
class ModelCapabilityProfile {
  const ModelCapabilityProfile({
    required this.label,
    this.package = const ModeTally(),
    this.lines = const ModeTally(),
    this.missingEnd = 0,
    this.unreadable = 0,
    this.largestCleanBatch = 0,
    this.probePassed,
  });

  final AiChatLabel label;
  final ModeTally package;
  final ModeTally lines;

  /// Replies without the end marker (likely cut off).
  final int missingEnd;

  /// Replies that could not be read in the requested format at all.
  final int unreadable;

  /// The most slots one clean reply has filled.
  final int largestCleanBatch;

  /// The optional format probe (Appendix A.1): `null` when not run. Only
  /// a starting hint; real replies take over once there are enough.
  final bool? probePassed;

  ModelCapabilityProfile withProbe(bool passed) => ModelCapabilityProfile(
    label: label,
    package: package,
    lines: lines,
    missingEnd: missingEnd,
    unreadable: unreadable,
    largestCleanBatch: largestCleanBatch,
    probePassed: passed,
  );

  /// Below this many replies, rates are not shown or used (small
  /// denominators are noise).
  static const minReplies = 3;

  /// The batch-size steps never jump past what has actually worked: a
  /// tier is suggested only after a clean reply at least as large as the
  /// tier below it.
  static const _standardMinReplies = 3;
  static const _largeMinReplies = 6;

  int get replies => package.replies + lines.replies;
  int get clean => package.clean + lines.clean;

  /// Share of replies that were clean in one pass, or `null` when there
  /// are too few replies to say.
  double? get jsonReliability => replies < minReplies ? null : clean / replies;

  /// Share of replies missing the end marker, or `null` when too few.
  double? get truncationRate =>
      replies < minReplies ? null : missingEnd / replies;

  ModelCapabilityProfile record(ReplyObservation o) {
    final isClean = o.clean;
    return ModelCapabilityProfile(
      label: label,
      package: o.mode == ManualOutputMode.package
          ? package.add(clean: isClean)
          : package,
      lines: o.mode == ManualOutputMode.lines
          ? lines.add(clean: isClean)
          : lines,
      missingEnd: missingEnd + (o.endMarker ? 0 : 1),
      unreadable: unreadable + (o.unreadable ? 1 : 0),
      largestCleanBatch: isClean && o.filled > largestCleanBatch
          ? o.filled
          : largestCleanBatch,
      probePassed: probePassed,
    );
  }

  /// The batch size to suggest. Conservative: unknown is compact, and a
  /// high cut-off rate always falls back to compact.
  ModelSizeTier get suggestedTier {
    final reliability = jsonReliability;
    final truncation = truncationRate;
    if (reliability == null || truncation == null) {
      // Too few real replies: a passed probe may start one step up.
      return probePassed == true
          ? ModelSizeTier.standard
          : ModelSizeTier.compact;
    }
    if (truncation > 0.25) return ModelSizeTier.compact;
    if (replies >= _largeMinReplies &&
        reliability >= 0.9 &&
        truncation <= 0.1 &&
        largestCleanBatch >= ModelSizeTier.standard.slotsPerMessage) {
      return ModelSizeTier.large;
    }
    if (replies >= _standardMinReplies &&
        reliability >= 0.75 &&
        largestCleanBatch >= ModelSizeTier.compact.slotsPerMessage) {
      return ModelSizeTier.standard;
    }
    return ModelSizeTier.compact;
  }

  /// The output mode that has worked better, or `null` when there is not
  /// enough evidence in both modes to compare.
  ManualOutputMode? get suggestedMode {
    if (package.replies < minReplies || lines.replies < minReplies) {
      // A failed probe hints that one item per line is safer, until real
      // replies in both modes can be compared.
      return probePassed == false && replies < minReplies
          ? ManualOutputMode.lines
          : null;
    }
    final p = package.clean / package.replies;
    final l = lines.clean / lines.replies;
    if ((p - l).abs() < 0.2) return null;
    return p > l ? ManualOutputMode.package : ManualOutputMode.lines;
  }

  /// Plain-language reason for the suggestion.
  String get explanation {
    final reliability = jsonReliability;
    if (reliability == null) {
      return switch (probePassed) {
        true =>
          'The quick test worked, so the app starts at medium. '
              'It still learns from replies you check here.',
        false =>
          'The quick test did not work cleanly, so the app starts small. '
              'It learns from replies you check here.',
        null =>
          'Not enough replies yet, so the app starts small. '
              'It learns from replies you check here.',
      };
    }
    final pct = (reliability * 100).round();
    return 'Based on $replies replies checked on this device: '
        '$pct% worked in one go. This is a guess, not a limit of your AI.';
  }

  static const int version = 1;

  Map<String, Object> toJson() => {
    'version': version,
    'label': label.wire,
    'package': package.toJson(),
    'lines': lines.toJson(),
    'missing_end': missingEnd,
    'unreadable': unreadable,
    'largest_clean_batch': largestCleanBatch,
    if (probePassed != null) 'probe_passed': probePassed!,
  };

  /// Reads a saved profile. Anything unexpected gives `null`, so a damaged
  /// save starts over at compact instead of suggesting a larger tier.
  static ModelCapabilityProfile? fromJson(Object? json) {
    if (json is! Map || json['version'] != version) return null;
    final label = AiChatLabel.fromWire(json['label']);
    final package = ModeTally.fromJson(json['package']);
    final lines = ModeTally.fromJson(json['lines']);
    final missingEnd = json['missing_end'];
    final unreadable = json['unreadable'];
    final largest = json['largest_clean_batch'];
    final probe = json['probe_passed'];
    if (probe != null && probe is! bool) return null;
    if (label == null ||
        missingEnd is! int ||
        unreadable is! int ||
        largest is! int) {
      return null;
    }
    final replies = package.replies + lines.replies;
    if (missingEnd < 0 ||
        missingEnd > replies ||
        unreadable < 0 ||
        unreadable > replies ||
        largest < 0 ||
        largest > ModelSizeTier.large.slotsPerMessage) {
      return null;
    }
    return ModelCapabilityProfile(
      label: label,
      package: package,
      lines: lines,
      missingEnd: missingEnd,
      unreadable: unreadable,
      largestCleanBatch: largest,
      probePassed: probe as bool?,
    );
  }
}
