import 'package:flutter/foundation.dart';
import '../../models/language/bilingual_bridge_item.dart';

/// Service providing curated bilingual vocational and life-milestone vocabulary pairs (P8-4).
class BilingualVocabService extends ChangeNotifier {
  final List<BilingualBridgeItem> _items = _seedBilingualCatalog;

  List<BilingualBridgeItem> getAllItems() => List.unmodifiable(_items);

  List<BilingualBridgeItem> getItemsByCategory(String category) {
    return _items
        .where((i) => i.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  List<String> getCategories() {
    return _items.map((i) => i.category).toSet().toList();
  }

  static const List<BilingualBridgeItem> _seedBilingualCatalog = [
    BilingualBridgeItem(
      id: 'bi_osha_loto_1',
      englishTerm: 'Lockout / Tagout (LOTO)',
      spanishTerm: 'Bloqueo / Etiquetado',
      englishPhonetic: '/ˈlɒk.aʊt ˈtæɡ.aʊt/',
      spanishPhonetic: '/bloˈke.o e.ti.keˈta.ðo/',
      englishDefinition: 'Specific practices and procedures to safeguard employees from unexpected machine energization.',
      spanishDefinition: 'Prácticas y procedimientos para proteger a los trabajadores del arranque inesperado de maquinaria.',
      visualEmoji: '🔒',
      category: 'OSHA Workplace Safety',
      regulatoryCitation: '29 CFR 1910.147',
    ),
    BilingualBridgeItem(
      id: 'bi_osha_ppe_2',
      englishTerm: 'Personal Protective Equipment (PPE)',
      spanishTerm: 'Equipo de Protección Personal (EPP)',
      englishPhonetic: '/ˈpɜː.sən.əl prəˈtek.tɪv ɪˈkwɪp.mənt/',
      spanishPhonetic: '/eˈki.po de pro.tekˈsjon per.soˈnal/',
      englishDefinition: 'Protective gear worn to minimize exposure to hazards that cause serious workplace injuries.',
      spanishDefinition: 'Equipo usado para minimizar el riesgo ante peligros que causan lesiones laborales.',
      visualEmoji: '🥽',
      category: 'OSHA Workplace Safety',
      regulatoryCitation: '29 CFR 1910.132',
    ),
    BilingualBridgeItem(
      id: 'bi_dmv_yield_3',
      englishTerm: 'Yield Right-of-Way',
      spanishTerm: 'Ceda el Paso',
      englishPhonetic: '/jiːld raɪt əv weɪ/',
      spanishPhonetic: '/ˈse.ða el ˈpa.so/',
      englishDefinition: 'Slow down and give precedence to oncoming traffic, pedestrians, or vehicles already in the intersection.',
      spanishDefinition: 'Disminuir la velocidad y dar paso a los vehículos o peatones que ya transitan por la intersección.',
      visualEmoji: '🔻',
      category: 'Florida Driver Rules',
      regulatoryCitation: 'F.S. 316.123',
    ),
    BilingualBridgeItem(
      id: 'bi_dmv_school_4',
      englishTerm: 'School Speed Zone',
      spanishTerm: 'Zona Escolar de Velocidad',
      englishPhonetic: '/skuːl spiːd zoʊn/',
      spanishPhonetic: '/ˈso.na es.koˈlar de be.lo.siˈðað/',
      englishDefinition: 'Enforced speed limit (usually 15-20 mph) active during child arrival and dismissal hours.',
      spanishDefinition: 'Límite de velocidad reducido vigente durante las horas de entrada y salida de estudiantes.',
      visualEmoji: '🚸',
      category: 'Florida Driver Rules',
      regulatoryCitation: 'F.S. 316.1895',
    ),
    BilingualBridgeItem(
      id: 'bi_health_rx_5',
      englishTerm: 'Prescription Dosage',
      spanishTerm: 'Dosis Recetada',
      englishPhonetic: '/prɪˈskrɪp.ʃən ˈdoʊ.sɪdʒ/',
      spanishPhonetic: '/ˈdo.sis re.seˈta.ða/',
      englishDefinition: 'The exact amount and frequency of medication specified by a licensed physician.',
      spanishDefinition: 'La cantidad y frecuencia exacta de medicamento indicada por un médico colegiado.',
      visualEmoji: '💊',
      category: 'Medical & Health Literacy',
      regulatoryCitation: 'FDA 21 CFR § 201.5',
    ),
  ];
}

