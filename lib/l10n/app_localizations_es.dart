// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Learning PWA';

  @override
  String get navLearn => 'Aprender';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get navProgress => 'Progreso';

  @override
  String get navSettings => 'Configuración';

  @override
  String get actionStudy => 'Estudiar';

  @override
  String get actionReview => 'Repasar';

  @override
  String get actionPractice => 'Practicar';

  @override
  String get actionHelp => 'Ayuda';

  @override
  String get actionSettings => 'Configuración';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionSubmit => 'Enviar';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get actionContinue => 'Continuar';

  @override
  String get actionSearch => 'Buscar';

  @override
  String get actionFilter => 'Filtrar';

  @override
  String get actionStart => 'Comenzar';

  @override
  String get actionFinish => 'Finalizar';

  @override
  String get modeFlashcards => 'Tarjetas de estudio';

  @override
  String get modeQuiz => 'Cuestionario';

  @override
  String get modeReading => 'Lectura';

  @override
  String get modeHandsFree => 'Modo Manos Libres';

  @override
  String get modeVoice => 'Práctica por voz';

  @override
  String get statusLoading => 'Cargando...';

  @override
  String get statusOffline => 'Modo sin conexión';

  @override
  String get statusOnline => 'En línea';

  @override
  String get statusError => 'Error';

  @override
  String get statusSuccess => 'Éxito';

  @override
  String get statusSyncing => 'Sincronizando cambios...';

  @override
  String get statusUpToDate => 'Todos los datos están sincronizados';

  @override
  String get metricStreak => 'Racha de días';

  @override
  String metricStreakCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString días de racha',
      one: '1 día de racha',
    );
    return '$_temp0';
  }

  @override
  String get metricScore => 'Puntuación';

  @override
  String get metricMastery => 'Dominio';

  @override
  String get metricAccuracy => 'Precisión';

  @override
  String get metricXp => 'PE';

  @override
  String metricLevel(int level) {
    return 'Nivel $level';
  }

  @override
  String get helpDialogTitle => '¿Cómo podemos ayudarte?';

  @override
  String get searchPlaceholder => 'Buscar lecciones, certificaciones, temas...';

  @override
  String get emptyLibraryMessage =>
      'No se encontraron cursos ni certificaciones.';
}
