import 'dart:convert';

import 'package:learning_pwa/models/answer_key.dart';
import 'package:learning_pwa/models/content_generation/generation_error.dart';
import 'package:learning_pwa/models/content_generation/slot_plan.dart';
import 'package:learning_pwa/services/content_generation/json_structure_scanner.dart';

/// Provisional parsing limits (master plan v2.6 §5.6). These are test
/// hypotheses to be tuned by measurement, not certified tolerances.
class LaGenLimits {
  const LaGenLimits({
    this.maxBytes = 256 * 1024,
    this.maxRecords = 256,
    this.maxLineBytes = 32 * 1024,
    this.maxDepth = 24,
    this.maxFieldChars = 4000,
    this.maxOptions = 8,
  });

  final int maxBytes;
  final int maxRecords;
  final int maxLineBytes;
  final int maxDepth;
  final int maxFieldChars;
  final int maxOptions;
}

enum LaGenMode {
  /// A single `{"schema": "la-gen/1.1", ...}` document.
  package,

  /// "Mode S": one independent JSON object per line.
  records,
}

/// A validated slot. Content is kept exactly as written; only the answer
/// letter is resolved to a zero-based index.
class LaGenSlot {
  const LaGenSlot({
    required this.spec,
    required this.fields,
    this.correctIndex,
  });

  final SlotSpec spec;

  /// The record's fields, unchanged (minus routing keys).
  final Map<String, dynamic> fields;

  /// Zero-based correct option for `mcq` slots.
  final int? correctIndex;

  String get code => spec.code;
}

class LaGenParseResult {
  LaGenParseResult({
    required this.plan,
    this.mode,
    Map<String, LaGenSlot>? accepted,
    List<GenerationError>? errors,
    this.fatal,
    this.sentinelPresent = false,
    this.claimedComplete,
    this.extractedFromCommentary = false,
  }) : accepted = accepted ?? {},
       errors = errors ?? [];

  final SlotPlan plan;
  final LaGenMode? mode;

  /// Accepted slots by code.
  final Map<String, LaGenSlot> accepted;

  /// Per-slot / per-line problems. Accepted slots are unaffected by these.
  final List<GenerationError> errors;

  /// A whole-payload refusal (nothing accepted).
  final GenerationError? fatal;

  /// The `end` sentinel was present and matched. A hint only.
  final bool sentinelPresent;

  /// The payload's own `complete` claim. A hint only, never trusted.
  final bool? claimedComplete;

  /// A single payload was taken from surrounding commentary.
  final bool extractedFromCommentary;

  /// Plan slots that still need a valid response, in plan order. Computed
  /// by the app; the payload's claims do not change it.
  List<String> get missingSlots => [
    for (final s in plan.slots)
      if (!accepted.containsKey(s.code)) s.code,
  ];

  bool get isComplete => fatal == null && missingSlots.isEmpty;
}

/// Bounded, standard-JSON parser for `la-gen/1.1` responses (master plan
/// v2.6 §5.6, Appendix D.3).
///
/// Allowed envelope adjustments: one leading BOM, one fully enclosing
/// Markdown code fence, or one unambiguous payload inside commentary.
/// Nothing inside the payload is rewritten: no quote, comma or truncation
/// repair, no inferred answers, citations or fields.
class LaGenParser {
  const LaGenParser._();

  static const schemaId = 'la-gen/1.1';

  static const _routingKeys = {'slot', 'kind', 'concept', 'support', 'job'};
  static const _fieldsByKind = {
    SlotKind.explanation: {
      'required': {'title', 'text'},
      'optional': {'example'},
    },
    SlotKind.term: {
      'required': {'term', 'definition'},
      'optional': {'example'},
    },
    SlotKind.mcq: {
      'required': {'stem', 'options', 'answer'},
      'optional': {'why'},
    },
  };
  static final _letter = RegExp(r'^[A-Z]$');

  static LaGenParseResult parse(
    String input,
    SlotPlan plan, {
    LaGenLimits limits = const LaGenLimits(),
  }) {
    LaGenParseResult refuse(GenerationErrorCode code, [String? detail]) =>
        LaGenParseResult(
          plan: plan,
          fatal: GenerationError(code, detail: detail),
        );

    // 1. Cheap length prefilter, then exact UTF-8 byte count. A UTF-16
    //    code unit is never less than one UTF-8 byte.
    if (input.length > limits.maxBytes) {
      return refuse(GenerationErrorCode.payloadTooLarge);
    }
    if (utf8.encode(input).length > limits.maxBytes) {
      return refuse(GenerationErrorCode.payloadTooLarge);
    }

    // 2. Envelope: one leading BOM and at most one code fence.
    var text = input.startsWith('﻿') ? input.substring(1) : input;
    final fences = RegExp(r'^\s*```', multiLine: true).allMatches(text).length;
    if (fences > 2) {
      return refuse(
        GenerationErrorCode.payloadAmbiguous,
        'more than one code block',
      );
    }
    var extracted = false;
    if (fences == 2) {
      final m = RegExp(
        r'^\s*```[^\n]*\n([\s\S]*?)^\s*```\s*$',
        multiLine: true,
      ).firstMatch(text);
      if (m == null) {
        return refuse(GenerationErrorCode.invalidJson, 'unclosed code block');
      }
      extracted =
          text.substring(0, m.start).trim().isNotEmpty ||
          text.substring(m.end).trim().isNotEmpty;
      text = m.group(1)!;
    } else if (fences == 1) {
      return refuse(GenerationErrorCode.invalidJson, 'unclosed code block');
    }

    // 3. Mode detection: Mode S when the first object line is itself a
    //    complete record without a `schema` key.
    final lines = const LineSplitter().convert(text);
    final firstObjectLine = lines
        .map((l) => l.trim())
        .firstWhere((l) => l.startsWith('{'), orElse: () => '');
    if (firstObjectLine.isEmpty) {
      return refuse(GenerationErrorCode.invalidJson, 'no JSON object found');
    }
    final firstScan = JsonStructureScanner.scan(
      firstObjectLine,
      maxDepth: limits.maxDepth,
    );
    if (firstScan.ok && firstScan.spans.length == 1) {
      try {
        final first = jsonDecode(firstObjectLine);
        if (first is Map && !first.containsKey('schema')) {
          return _parseRecords(lines, plan, limits);
        }
      } on FormatException {
        // Fall through to package mode, which reports the error.
      }
    }
    return _parsePackage(text, plan, limits, extracted);
  }

  static LaGenParseResult _parsePackage(
    String text,
    SlotPlan plan,
    LaGenLimits limits,
    bool extractedByFence,
  ) {
    LaGenParseResult refuse(GenerationErrorCode code, [String? detail]) =>
        LaGenParseResult(
          plan: plan,
          mode: LaGenMode.package,
          fatal: GenerationError(code, detail: detail),
        );

    final scan = JsonStructureScanner.scan(text, maxDepth: limits.maxDepth);
    if (!scan.ok) {
      return switch (scan.problem!) {
        JsonScanProblem.tooDeep => refuse(GenerationErrorCode.structureTooDeep),
        JsonScanProblem.mismatchedBracket => refuse(
          GenerationErrorCode.invalidJson,
          'mismatched bracket at ${scan.position}',
        ),
        JsonScanProblem.unterminated => refuse(
          GenerationErrorCode.invalidJson,
          'response ends before the JSON is complete',
        ),
      };
    }
    if (scan.spans.length != 1) {
      return refuse(
        GenerationErrorCode.payloadAmbiguous,
        '${scan.spans.length} JSON objects found',
      );
    }
    final span = scan.spans.single;
    final extracted =
        extractedByFence ||
        text.substring(0, span.start).trim().isNotEmpty ||
        text.substring(span.end).trim().isNotEmpty;

    final Object? decoded;
    try {
      decoded = jsonDecode(text.substring(span.start, span.end));
    } on FormatException catch (e) {
      return refuse(GenerationErrorCode.invalidJson, e.message);
    }
    if (decoded is! Map<String, dynamic>) {
      return refuse(GenerationErrorCode.invalidJson, 'expected an object');
    }
    if (decoded['schema'] != schemaId) {
      return refuse(
        GenerationErrorCode.schemaUnsupported,
        'schema "${decoded['schema']}"',
      );
    }
    if (decoded['job'] != plan.jobCode) {
      return refuse(
        GenerationErrorCode.unknownJobOrSlot,
        'payload is for job "${decoded['job']}"',
      );
    }
    final items = decoded['items'];
    if (items is! List) {
      return refuse(GenerationErrorCode.invalidJson, '"items" must be a list');
    }
    if (items.length > limits.maxRecords) {
      return refuse(
        GenerationErrorCode.payloadTooLarge,
        '${items.length} items exceeds ${limits.maxRecords}',
      );
    }

    final records = <(Map<String, dynamic>, int?)>[];
    final errors = <GenerationError>[];
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        records.add((item, null));
      } else {
        errors.add(
          const GenerationError(
            GenerationErrorCode.invalidJson,
            detail: 'item is not an object',
          ),
        );
      }
    }
    final result = _acceptRecords(records, plan, limits, errors);
    return LaGenParseResult(
      plan: plan,
      mode: LaGenMode.package,
      accepted: result,
      errors: errors,
      sentinelPresent: decoded['end'] == plan.endSentinel,
      claimedComplete: decoded['complete'] is bool
          ? decoded['complete'] as bool
          : null,
      extractedFromCommentary: extracted,
    );
  }

  static LaGenParseResult _parseRecords(
    List<String> lines,
    SlotPlan plan,
    LaGenLimits limits,
  ) {
    final errors = <GenerationError>[];
    final records = <(Map<String, dynamic>, int?)>[];
    var sentinel = false;
    var recordCount = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lineNo = i + 1;
      if (line.isEmpty || !line.startsWith('{')) continue;
      recordCount++;
      if (recordCount > limits.maxRecords) {
        return LaGenParseResult(
          plan: plan,
          mode: LaGenMode.records,
          fatal: GenerationError(
            GenerationErrorCode.payloadTooLarge,
            detail: 'more than ${limits.maxRecords} records',
          ),
        );
      }
      if (utf8.encode(line).length > limits.maxLineBytes) {
        errors.add(
          GenerationError(
            GenerationErrorCode.payloadTooLarge,
            line: lineNo,
            detail: 'line too long',
          ),
        );
        continue;
      }
      final scan = JsonStructureScanner.scan(line, maxDepth: limits.maxDepth);
      if (!scan.ok || scan.spans.length != 1) {
        errors.add(
          GenerationError(
            scan.problem == JsonScanProblem.tooDeep
                ? GenerationErrorCode.structureTooDeep
                : GenerationErrorCode.invalidJsonlRecord,
            line: lineNo,
            detail: scan.problem == JsonScanProblem.unterminated
                ? 'incomplete line (discarded, not completed)'
                : null,
          ),
        );
        continue;
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(line);
      } on FormatException catch (e) {
        errors.add(
          GenerationError(
            GenerationErrorCode.invalidJsonlRecord,
            line: lineNo,
            detail: e.message,
          ),
        );
        continue;
      }
      if (decoded is! Map<String, dynamic>) {
        errors.add(
          GenerationError(GenerationErrorCode.invalidJsonlRecord, line: lineNo),
        );
        continue;
      }
      if (decoded.length == 1 && decoded.containsKey('end')) {
        if (decoded['end'] == plan.endSentinel) {
          sentinel = true;
        } else {
          errors.add(
            GenerationError(
              GenerationErrorCode.unknownJobOrSlot,
              line: lineNo,
              detail: 'end sentinel for another job',
            ),
          );
        }
        continue;
      }
      records.add((decoded, lineNo));
    }

    final accepted = _acceptRecords(records, plan, limits, errors);
    return LaGenParseResult(
      plan: plan,
      mode: LaGenMode.records,
      accepted: accepted,
      errors: errors,
      sentinelPresent: sentinel,
    );
  }

  /// Validates records against the slot plan. Duplicate slot codes are all
  /// held for repair (no last-writer-wins).
  static Map<String, LaGenSlot> _acceptRecords(
    List<(Map<String, dynamic>, int?)> records,
    SlotPlan plan,
    LaGenLimits limits,
    List<GenerationError> errors,
  ) {
    final counts = <String, int>{};
    for (final (r, _) in records) {
      final slot = r['slot'];
      if (slot is String) counts[slot] = (counts[slot] ?? 0) + 1;
    }
    final accepted = <String, LaGenSlot>{};
    for (final (record, line) in records) {
      final slotCode = record['slot'];
      if (slotCode is String && (counts[slotCode] ?? 0) > 1) {
        errors.add(
          GenerationError(
            GenerationErrorCode.payloadAmbiguous,
            slot: slotCode,
            line: line,
            detail: 'slot appears more than once',
          ),
        );
        continue;
      }
      final outcome = _validateRecord(record, plan, limits);
      if (outcome is LaGenSlot) {
        accepted[outcome.code] = outcome;
      } else {
        final e = outcome as GenerationError;
        errors.add(
          GenerationError(
            e.errorCode,
            slot: e.slot ?? (slotCode is String ? slotCode : null),
            line: line,
            detail: e.detail,
          ),
        );
      }
    }
    return accepted;
  }

  /// Returns a [LaGenSlot] or a [GenerationError].
  static Object _validateRecord(
    Map<String, dynamic> record,
    SlotPlan plan,
    LaGenLimits limits,
  ) {
    GenerationError err(GenerationErrorCode code, String detail) =>
        GenerationError(code, detail: detail);

    final slotCode = record['slot'];
    if (slotCode is! String) {
      return err(GenerationErrorCode.unknownJobOrSlot, 'missing "slot"');
    }
    final spec = plan[slotCode];
    if (spec == null) {
      return err(
        GenerationErrorCode.unknownJobOrSlot,
        'slot "$slotCode" is not in this job',
      );
    }
    if (record.containsKey('job') && record['job'] != plan.jobCode) {
      return err(
        GenerationErrorCode.unknownJobOrSlot,
        'record is for another job',
      );
    }
    final kind = SlotKind.fromWire(record['kind']);
    if (kind == null) {
      return err(
        GenerationErrorCode.schemaUnsupported,
        'unknown kind "${record['kind']}"',
      );
    }
    if (kind != spec.kind) {
      return err(
        GenerationErrorCode.unknownJobOrSlot,
        'slot $slotCode expects ${spec.kind.wire}, got ${kind.wire}',
      );
    }
    if (record['concept'] != spec.conceptCode) {
      return err(
        GenerationErrorCode.unknownJobOrSlot,
        'slot $slotCode is for concept ${spec.conceptCode}',
      );
    }
    final support = record['support'];
    if (support != null) {
      if (support is! List || support.any((s) => s is! String)) {
        return err(
          GenerationErrorCode.reviewRequired,
          '"support" must be a list of fact codes',
        );
      }
      final unknown = support.cast<String>().where(
        (s) => !spec.allowedSupport.contains(s),
      );
      if (unknown.isNotEmpty) {
        return err(
          GenerationErrorCode.reviewRequired,
          'unknown support code(s): ${unknown.join(', ')}',
        );
      }
    }

    final spec2 = _fieldsByKind[kind]!;
    final required = spec2['required']!;
    final optional = spec2['optional']!;
    for (final key in record.keys) {
      if (!_routingKeys.contains(key) &&
          !required.contains(key) &&
          !optional.contains(key)) {
        return err(
          GenerationErrorCode.schemaUnsupported,
          'unexpected field "$key"',
        );
      }
    }
    for (final key in required) {
      if (!record.containsKey(key) || record[key] == null) {
        return err(GenerationErrorCode.reviewRequired, 'missing "$key"');
      }
    }
    for (final key in [...required, ...optional]) {
      final value = record[key];
      if (value == null || key == 'options') continue;
      if (value is! String || value.trim().isEmpty) {
        return err(
          GenerationErrorCode.reviewRequired,
          '"$key" must be non-empty text',
        );
      }
      if (value.length > limits.maxFieldChars) {
        return err(GenerationErrorCode.payloadTooLarge, '"$key" is too long');
      }
    }

    int? correctIndex;
    if (kind == SlotKind.mcq) {
      final options = record['options'];
      if (options is! List ||
          options.length < 2 ||
          options.length > limits.maxOptions ||
          options.any((o) => o is! String || o.trim().isEmpty)) {
        return err(
          GenerationErrorCode.reviewRequired,
          '"options" must be 2-${limits.maxOptions} non-empty texts',
        );
      }
      final opts = options.cast<String>();
      if (opts.any((o) => o.length > limits.maxFieldChars)) {
        return err(GenerationErrorCode.payloadTooLarge, 'option too long');
      }
      if (opts.map(AnswerKey.normalize).toSet().length != opts.length) {
        return err(
          GenerationErrorCode.optionsAmbiguous,
          'two options have the same text',
        );
      }
      final answer = record['answer'] as String;
      // Canonical letter only; "b", "B)" or option text are not adapted.
      if (!_letter.hasMatch(answer)) {
        return err(
          GenerationErrorCode.answerUnresolvable,
          'answer must be one capital letter',
        );
      }
      final index = answer.codeUnitAt(0) - 0x41;
      if (index >= opts.length) {
        return err(
          GenerationErrorCode.correctIndexOutOfRange,
          'answer $answer but only ${opts.length} options',
        );
      }
      final key = AnswerKey.fromIndex(index, opts);
      if (!key.isScorable) {
        return err(
          GenerationErrorCode.answerUnresolvable,
          key.detail ?? 'invalid answer',
        );
      }
      correctIndex = key.index;
    }

    return LaGenSlot(
      spec: spec,
      fields: {
        for (final e in record.entries)
          if (!_routingKeys.contains(e.key)) e.key: e.value,
      },
      correctIndex: correctIndex,
    );
  }
}
