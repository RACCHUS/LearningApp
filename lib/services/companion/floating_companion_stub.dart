import 'package:learning_pwa/services/companion/floating_companion.dart';

/// Non-web builds (VM tests): there is no floating window.
FloatingWindow createFloatingWindow() => _NoFloatingWindow();

class _NoFloatingWindow implements FloatingWindow {
  @override
  bool get supported => false;

  @override
  bool get isOpen => false;

  @override
  Future<bool> open(
    FloatingContent content, {
    required void Function() onDone,
    required void Function() onClosed,
  }) async => false;

  @override
  void update(FloatingContent content) {}

  @override
  void close() {}
}
