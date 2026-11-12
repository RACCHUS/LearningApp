import 'package:learning_pwa/models/learning_support/support_identifiers.dart';
import 'package:learning_pwa/services/learning_support/bridge_check_evaluator.dart';
import 'package:learning_pwa/services/learning_support/exact_number.dart';

/// How a source may be used. Unknown terms default to link-only.
enum SourceRightsPosture {
  linkOnly('link_only'),
  mayExcerpt('may_excerpt'),
  mayAdapt('may_adapt'),
  mayIngest('may_ingest'),
  mayRedistribute('may_redistribute'),
  restricted('restricted');

  const SourceRightsPosture(this.wire);
  final String wire;

  static SourceRightsPosture? fromWire(Object? v) {
    for (final p in values) {
      if (p.wire == v) return p;
    }
    return null;
  }
}

class BridgeSource {
  const BridgeSource({
    required this.sourceId,
    required this.publisher,
    required this.title,
    required this.url,
    required this.license,
    required this.rightsPosture,
    this.section,
  });

  final String sourceId;
  final String publisher;
  final String title;
  final String? section;
  final String url;
  final String license;
  final SourceRightsPosture rightsPosture;
}

/// A short block of independently authored text.
class BridgeBlock {
  const BridgeBlock({
    required this.blockId,
    required this.text,
    required this.sourceIds,
    this.worked,
  });

  final String blockId;
  final String text;
  final List<String> sourceIds;

  /// Optional machine-checked worked example.
  final BridgeWorked? worked;
}

class BridgeWorked {
  const BridgeWorked(this.template, this.inputs, this.result, this.roundTo);

  final BridgeCheckTemplate template;
  final Map<String, Object?> inputs;
  final ExactNumber result;
  final int? roundTo;
}

class BridgeOption {
  const BridgeOption(this.optionId, this.text, this.value);

  final String optionId;
  final String text;
  final ExactNumber value;
}

enum BridgeCheckKind {
  numeric('numeric'),
  choice('choice');

  const BridgeCheckKind(this.wire);
  final String wire;
}

/// An independent check item. Its answer is recomputed from [template]
/// and [inputs]; the stored answer is only accepted if it agrees.
class BridgeCheck {
  const BridgeCheck({
    required this.itemId,
    required this.kind,
    required this.prompt,
    required this.template,
    required this.inputs,
    required this.expected,
    required this.feedback,
    this.roundTo,
    this.acceptsPercentSign = false,
    this.options = const [],
    this.correctOptionId,
  });

  final String itemId;
  final BridgeCheckKind kind;
  final String prompt;
  final BridgeCheckTemplate template;
  final Map<String, Object?> inputs;
  final int? roundTo;

  /// Verified expected value (after rounding, when [roundTo] is set).
  final ExactNumber expected;
  final bool acceptsPercentSign;
  final List<BridgeOption> options;
  final String? correctOptionId;
  final String feedback;

  /// Index of the verified correct option for `choice` items.
  int get correctOptionIndex =>
      options.indexWhere((o) => o.optionId == correctOptionId);
}

class BridgeAccessibility {
  const BridgeAccessibility({
    required this.plainLanguage,
    required this.screenReaderReady,
    required this.audioScriptAvailable,
    required this.needsImages,
  });

  final bool plainLanguage;
  final bool screenReaderReady;
  final bool audioScriptAvailable;
  final bool needsImages;
}

/// Honest record of what checking was actually done (master plan v2.6
/// §8.5): none of these implies the others.
class BridgeEvidence {
  const BridgeEvidence({
    required this.humanReviewed,
    required this.citationsCheckedAt,
    required this.deterministicChecks,
    this.reviewer,
    this.notes,
  });

  final bool humanReviewed;
  final String? reviewer;
  final DateTime citationsCheckedAt;
  final String deterministicChecks;
  final String? notes;
}

class BridgeIssue {
  const BridgeIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

class BridgeDecodeResult {
  const BridgeDecodeResult(this.bridge, this.issues);

  final BridgeLesson? bridge;
  final List<BridgeIssue> issues;

  bool get isOk => bridge != null;
}

/// A no-AI prerequisite lesson from the Bridge Library (master plan v2.6
/// §10.0). One primary objective, independently authored text with
/// citations, deterministic check items and a return cue. It never creates
/// a learning context or changes Standard/Fast.
class BridgeLesson {
  const BridgeLesson({
    required this.bridgeId,
    required this.contentVersion,
    required this.title,
    required this.conceptId,
    required this.objectiveId,
    required this.objectiveStatement,
    required this.locale,
    required this.estimatedMinutes,
    required this.buildsOn,
    required this.sources,
    required this.teach,
    required this.examples,
    required this.alternateExplanations,
    required this.checks,
    required this.returnCue,
    required this.accessibility,
    required this.evidence,
  });

  static const int currentVersion = 1;
  static const int maxTextLength = 1200;
  static const int maxPromptLength = 400;
  static const int maxTitleLength = 80;

  final String bridgeId;
  final String contentVersion;
  final String title;
  final String conceptId;
  final String objectiveId;
  final String objectiveStatement;
  final String locale;
  final int estimatedMinutes;

  /// Other bridges this one assumes, by `bridge_id`.
  final List<String> buildsOn;
  final List<BridgeSource> sources;
  final List<BridgeBlock> teach;
  final List<BridgeBlock> examples;
  final List<BridgeBlock> alternateExplanations;
  final List<BridgeCheck> checks;
  final String returnCue;
  final BridgeAccessibility accessibility;
  final BridgeEvidence evidence;

  /// Validates and decodes. Every issue is collected; nothing is repaired.
  static BridgeDecodeResult decode(Object? json) =>
      _BridgeDecoder().decode(json);

  /// A stable key for a check's computation, used to require that checks
  /// elsewhere use numbers the learner has not already seen.
  static String signatureOf(
    BridgeCheckTemplate template,
    Map<String, Object?> inputs,
  ) => _BridgeDecoder._signature(template, inputs);

  /// Signatures of every worked example and check in this Bridge.
  Set<String> get shownSignatures => {
    for (final b in [...teach, ...examples, ...alternateExplanations])
      if (b.worked != null) signatureOf(b.worked!.template, b.worked!.inputs),
    for (final c in checks) signatureOf(c.template, c.inputs),
  };

  /// Decodes a list of check items with the same strict rules Bridges use
  /// (allowlisted templates, recomputed answers, one correct option).
  static ({List<BridgeCheck> checks, List<BridgeIssue> issues}) decodeChecks(
    Object? raw,
    String path, {
    int min = 1,
  }) {
    final d = _BridgeDecoder();
    final checks = <BridgeCheck>[];
    final ids = <String>{};
    final items = d.list({'checks': raw}, 'checks', path, min: min) ?? [];
    for (final (i, c) in items.indexed) {
      final check = d.check(c, '$path.checks[$i]');
      if (check == null) continue;
      if (!ids.add(check.itemId)) {
        d.issue('$path.checks[$i].item_id', 'duplicate item id');
      }
      checks.add(check);
    }
    return (checks: checks, issues: List.of(d.issues));
  }
}

class _BridgeDecoder {
  final issues = <BridgeIssue>[];

  void issue(String path, String message) =>
      issues.add(BridgeIssue(path, message));

  String? text(Map m, String key, String path, int max, {bool req = true}) {
    final v = m[key];
    if (v == null) {
      if (req) issue('$path.$key', 'required');
      return null;
    }
    if (v is! String || v.trim().isEmpty) {
      issue('$path.$key', 'must be non-empty text');
      return null;
    }
    if (v.length > max) issue('$path.$key', 'longer than $max characters');
    if (v.contains('<') || v.contains('](')) {
      issue('$path.$key', 'markup and links are not allowed in text');
    }
    return v;
  }

  String? id(Map m, String key, String path) {
    final v = m[key];
    if (!SupportIdentifiers.isId(v)) {
      issue('$path.$key', 'must be a safe identifier');
      return null;
    }
    return v as String;
  }

  bool? flag(Map m, String key, String path) {
    final v = m[key];
    if (v is! bool) {
      issue('$path.$key', 'must be true or false');
      return null;
    }
    return v;
  }

  List<Map>? list(Map m, String key, String path, {int min = 0}) {
    final v = m[key];
    if (v is! List) {
      issue('$path.$key', 'must be a list');
      return null;
    }
    if (v.length < min) issue('$path.$key', 'needs at least $min');
    final out = <Map>[];
    for (var i = 0; i < v.length; i++) {
      if (v[i] is Map) {
        out.add(v[i] as Map);
      } else {
        issue('$path.$key[$i]', 'must be an object');
      }
    }
    return out;
  }

  BridgeDecodeResult decode(Object? json) {
    if (json is! Map) {
      return const BridgeDecodeResult(null, [
        BridgeIssue(r'$', 'not an object'),
      ]);
    }
    const p = r'$';
    final version = json['bridge_version'];
    if (version != BridgeLesson.currentVersion) {
      issue('$p.bridge_version', 'must be ${BridgeLesson.currentVersion}');
    }
    if (json['uses_ai'] != false) {
      issue('$p.uses_ai', 'a Bridge must work without AI (false)');
    }
    final bridgeId = id(json, 'bridge_id', p);
    final contentVersion = json['content_version'];
    if (contentVersion is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(contentVersion)) {
      issue('$p.content_version', 'must look like 1.0.0');
    }
    final title = text(json, 'title', p, BridgeLesson.maxTitleLength);
    final conceptId = id(json, 'concept_id', p);
    final locale = json['locale'];
    if (locale is! String ||
        !RegExp(r'^[a-z]{2}(-[A-Z]{2})?$').hasMatch(locale)) {
      issue('$p.locale', 'must be a locale such as en-US');
    }
    final minutes = json['estimated_minutes'];
    if (minutes is! int || minutes < 1 || minutes > 15) {
      issue('$p.estimated_minutes', 'must be 1..15 (a Bridge is short)');
    }

    String? objectiveId;
    String? objectiveStatement;
    final objective = json['primary_objective'];
    if (objective is Map) {
      objectiveId = id(objective, 'objective_id', '$p.primary_objective');
      objectiveStatement = text(
        objective,
        'statement',
        '$p.primary_objective',
        BridgeLesson.maxPromptLength,
      );
    } else {
      issue('$p.primary_objective', 'required object');
    }

    final buildsOn = <String>[];
    final rawBuilds = json['builds_on'];
    if (rawBuilds is List) {
      for (var i = 0; i < rawBuilds.length; i++) {
        if (SupportIdentifiers.isId(rawBuilds[i])) {
          buildsOn.add(rawBuilds[i] as String);
        } else {
          issue('$p.builds_on[$i]', 'must be a bridge id');
        }
      }
    } else {
      issue('$p.builds_on', 'must be a list (may be empty)');
    }

    final sources = <BridgeSource>[];
    for (final (i, s) in (list(json, 'sources', p, min: 1) ?? []).indexed) {
      final sp = '$p.sources[$i]';
      final sid = id(s, 'source_id', sp);
      final url = s['url'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        issue('$sp.url', 'must be an https URL');
      }
      final posture = SourceRightsPosture.fromWire(s['rights_posture']);
      if (posture == null) issue('$sp.rights_posture', 'unknown posture');
      if (posture == SourceRightsPosture.restricted) {
        issue('$sp.rights_posture', 'restricted sources cannot back a Bridge');
      }
      final publisher = text(s, 'publisher', sp, 120);
      final stitle = text(s, 'title', sp, 200);
      final section = text(s, 'section', sp, 200, req: false);
      final license = text(s, 'license', sp, 200);
      if (sid != null &&
          uri != null &&
          posture != null &&
          publisher != null &&
          stitle != null &&
          license != null) {
        sources.add(
          BridgeSource(
            sourceId: sid,
            publisher: publisher,
            title: stitle,
            section: section,
            url: url as String,
            license: license,
            rightsPosture: posture,
          ),
        );
      }
    }
    final sourceIds = {for (final s in sources) s.sourceId};
    if (sourceIds.length != sources.length) {
      issue('$p.sources', 'source ids must be unique');
    }

    final blockIds = <String>{};
    List<BridgeBlock> blocks(String key, {int min = 1}) {
      final out = <BridgeBlock>[];
      for (final (i, b) in (list(json, key, p, min: min) ?? []).indexed) {
        final bp = '$p.$key[$i]';
        final bid = id(b, 'block_id', bp);
        if (bid != null && !blockIds.add(bid)) {
          issue('$bp.block_id', 'duplicate block id');
        }
        final t = text(b, 'text', bp, BridgeLesson.maxTextLength);
        final refs = <String>[];
        final rawRefs = b['source_ids'];
        if (rawRefs is! List || rawRefs.isEmpty) {
          issue('$bp.source_ids', 'cite at least one source');
        } else {
          for (final r in rawRefs) {
            if (r is String && sourceIds.contains(r)) {
              refs.add(r);
            } else {
              issue('$bp.source_ids', 'unknown source "$r"');
            }
          }
        }
        final worked = b['worked'] == null
            ? null
            : this.worked(b['worked'], '$bp.worked');
        if (bid != null && t != null) {
          out.add(
            BridgeBlock(blockId: bid, text: t, sourceIds: refs, worked: worked),
          );
        }
      }
      return out;
    }

    final teach = blocks('teach');
    final examples = blocks('examples');
    final alternates = blocks('alternate_explanations', min: 0);

    final checks = <BridgeCheck>[];
    final itemIds = <String>{};
    for (final (i, c) in (list(json, 'checks', p, min: 2) ?? []).indexed) {
      final check = this.check(c, '$p.checks[$i]');
      if (check == null) continue;
      if (!itemIds.add(check.itemId)) {
        issue('$p.checks[$i].item_id', 'duplicate item id');
      }
      checks.add(check);
    }
    // Independence: a check must not repeat a worked example's numbers.
    final shown = {
      for (final b in [...examples, ...teach, ...alternates])
        if (b.worked != null) _signature(b.worked!.template, b.worked!.inputs),
    };
    for (final (i, c) in checks.indexed) {
      if (shown.contains(_signature(c.template, c.inputs))) {
        issue('$p.checks[$i]', 'repeats a worked example; use unseen numbers');
      }
    }
    final signatures = <String>{};
    for (final (i, c) in checks.indexed) {
      if (!signatures.add(_signature(c.template, c.inputs))) {
        issue('$p.checks[$i]', 'duplicates another check');
      }
    }

    final returnCue = text(json, 'return_cue', p, BridgeLesson.maxPromptLength);

    BridgeAccessibility? accessibility;
    final a = json['accessibility'];
    if (a is Map) {
      final plain = flag(a, 'plain_language', '$p.accessibility');
      final sr = flag(a, 'screen_reader_ready', '$p.accessibility');
      final audio = flag(a, 'audio_script_available', '$p.accessibility');
      final images = flag(a, 'needs_images', '$p.accessibility');
      if (images == true) {
        issue('$p.accessibility.needs_images', 'starter Bridges are text-only');
      }
      if (plain != null && sr != null && audio != null && images != null) {
        accessibility = BridgeAccessibility(
          plainLanguage: plain,
          screenReaderReady: sr,
          audioScriptAvailable: audio,
          needsImages: images,
        );
      }
    } else {
      issue('$p.accessibility', 'required object');
    }

    BridgeEvidence? evidence;
    final e = json['evidence'];
    if (e is Map) {
      final reviewed = flag(e, 'human_reviewed', '$p.evidence');
      final reviewer = e['reviewer'];
      if (reviewed == true &&
          (reviewer is! String || reviewer.trim().isEmpty)) {
        issue('$p.evidence.reviewer', 'a human review must name who reviewed');
      }
      if (reviewed == false && reviewer != null) {
        issue('$p.evidence.reviewer', 'no reviewer without a human review');
      }
      final checkedAt = e['citations_checked_at'] is String
          ? DateTime.tryParse(e['citations_checked_at'] as String)
          : null;
      if (checkedAt == null) {
        issue('$p.evidence.citations_checked_at', 'must be an ISO date');
      }
      final det = text(e, 'deterministic_checks', '$p.evidence', 200);
      final notes = text(e, 'notes', '$p.evidence', 600, req: false);
      if (reviewed != null && checkedAt != null && det != null) {
        evidence = BridgeEvidence(
          humanReviewed: reviewed,
          reviewer: reviewer as String?,
          citationsCheckedAt: checkedAt,
          deterministicChecks: det,
          notes: notes,
        );
      }
    } else {
      issue('$p.evidence', 'required object');
    }

    if (issues.isNotEmpty) return BridgeDecodeResult(null, List.of(issues));
    return BridgeDecodeResult(
      BridgeLesson(
        bridgeId: bridgeId!,
        contentVersion: contentVersion as String,
        title: title!,
        conceptId: conceptId!,
        objectiveId: objectiveId!,
        objectiveStatement: objectiveStatement!,
        locale: locale as String,
        estimatedMinutes: minutes as int,
        buildsOn: List.unmodifiable(buildsOn),
        sources: List.unmodifiable(sources),
        teach: List.unmodifiable(teach),
        examples: List.unmodifiable(examples),
        alternateExplanations: List.unmodifiable(alternates),
        checks: List.unmodifiable(checks),
        returnCue: returnCue!,
        accessibility: accessibility!,
        evidence: evidence!,
      ),
      const [],
    );
  }

  static String _signature(BridgeCheckTemplate t, Map<String, Object?> inputs) {
    final keys = inputs.keys.toList()..sort();
    return [
      t.wire,
      for (final k in keys) '$k=${ExactNumber.tryParseJson(inputs[k])}',
    ].join('|');
  }

  int? roundTo(Map m, String path) {
    final r = m['round_to'];
    if (r == null) return null;
    if (r is! int || r < 0 || r > 6) {
      issue('$path.round_to', 'must be 0..6');
      return null;
    }
    return r;
  }

  ({
    BridgeCheckTemplate template,
    Map<String, Object?> inputs,
    ExactNumber exact,
  })?
  computed(Map m, String path) {
    final template = BridgeCheckTemplate.fromWire(m['template']);
    if (template == null) {
      issue('$path.template', 'not an allowlisted template');
      return null;
    }
    final inputs = m['inputs'];
    if (inputs is! Map) {
      issue('$path.inputs', 'must be an object');
      return null;
    }
    final typed = inputs.map((k, v) => MapEntry('$k', v as Object?));
    final result = BridgeCheckEvaluator.compute(template, typed);
    if (!result.isOk) {
      issue('$path.inputs', result.error!);
      return null;
    }
    return (
      template: template,
      inputs: Map.unmodifiable(typed),
      exact: result.value!,
    );
  }

  BridgeWorked? worked(Object? raw, String path) {
    if (raw is! Map) {
      issue(path, 'must be an object');
      return null;
    }
    final c = computed(raw, path);
    final round = roundTo(raw, path);
    final stated = ExactNumber.tryParseJson(raw['result']);
    if (stated == null) {
      issue('$path.result', 'must be an int or decimal string');
      return null;
    }
    if (c == null) return null;
    final expected = BridgeCheckEvaluator.expected(c.exact, round);
    if (stated != expected) {
      issue('$path.result', 'states $stated but the template gives $expected');
      return null;
    }
    return BridgeWorked(c.template, c.inputs, expected, round);
  }

  BridgeCheck? check(Map c, String path) {
    final itemId = id(c, 'item_id', path);
    final prompt = text(c, 'prompt', path, BridgeLesson.maxPromptLength);
    final feedback = text(c, 'feedback', path, BridgeLesson.maxPromptLength);
    final kind = switch (c['kind']) {
      'numeric' => BridgeCheckKind.numeric,
      'choice' => BridgeCheckKind.choice,
      _ => null,
    };
    if (kind == null) issue('$path.kind', 'must be numeric or choice');
    final comp = computed(c, path);
    final round = roundTo(c, path);
    if (comp == null || kind == null || itemId == null) return null;
    final expected = BridgeCheckEvaluator.expected(comp.exact, round);
    if (round == null && expected.toString().contains('/')) {
      issue('$path.round_to', 'answer does not terminate; set round_to');
    }

    if (kind == BridgeCheckKind.numeric) {
      final stated = ExactNumber.tryParseJson(c['answer']);
      if (stated == null) {
        issue('$path.answer', 'must be an int or decimal string');
      } else if (stated != expected) {
        issue(
          '$path.answer',
          'states $stated but the template gives $expected',
        );
      }
      if (c.containsKey('options') || c.containsKey('correct_option_id')) {
        issue(path, 'numeric items have no options');
      }
      final pct = c['accepts_percent_sign'] ?? false;
      if (pct is! bool) issue('$path.accepts_percent_sign', 'must be a bool');
      if (prompt == null || feedback == null || stated != expected) return null;
      return BridgeCheck(
        itemId: itemId,
        kind: kind,
        prompt: prompt,
        template: comp.template,
        inputs: comp.inputs,
        roundTo: round,
        expected: expected,
        acceptsPercentSign: pct == true,
        feedback: feedback,
      );
    }

    final options = <BridgeOption>[];
    final optionIds = <String>{};
    final optionTexts = <String>{};
    final rawOptions = list(c, 'options', path, min: 3) ?? const [];
    if (rawOptions.length > 6) issue('$path.options', 'at most 6 options');
    for (final (i, o) in rawOptions.indexed) {
      final op = '$path.options[$i]';
      final oid = id(o, 'option_id', op);
      final ot = text(o, 'text', op, 120);
      final ov = ExactNumber.tryParseJson(o['value']);
      if (ov == null) issue('$op.value', 'must be an int or decimal string');
      if (oid != null && !optionIds.add(oid)) {
        issue('$op.option_id', 'duplicate option id');
      }
      if (ot != null && !optionTexts.add(ot.trim().toLowerCase())) {
        issue('$op.text', 'duplicate option text');
      }
      if (oid != null && ot != null && ov != null) {
        options.add(BridgeOption(oid, ot, ov));
      }
    }
    final matching = options.where((o) => o.value == expected).toList();
    final correctId = c['correct_option_id'];
    if (matching.length != 1) {
      issue(
        '$path.options',
        'exactly one option must equal $expected (found ${matching.length})',
      );
    } else if (correctId != matching.single.optionId) {
      issue(
        '$path.correct_option_id',
        'must be "${matching.single.optionId}", the option equal to $expected',
      );
    }
    if (prompt == null || feedback == null || issues.isNotEmpty) return null;
    return BridgeCheck(
      itemId: itemId,
      kind: kind,
      prompt: prompt,
      template: comp.template,
      inputs: comp.inputs,
      roundTo: round,
      expected: expected,
      options: List.unmodifiable(options),
      correctOptionId: correctId as String,
      feedback: feedback,
    );
  }
}

/// Checks a set of Bridges together: unique IDs and concepts, `builds_on`
/// references that exist, and no circular dependencies.
class BridgeLibraryValidator {
  const BridgeLibraryValidator._();

  static List<BridgeIssue> validate(List<BridgeLesson> bridges) {
    final issues = <BridgeIssue>[];
    final byId = <String, BridgeLesson>{};
    final concepts = <String>{};
    for (final b in bridges) {
      if (byId.containsKey(b.bridgeId)) {
        issues.add(BridgeIssue(b.bridgeId, 'duplicate bridge id'));
      }
      byId[b.bridgeId] = b;
      if (!concepts.add(b.conceptId)) {
        issues.add(BridgeIssue(b.bridgeId, 'concept ${b.conceptId} reused'));
      }
    }
    for (final b in bridges) {
      for (final dep in b.buildsOn) {
        if (!byId.containsKey(dep)) {
          issues.add(BridgeIssue(b.bridgeId, 'builds_on unknown "$dep"'));
        }
      }
    }
    // Depth-first cycle check.
    final state = <String, int>{}; // 1 visiting, 2 done
    bool visit(String id) {
      if (state[id] == 2) return false;
      if (state[id] == 1) return true;
      state[id] = 1;
      for (final dep in byId[id]?.buildsOn ?? const <String>[]) {
        if (byId.containsKey(dep) && visit(dep)) return true;
      }
      state[id] = 2;
      return false;
    }

    for (final id in byId.keys) {
      if (visit(id)) {
        issues.add(BridgeIssue(id, 'builds_on forms a cycle'));
        break;
      }
    }
    return issues;
  }
}
