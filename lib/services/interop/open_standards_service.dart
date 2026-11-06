import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/learning_event.dart';

/// Result of emitting an xAPI statement or statement batch to an external LRS.
class XApiEmissionResult {
  final bool success;
  final int statusCode;
  final String? message;
  final List<String> statementIds;

  const XApiEmissionResult({
    required this.success,
    required this.statusCode,
    this.message,
    this.statementIds = const [],
  });
}

/// Service providing standard interoperability for QTI 3.0 and xAPI / cmi5 (OPP-5).
class OpenStandardsService {
  final http.Client _httpClient;

  OpenStandardsService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Exports an [AssessmentItemCore] directly into standard QTI 3.0 XML.
  String exportCoreItemToQti(
    AssessmentItemCore item, {
    String title = 'Assessment Item',
  }) {
    return QtiItemConverter.exportItem(item, title: title);
  }

  /// Converts an application [AssessmentItem] into a QTI 3.0 compliant XML item.
  String exportAssessmentItemToQti(AssessmentItem item) {
    final rawOptions = item.responseSpec['options'] as List? ?? [];
    final options = <AssessmentOptionCore>[];
    final correctId = item.scoringSpec['correct_option_id'] ??
        item.scoringSpec['correct_answer'];

    for (final opt in rawOptions) {
      if (opt is Map) {
        final text =
            opt['text']?.toString() ?? opt['label']?.toString() ?? '';
        final optId = opt['id']?.toString() ?? text;
        final isCorrect = opt['is_correct'] == true ||
            optId == correctId ||
            text == correctId;
        options.add(AssessmentOptionCore(
          text: text,
          isCorrect: isCorrect,
          rationale: opt['rationale']?.toString(),
          misconception: opt['misconception']?.toString(),
        ));
      } else if (opt is String) {
        options.add(AssessmentOptionCore(
          text: opt,
          isCorrect: opt == correctId,
        ));
      }
    }

    final coreItem = AssessmentItemCore(
      id: item.id,
      stem: item.prompt,
      options: options,
      explanation: item.explanation,
      conceptSlug:
          item.concepts.isNotEmpty ? item.concepts.first.conceptId : null,
      sourceRef: item.metadata['source_ref']?.toString(),
    );

    return QtiItemConverter.exportItem(coreItem, title: 'Item ${item.id}');
  }

  /// Parses a QTI 3.0 XML string into an [AssessmentItemCore].
  AssessmentItemCore importAssessmentItemFromQti(String qtiXml) {
    return QtiItemConverter.importItem(qtiXml);
  }

  /// Converts a [LearningEventCore] into an ADL xAPI 1.0.3 compliant statement.
  Map<String, dynamic> generateXApiStatementFromCore(
    LearningEventCore event, {
    String baseUri = 'https://learningapp.org',
  }) {
    return XApiStatementEmitter.emitStatement(event, baseUri: baseUri);
  }

  /// Converts an application [LearningEvent] into an ADL xAPI 1.0.3 compliant statement.
  Map<String, dynamic> generateXApiStatement(
    LearningEvent event, {
    String baseUri = 'https://learningapp.org',
  }) {
    final payload = <String, dynamic>{
      'item_id': event.itemId,
      'item_type': event.itemType,
      if (event.contextId != null) 'context_id': event.contextId,
      if (event.sessionId != null) 'session_id': event.sessionId,
      if (event.score != null) 'score': event.score,
      if (event.score != null) 'is_correct': (event.score! >= 0.7),
      if (event.latencyMs != null) 'response_time_ms': event.latencyMs,
      if (event.confidence != null) 'confidence': event.confidence,
      ...event.metadata,
    };

    final coreEvent = LearningEventCore(
      id: event.id,
      idempotencyKey:
          event.metadata['idempotency_key']?.toString() ?? event.id,
      sessionId: event.sessionId ?? 'session_default',
      clientSeq: event.metadata['client_seq'] as int? ?? 1,
      userId: event.userId,
      eventType: event.eventType,
      clientOccurredAt: event.occurredAt,
      payload: payload,
    );

    return XApiStatementEmitter.emitStatement(coreEvent, baseUri: baseUri);
  }

  /// Emits an xAPI statement to a remote Learning Record Store (LRS) endpoint.
  Future<XApiEmissionResult> emitStatementToLrs({
    required Map<String, dynamic> statement,
    required Uri lrsEndpoint,
    String? basicAuthUser,
    String? basicAuthPassword,
    String? bearerToken,
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'X-Experience-API-Version': '1.0.3',
      };

      if (bearerToken != null && bearerToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $bearerToken';
      } else if (basicAuthUser != null && basicAuthPassword != null) {
        final credentials =
            base64Encode(utf8.encode('$basicAuthUser:$basicAuthPassword'));
        headers['Authorization'] = 'Basic $credentials';
      }

      final body = jsonEncode(statement);
      final response = await _httpClient.post(
        lrsEndpoint,
        headers: headers,
        body: body,
      );

      final statementId = statement['id']?.toString() ?? '';
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return XApiEmissionResult(
          success: true,
          statusCode: response.statusCode,
          statementIds: [statementId],
        );
      } else {
        return XApiEmissionResult(
          success: false,
          statusCode: response.statusCode,
          message: 'LRS rejected statement: ${response.body}',
          statementIds: [statementId],
        );
      }
    } catch (e) {
      return XApiEmissionResult(
        success: false,
        statusCode: 0,
        message: 'Exception emitting statement to LRS: $e',
      );
    }
  }
}
