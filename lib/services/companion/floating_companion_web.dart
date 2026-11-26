import 'dart:async';
import 'dart:js_interop';

import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/services/companion/floating_companion.dart';
import 'package:web/web.dart' as web;

// Document Picture-in-Picture (Chrome and Edge desktop, Firefox 151+). The
// `web` package has no typed wrapper for it yet, so this is the small part
// of the API the companion uses.
@JS('documentPictureInPicture')
external _DocumentPictureInPicture? get _documentPictureInPicture;

extension type _DocumentPictureInPicture._(JSObject _) implements JSObject {
  external JSPromise<web.Window> requestWindow(_Options options);
}

extension type _Options._(JSObject _) implements JSObject {
  external factory _Options({int width, int height});
}

FloatingWindow createFloatingWindow() => _WebFloatingWindow();

class _WebFloatingWindow implements FloatingWindow {
  web.Window? _window;
  Timer? _ticker;
  DateTime _partStarted = DateTime.now();
  String? _partTitle;
  web.Element? _clock;
  void Function()? _onDone;
  void Function()? _onClosed;

  @override
  bool get supported => _documentPictureInPicture != null;

  @override
  bool get isOpen => _window != null;

  @override
  Future<bool> open(
    FloatingContent content, {
    required void Function() onDone,
    required void Function() onClosed,
  }) async {
    final api = _documentPictureInPicture;
    if (api == null) return false;
    close();
    final web.Window window;
    try {
      // Must run inside the learner's click, or the browser refuses.
      window = await api
          .requestWindow(_Options(width: 340, height: 420))
          .toDart;
    } catch (_) {
      return false;
    }
    _window = window;
    _onDone = onDone;
    _onClosed = onClosed;
    _partTitle = null;
    window.addEventListener('pagehide', ((web.Event _) => _closed()).toJS);
    window.document.title = 'LearningApp companion';
    window.document.documentElement?.setAttribute('lang', 'en');
    _render(content);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    return true;
  }

  @override
  void update(FloatingContent content) {
    if (_window != null) _render(content);
  }

  @override
  void close() {
    final window = _window;
    if (window == null) return;
    _forget();
    window.close();
  }

  void _closed() {
    if (_window == null) return;
    final onClosed = _onClosed;
    _forget();
    onClosed?.call();
  }

  void _forget() {
    _ticker?.cancel();
    _ticker = null;
    _window = null;
    _clock = null;
    _onDone = null;
    _onClosed = null;
  }

  void _tick() {
    final clock = _clock;
    if (clock == null) return;
    final s = DateTime.now().difference(_partStarted).inSeconds;
    clock.textContent =
        'Time on this part: ${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // Every piece of text goes in through textContent, never as markup: part
  // titles are whatever the learner pasted.
  web.HTMLElement _el(web.Document doc, String tag, String text, String style) {
    final e = doc.createElement(tag) as web.HTMLElement;
    e.textContent = text;
    e.setAttribute('style', style);
    return e;
  }

  void _render(FloatingContent c) {
    final window = _window;
    if (window == null) return;
    final doc = window.document;
    final body = doc.body;
    if (body == null) return;
    if (c.partTitle != _partTitle) {
      _partTitle = c.partTitle;
      _partStarted = DateTime.now();
    }
    body.textContent = '';
    body.setAttribute(
      'style',
      'margin:0;padding:12px;background:#0f1115;color:#e8eaed;'
          'font:15px/1.4 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;',
    );
    const muted = 'margin:0 0 8px;color:#b4bac4;font-size:13px;';
    const button =
        'display:block;width:100%;min-height:44px;margin:8px 0 0;padding:8px 12px;border-radius:8px;'
        'font:inherit;cursor:pointer;';

    body.append(_el(doc, 'p', c.resourceTitle, muted));
    if (c.allDone) {
      _clock = null;
      body.append(
        _el(
          doc,
          'h1',
          'Every part is marked studied.',
          'margin:0 0 8px;font-size:17px;',
        ),
      );
      body.append(
        _el(
          doc,
          'p',
          'Go back to LearningApp and check yourself to see where you stand.',
          'margin:0 0 8px;',
        ),
      );
    } else {
      final time = c.minutes == null
          ? ''
          : ' (about ${formatStudyMinutes(c.minutes!)})';
      body.append(
        _el(
          doc,
          'h1',
          'Next: ${c.partTitle}$time',
          'margin:0 0 4px;font-size:17px;',
        ),
      );
      final clock = _el(doc, 'p', 'Time on this part: 0:00', muted);
      clock.setAttribute('aria-live', 'off');
      _clock = clock;
      body.append(clock);
      _tick();
      if (c.lookFor.isEmpty) {
        body.append(
          _el(doc, 'p', 'No objectives are matched to this part.', muted),
        );
      } else {
        body.append(
          _el(doc, 'p', 'Look for:', 'margin:0 0 4px;font-weight:600;'),
        );
        final list = _el(doc, 'ul', '', 'margin:0 0 8px;padding-left:20px;');
        for (final item in c.lookFor) {
          list.append(_el(doc, 'li', item, 'margin:0 0 4px;'));
        }
        body.append(list);
      }
      final done = _el(
        doc,
        'button',
        'Done studying this part',
        '${button}background:#8ab4f8;color:#0f1115;border:0;font-weight:600;',
      );
      done.setAttribute('type', 'button');
      done.addEventListener('click', ((web.Event _) => _onDone?.call()).toJS);
      body.append(done);
    }
    final back = _el(
      doc,
      'button',
      'Back to LearningApp for the check',
      '${button}background:transparent;color:#e8eaed;border:1px solid #5f6368;',
    );
    back.setAttribute('type', 'button');
    back.addEventListener('click', ((web.Event _) => web.window.focus()).toJS);
    body.append(back);
    body.append(
      _el(
        doc,
        'p',
        "Studied is your own note. Only LearningApp's checks count toward readiness. "
            'This timer is yours and is not saved.',
        'margin:12px 0 0;color:#b4bac4;font-size:12px;',
      ),
    );
  }
}
