/// Kinds of slot an `la-gen/1.1` job may ask a model to fill.
enum SlotKind {
  explanation('explanation'),
  term('term'),
  mcq('mcq');

  const SlotKind(this.wire);

  final String wire;

  static SlotKind? fromWire(Object? value) {
    for (final k in values) {
      if (k.wire == value) return k;
    }
    return null;
  }
}

/// One slot the app created before asking the model (master plan v2.6
/// §5.6 "Why slots"). The model fills content only; it never chooses IDs.
class SlotSpec {
  const SlotSpec({
    required this.code,
    required this.kind,
    required this.conceptCode,
    this.allowedSupport = const {},
  });

  /// Short slot code supplied in the prompt, e.g. `S2`.
  final String code;
  final SlotKind kind;

  /// Short concept code supplied in the prompt, e.g. `C1`.
  final String conceptCode;

  /// Fact codes (e.g. `F2`) this slot may cite.
  final Set<String> allowedSupport;
}

/// The app-owned slot plan for one job. Short codes are resolved to real
/// IDs only by an authorized layer; a pasted code never establishes them.
class SlotPlan {
  SlotPlan({required this.jobCode, required List<SlotSpec> slots})
    : slots = List.unmodifiable(slots),
      _byCode = {for (final s in slots) s.code: s} {
    if (_byCode.length != slots.length) {
      throw ArgumentError('Slot codes must be unique');
    }
  }

  /// Short job code, e.g. `J7F3A`.
  final String jobCode;

  /// Slots in presentation order.
  final List<SlotSpec> slots;

  final Map<String, SlotSpec> _byCode;

  SlotSpec? operator [](String code) => _byCode[code];

  /// The sentinel the model is asked to echo, e.g. `END-J7F3A`.
  String get endSentinel => 'END-$jobCode';
}
