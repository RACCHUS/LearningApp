import 'package:flutter/foundation.dart';
import '../../models/words/word_sense_item.dart';

/// Service providing curated vocabulary definition senses and distractors (W2, P8-3).
class WordSenseService extends ChangeNotifier {
  final List<WordSenseItem> _catalog = _seedVocabularyCatalog;

  List<WordSenseItem> getAllSenses() => List.unmodifiable(_catalog);

  List<WordSenseItem> getSensesByCategory(String category) {
    return _catalog
        .where((s) => s.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  WordSenseItem? getSenseForWord(String word) {
    try {
      return _catalog.firstWhere(
        (s) => s.word.toLowerCase() == word.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  List<String> getAvailableCategories() {
    return _catalog.map((s) => s.category).toSet().toList();
  }

  static const List<WordSenseItem> _seedVocabularyCatalog = [
    WordSenseItem(
      id: 'ws_hazard_1',
      word: 'Hazard',
      partOfSpeech: 'noun',
      definition: 'A potential source of harm, danger, or adverse health effect.',
      exampleSentence: 'Frayed electrical cables present a serious fire [TARGET] on a jobsite.',
      distractorDefinitions: [
        'A protective piece of equipment worn over the face.',
        'An approved legal permit required before beginning construction.',
        'A formal written citation issued by a regulatory inspector.',
      ],
      synonyms: ['danger', 'peril', 'risk'],
      category: 'Workplace Safety',
    ),
    WordSenseItem(
      id: 'ws_mitigation_2',
      word: 'Mitigation',
      partOfSpeech: 'noun',
      definition: 'The action of reducing the severity, seriousness, or painfulness of a hazard.',
      exampleSentence: 'Installing guardrails on scaffolding is a key fall [TARGET] strategy.',
      distractorDefinitions: [
        'The process of determining legal fault after an accident.',
        'The physical destruction of defective machinery parts.',
        'The monetary compensation paid to an injured employee.',
      ],
      synonyms: ['reduction', 'alleviation', 'abatement'],
      category: 'Workplace Safety',
    ),
    WordSenseItem(
      id: 'ws_fiduciary_3',
      word: 'Fiduciary',
      partOfSpeech: 'adjective',
      definition: 'Involving trust, especially regarding the relationship between a trustee and beneficiary.',
      exampleSentence: 'A licensed real estate broker owes a [TARGET] duty of utmost loyalty to their client.',
      distractorDefinitions: [
        'Relating to physical land boundaries recorded in public property deeds.',
        'Subject to mandatory municipal zoning taxes and property assessments.',
        'Exempt from state disclosure laws under contractual agreement.',
      ],
      synonyms: ['trustee-based', 'confidential', 'bound by trust'],
      category: 'Florida Real Estate',
    ),
    WordSenseItem(
      id: 'ws_escrow_4',
      word: 'Escrow',
      partOfSpeech: 'noun',
      definition: 'A contractual arrangement in which a third party receives and disburses funds for the primary transacting parties.',
      exampleSentence: 'The buyer deposited earnest money into the title company\'s [TARGET] account.',
      distractorDefinitions: [
        'A long-term mortgage issued directly by a commercial bank.',
        'The closing commission fee distributed to real estate sales agents.',
        'A public property foreclosure auction held at the county courthouse.',
      ],
      synonyms: ['trust account', 'safekeeping deposit'],
      category: 'Florida Real Estate',
    ),
    WordSenseItem(
      id: 'ws_pathogen_5',
      word: 'Pathogen',
      partOfSpeech: 'noun',
      definition: 'A biological agent, such as a bacterium or virus, that can cause disease in its host.',
      exampleSentence: 'Cooking ground poultry to 165°F destroys harmful foodborne [TARGET]s like Salmonella.',
      distractorDefinitions: [
        'A chemical disinfectant used to clean stainless steel prep surfaces.',
        'A harmless microscopic food additive used to enhance shelf life.',
        'An allergic reaction triggered by peanuts or tree nuts.',
      ],
      synonyms: ['infectious agent', 'germ', 'microbe'],
      category: 'Food & Health Safety',
    ),
  ];
}

