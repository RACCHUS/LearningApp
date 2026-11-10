/// Product analytics dimensions are explicitly allowlisted and categorical.
 ///
 /// This contract carries **no user id**, raw search text, message content,
 /// video URL, assessment answers or payment state. The server must independently
 /// validate identity, consent, eligibility and event deduplication.
enum ProductEventKind {
  appSessionStarted,
  surfaceViewed,
  goalSelected,
  resourceSearchSubmitted,
  resourceOpened,
  externalResourceClicked,
  lessonEngaged,
  featureErrorObserved,
}

extension ProductEventKindWire on ProductEventKind {
  String get wireName => switch (this) {
        ProductEventKind.appSessionStarted => 'app_session_started',
        ProductEventKind.surfaceViewed => 'surface_viewed',
        ProductEventKind.goalSelected => 'goal_selected',
        ProductEventKind.resourceSearchSubmitted =>
          'resource_search_submitted',
        ProductEventKind.resourceOpened => 'resource_opened',
        ProductEventKind.externalResourceClicked =>
          'external_resource_clicked',
        ProductEventKind.lessonEngaged => 'lesson_engaged',
        ProductEventKind.featureErrorObserved => 'feature_error_observed',
      };
}

class ProductEvent {
  static const int schemaVersion = 1;

  static const Map<ProductEventKind, Set<String>> allowedKeys = {
    ProductEventKind.appSessionStarted: {'surface'},
    ProductEventKind.surfaceViewed: {'surface'},
    ProductEventKind.goalSelected: {'goal_type'},
    ProductEventKind.resourceSearchSubmitted: {
      'source_type', 'query_category',
    },
    ProductEventKind.resourceOpened: {
      'resource_id', 'resource_type', 'source_tier',
    },
    ProductEventKind.externalResourceClicked: {
      'resource_id', 'provider_category', 'referral_id',
    },
    ProductEventKind.lessonEngaged: {'resource_id', 'mode'},
    ProductEventKind.featureErrorObserved: {
      'error_category', 'feature',
    },
  };

  /// Prevent accidental high-cardinality free text even on approved keys.
  /// Resource IDs must be catalog identifiers, not URLs or titles.
  static final RegExp _valuePattern = RegExp(r'^[a-zA-Z0-9_.:-]{1,64}$');
  static final RegExp _uuidPattern =
      RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$');

  final String eventId;
  final String sessionId;
  final ProductEventKind kind;
  final DateTime occurredAt;
  final Map<String, String> dimensions;

  ProductEvent({
    required this.eventId,
    required this.sessionId,
    required this.kind,
    required DateTime occurredAt,
    Map<String, String> dimensions = const {},
  })  : occurredAt = occurredAt.toUtc(),
        dimensions = Map.unmodifiable(dimensions) {
    if (!_uuidPattern.hasMatch(eventId) ||
        !_uuidPattern.hasMatch(sessionId)) {
      throw ArgumentError('Event and session identifiers must be UUIDs');
    }
    if (dimensions.length > 5 ||
        dimensions.keys.any((k) => !allowedKeys[kind]!.contains(k)) ||
        dimensions.values.any((v) => !_valuePattern.hasMatch(v))) {
      throw ArgumentError('Unapproved or unbounded product event dimension');
    }
  }

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'session_id': sessionId,
        'event_name': kind.wireName,
        'schema_version': schemaVersion,
        'occurred_at_client': occurredAt.toIso8601String(),
        'properties': dimensions,
      };
}
