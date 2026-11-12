/// Structured, audit-safe error codes for content generation, import and
/// publication (master plan v2.6 Appendix D.1).
///
/// Every code carries a plain-language explanation and a safe recovery
/// route. Messages never include secrets, private content or protected
/// answer keys.
enum GenerationErrorCode {
  invalidStateTransition(
    'invalid_state_transition',
    'That step is not possible right now.',
    'Reload the job to see its current status, then try again.',
  ),
  unauthorizedScope(
    'unauthorized_scope',
    'You do not have access to this content.',
    'Sign in with the account that owns it, or start your own copy.',
  ),
  unknownJobOrSlot(
    'unknown_job_or_slot',
    'This answer does not belong to the current job or slot.',
    'Paste the response for this job only. Other jobs are not merged in.',
  ),
  schemaUnsupported(
    'schema_unsupported',
    'This format or item type is not supported.',
    'Ask the AI to answer in the requested format, or copy the prompt again.',
  ),
  payloadTooLarge(
    'payload_too_large',
    'The pasted response is too long.',
    'Ask for fewer items at a time and paste each part separately.',
  ),
  structureTooDeep(
    'structure_too_deep',
    'The pasted response is nested too deeply.',
    'Ask the AI to use the flat format from the prompt.',
  ),
  invalidJson(
    'invalid_json',
    'The pasted response is not valid JSON.',
    'Copy the whole code block again. Nothing was changed or guessed.',
  ),
  invalidJsonlRecord(
    'invalid_jsonl_record',
    'One line of the response could not be read.',
    'Valid lines were kept. Ask the AI to resend only the missing items.',
  ),
  payloadAmbiguous(
    'payload_ambiguous',
    'The paste contains more than one possible answer block.',
    'Paste only the single block you want to use.',
  ),
  answerUnresolvable(
    'answer_unresolvable',
    'The correct answer could not be identified.',
    'Ask for the answer as a single letter that matches one option.',
  ),
  optionsAmbiguous(
    'options_ambiguous',
    'Two or more answer options are the same.',
    'Ask the AI to rewrite the options so each one is different.',
  ),
  correctIndexOutOfRange(
    'correct_index_out_of_range',
    'The correct answer points to an option that does not exist.',
    'Ask the AI to choose one of the listed options.',
  ),
  reviewRequired(
    'review_required',
    'This item needs a review before it can be used.',
    'Check the item, fix what is marked, then validate again.',
  ),
  checkpointConflict(
    'checkpoint_conflict',
    'This work was changed somewhere else.',
    'Reload to see the latest version. Your copy is kept for export.',
  ),
  checkpointUnavailable(
    'checkpoint_unavailable',
    'Saving is not available on this device right now.',
    'Export your work to keep a copy, then try again later.',
  ),
  sourceRightsBlocked(
    'source_rights_blocked',
    'The source rights do not allow this use.',
    'Use a source that permits it, or keep the content private.',
  ),
  publicationDenied(
    'publication_denied',
    'This content cannot be published by this account.',
    'Keep it as a private draft, or ask an authorized reviewer.',
  );

  const GenerationErrorCode(this.code, this.userMessage, this.recovery);

  /// Stable wire/log identifier.
  final String code;

  /// Plain-language explanation for the learner.
  final String userMessage;

  /// Safe next step for the learner.
  final String recovery;
}

/// A structured error with an optional location (slot code or line number).
class GenerationError {
  const GenerationError(this.errorCode, {this.slot, this.line, this.detail});

  final GenerationErrorCode errorCode;

  /// Slot code (e.g. `S2`) the error applies to, when known.
  final String? slot;

  /// 1-based line number for line-record input, when known.
  final int? line;

  /// Developer-facing detail. Must never contain secrets or protected keys.
  final String? detail;

  String get code => errorCode.code;

  @override
  String toString() => [
    code,
    if (slot != null) 'slot=$slot',
    if (line != null) 'line=$line',
    if (detail != null) detail!,
  ].join(' ');
}
