import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/word_learning.dart';
import '../../services/audio_service.dart';
import '../../services/word_list_service.dart';
import '../../services/word_spelling_advisor.dart';

/// W1 private word lists and basic, independently scored audio dictation.
/// Vocabulary and combined practice remain W2.
class WordLearningScreen extends StatefulWidget {
  const WordLearningScreen({super.key});

  @override
  State<WordLearningScreen> createState() => _WordLearningScreenState();
}

class _WordLearningScreenState extends State<WordLearningScreen> {
  final WordListService _service = WordListService();
  final WordSpellingAdvisor _advisor = WordSpellingAdvisor();
  final TextEditingController _words = TextEditingController();
  final TextEditingController _answer = TextEditingController();

  List<WordList> _lists = [];
  List<WordListEntry> _entries = [];
  List<String>? _pendingWords;
  Map<int, List<String>> _pendingSuggestions = {};
  WordList? _selected;
  int? _practiceIndex;
  SpellingGrade? _grade;
  bool _assisted = false;
  bool _properNames = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  @override
  void dispose() {
    _words.dispose();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadLists() async => _run(() async {
        final lists = await _service.getLists();
        if (mounted) setState(() => _lists = lists);
      });

  Future<void> _select(WordList selected) async => _run(() async {
        final entries = await _service.getEntries(selected.id);
        if (mounted) {
          setState(() {
            _selected = selected;
            _entries = entries;
            _practiceIndex = null;
          });
        }
      });

  Future<void> _createList() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New word list'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 160,
          decoration: const InputDecoration(hintText: 'Weekly spelling words'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.trim().isEmpty) return;
    await _run(() async {
      final list = await _service.createList(title);
      final lists = await _service.getLists();
      if (mounted) {
        setState(() {
          _lists = lists;
          _selected = list;
          _entries = [];
        });
      }
    });
  }

  Future<void> _addWords() async {
    if (_selected == null || _words.text.trim().isEmpty) return;
    final words = _words.text.split(RegExp(r'[,;\\n\\r]+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length > 100) {
      setState(() => _error = 'Add up to 100 words at a time.');
      return;
    }
    await _run(() async {
      final suggestions = <int, List<String>>{};
      if (!_properNames) {
        try {
          for (var i = 0; i < words.length; i++) {
            final advice = await _advisor.check(words[i]);
            if (!advice.recognized) {
              suggestions[i] = advice.suggestions;
            }
          }
        } catch (_) {
          // A missing optional lexicon cannot prevent user-owned word entry.
          suggestions.clear();
        }
      }
      if (!mounted) return;
      if (suggestions.isNotEmpty) {
        setState(() {
          _pendingWords = words;
          _pendingSuggestions = suggestions;
        });
        return;
      }
      await _persistWords(words);
    });
  }

  Future<void> _persistWords(List<String> words) async {
    final list = _selected;
    if (list == null || words.isEmpty) return;
    await _service.addWords(
      list.id,
      words.join('\\n'),
      kind: _properNames ? WordEntryKind.properName : WordEntryKind.ordinary,
      casePolicy: _properNames ? WordCasePolicy.exact : WordCasePolicy.ignoreCase,
    );
    final entries = await _service.getEntries(list.id);
    if (mounted) {
      setState(() {
        _entries = entries;
        _pendingWords = null;
        _pendingSuggestions = {};
      });
      _words.clear();
    }
  }

  Future<void> _saveReviewedWords() async {
    final pending = _pendingWords;
    if (pending == null) return;
    await _run(() => _persistWords(pending));
  }

  Future<void> _deleteList() async {
    final current = _selected;
    if (current == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete list?'),
        content: const Text(
          'The list and its words will be removed. Your existing spelling review history is kept.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete list')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _service.deleteList(current.id);
      final lists = await _service.getLists();
      if (mounted) {
        setState(() {
          _lists = lists;
          _selected = null;
          _entries = [];
          _practiceIndex = null;
        });
      }
    });
  }

  void _startPractice() {
    if (_entries.isEmpty) return;
    setState(() {
      _practiceIndex = 0;
      _grade = null;
      _assisted = false;
      _answer.clear();
    });
  }

  Future<void> _speakWord() async {
    final idx = _practiceIndex;
    if (idx == null || idx >= _entries.length) return;
    try {
      final audio = AudioService();
      await audio.initialize();
      final entry = _entries[idx];
      final ok = await audio.speak(
        entry.pronunciationHint?.trim().isNotEmpty == true
            ? entry.pronunciationHint!
            : entry.word,
        interrupt: true,
      );
      if (!ok && mounted) {
        setState(() => _error =
            'Audio was unavailable. You can reveal the word as assisted practice.');
      }
    } catch (_) {
      if (mounted) setState(() =>
          _error = 'Audio was unavailable. Try assisted practice.');
    }
  }

  Future<void> _checkAnswer() async {
    final idx = _practiceIndex;
    if (idx == null || _grade != null || _answer.text.trim().isEmpty) return;
    final entry = _entries[idx];
    final grade = SpellingScorer.score(
      submitted: _answer.text,
      target: entry.word,
      acceptedForms: entry.acceptedForms,
      casePolicy: entry.casePolicy,
      assisted: _assisted,
    );
    await _run(() async {
      await _service.recordUnassistedSpelling(entry, grade);
      if (mounted) setState(() => _grade = grade);
    });
  }

  void _nextWord() {
    final idx = _practiceIndex;
    if (idx == null) return;
    setState(() {
      _practiceIndex = idx + 1;
      _grade = null;
      _assisted = false;
      _answer.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selected?.title ?? 'My word lists'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_practiceIndex != null || _selected != null) {
              setState(() {
                _practiceIndex = null;
                _selected = null;
              });
              _loadLists();
            } else {
              context.go('/library');
            }
          },
        ),
        actions: [
          if (_selected != null && _practiceIndex == null)
            IconButton(icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete list', onPressed: _busy ? null : _deleteList),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(_error!, style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                  ),
                if (_busy) const LinearProgressIndicator(),
                if (_practiceIndex != null)
                  _buildPractice()
                else if (_selected != null)
                  _buildEntries()
                else
                  _buildLists(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLists() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Create personal spelling lists or revisit your words.'),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: _busy ? null : _createList,
        icon: const Icon(Icons.add), label: const Text('Create a word list')),
      const SizedBox(height: 12),
      for (final list in _lists)
        Card(child: ListTile(
          title: Text(list.title),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : () => _select(list),
        )),
      if (_lists.isEmpty && !_busy)
        const Padding(padding: EdgeInsets.all(16),
          child: Text('No lists yet. Continue as Guest or sign in to save your words.')),
      if (_lists.isEmpty)
        TextButton(onPressed: () => context.go('/login'),
          child: const Text('Continue as Guest / Sign in')),
    ],
  );

  Widget _buildEntries() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Paste words separated by commas or new lines.'),
      const SizedBox(height: 10),
      TextField(
        controller: _words,
        onChanged: (_) {
          if (_pendingWords != null) {
            setState(() {
              _pendingWords = null;
              _pendingSuggestions = {};
            });
          }
        },
        minLines: 2, maxLines: 6,
        decoration: const InputDecoration(
          labelText: 'Your words', border: OutlineInputBorder()),
      ),
      SwitchListTile(
        title: const Text('These are names or proper nouns'),
        subtitle: const Text('Require matching capitalization'),
        value: _properNames,
        onChanged: (v) => setState(() {
          _properNames = v;
          _pendingWords = null;
          _pendingSuggestions = {};
        }),
      ),
      FilledButton.icon(
        onPressed: _busy ? null : _addWords,
        icon: const Icon(Icons.add),
        label: const Text('Add words'),
      ),
      const SizedBox(height: 8),
      const Text('Dictionary suggestions are advisory. Names, inflections and trade terms may be absent. You can always keep what you typed.'),
      if (_pendingWords != null) ...[
        const SizedBox(height: 16),
        Text('Review possible spellings',
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text('Nothing is changed automatically. Choose a suggestion or keep the original spelling.'),
        for (final warning in _pendingSuggestions.entries)
          Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entered: ${_pendingWords![warning.key]}'),
                const Text('Not found in the base-word list. This may still be valid.'),
                if (warning.value.isNotEmpty)
                  Wrap(spacing: 6, children: [
                    for (final suggestion in warning.value)
                      OutlinedButton(
                        onPressed: _busy ? null : () => setState(
                          () => _pendingWords![warning.key] = suggestion),
                        child: Text('Use ${suggestion}'),
                      ),
                  ]),
              ],
            ),
          )),
        Row(children: [
          Expanded(child: FilledButton(
            onPressed: _busy ? null : _saveReviewedWords,
            child: const Text('Save words as shown'),
          )),
          TextButton(
            onPressed: () => setState(() {
              _pendingWords = null;
              _pendingSuggestions = {};
            }),
            child: const Text('Cancel'),
          ),
        ]),
      ],
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _entries.isEmpty || _busy ? null : _startPractice,
        icon: const Icon(Icons.hearing),
        label: Text('Practice spelling (${_entries.length})'),
      ),
      const SizedBox(height: 12),
      for (final entry in _entries)
        ListTile(
          title: Text(entry.word),
          subtitle: entry.kind == WordEntryKind.properName
              ? const Text('Proper name · exact capitalization') : null,
          trailing: IconButton(
            tooltip: 'Remove from list (preserves progress)',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _busy ? null : () => _run(() async {
              await _service.removeWord(entry.id);
              final entries = await _service.getEntries(entry.listId);
              if (mounted) setState(() => _entries = entries);
            }),
          ),
        ),
    ],
  );

  Widget _buildPractice() {
    final idx = _practiceIndex!;
    if (idx >= _entries.length) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.check_circle_outline, size: 60),
        const SizedBox(height: 10),
        const Text('Practice complete', textAlign: TextAlign.center),
        FilledButton(onPressed: () => setState(() => _practiceIndex = null),
          child: const Text('Back to my list')),
      ]);
    }
    final entry = _entries[idx];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Word ${idx + 1} of ${_entries.length}',
        style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 18),
      const Text('Listen, then spell the word without looking at it.'),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _speakWord, icon: const Icon(Icons.volume_up),
        label: const Text('Hear word / replay'),
      ),
      TextButton(
        onPressed: () => setState(() => _assisted = true),
        child: const Text('Audio unclear? Reveal as assisted practice'),
      ),
      if (_assisted)
        Text('Target word: ${entry.word} (assisted — not counted as unaided recall)'),
      const SizedBox(height: 18),
      TextField(
        controller: _answer,
        enabled: _grade == null && !_busy,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        decoration: const InputDecoration(
          labelText: 'Type the spelling',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _checkAnswer(),
      ),
      const SizedBox(height: 12),
      if (_grade == null)
        FilledButton(
          onPressed: _busy ? null : _checkAnswer,
          child: const Text('Check spelling'),
        )
      else ...[
        Text(_grade!.correct ? 'Correct' : 'Not quite',
          style: Theme.of(context).textTheme.titleLarge),
        Text('Spelling: ${entry.word}'),
        if (_grade!.assisted)
          const Text('Assisted practice is not counted as independent recall.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: _nextWord, child: const Text('Next word')),
      ],
    ]);
  }
}
