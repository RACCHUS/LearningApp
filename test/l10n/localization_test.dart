import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/l10n/app_localizations.dart';
import 'package:learning_pwa/widgets/app_shell.dart';

void main() {
  group('AppLocalizations Unit Tests', () {
    test('supportedLocales includes English and Spanish', () {
      const locales = AppLocalizations.supportedLocales;
      expect(locales, contains(const Locale('en')));
      expect(locales, contains(const Locale('es')));
      expect(locales.length, 2);
    });

    test('delegate correctly identifies supported locales', () {
      expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('es')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('fr')), isFalse);
    });

    test('English translations match expected terminology', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(l10n.localeName, equals('en'));
      expect(l10n.appTitle, equals('Learning PWA'));
      expect(l10n.navLearn, equals('Learn'));
      expect(l10n.navLibrary, equals('Library'));
      expect(l10n.navProgress, equals('Progress'));
      expect(l10n.navSettings, equals('Settings'));

      expect(l10n.actionStudy, equals('Study'));
      expect(l10n.actionReview, equals('Review'));
      expect(l10n.actionHelp, equals('Help'));
      expect(l10n.actionCancel, equals('Cancel'));
      expect(l10n.actionSave, equals('Save'));
      expect(l10n.actionSubmit, equals('Submit'));
      expect(l10n.actionRetry, equals('Retry'));
      expect(l10n.actionClose, equals('Close'));

      expect(l10n.modeFlashcards, equals('Flashcards'));
      expect(l10n.modeQuiz, equals('Quiz'));
      expect(l10n.statusOffline, equals('Offline Mode'));
      expect(l10n.metricLevel(5), equals('Level 5'));
      expect(l10n.metricStreakCount(1), equals('1 Day Streak'));
      expect(l10n.metricStreakCount(7), equals('7 Days Streak'));
    });

    test('Spanish translations match expected terminology', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));

      expect(l10n.localeName, equals('es'));
      expect(l10n.navLearn, equals('Aprender'));
      expect(l10n.navLibrary, equals('Biblioteca'));
      expect(l10n.navProgress, equals('Progreso'));
      expect(l10n.navSettings, equals('Configuración'));

      expect(l10n.actionStudy, equals('Estudiar'));
      expect(l10n.actionReview, equals('Repasar'));
      expect(l10n.actionHelp, equals('Ayuda'));
      expect(l10n.actionCancel, equals('Cancelar'));
      expect(l10n.actionSave, equals('Guardar'));
      expect(l10n.actionSubmit, equals('Enviar'));
      expect(l10n.actionRetry, equals('Reintentar'));
      expect(l10n.actionClose, equals('Cerrar'));

      expect(l10n.modeFlashcards, equals('Tarjetas de estudio'));
      expect(l10n.modeQuiz, equals('Cuestionario'));
      expect(l10n.statusOffline, equals('Modo sin conexión'));
      expect(l10n.metricLevel(3), equals('Nivel 3'));
      expect(l10n.metricStreakCount(1), equals('1 día de racha'));
      expect(l10n.metricStreakCount(10), equals('10 días de racha'));
    });
  });

  group('AppLocalizations Widget Integration', () {
    Widget createLocalizedApp({required Locale locale, required Widget child}) {
      final router = GoRouter(
        initialLocation: '/learn',
        routes: [
          ShellRoute(
            builder: (context, state, shellChild) =>
                AppShell(child: shellChild),
            routes: [
              GoRoute(
                path: '/learn',
                builder: (context, state) => child,
              ),
              GoRoute(
                path: '/library',
                builder: (context, state) =>
                    const Scaffold(body: Text('LIBRARY')),
              ),
              GoRoute(
                path: '/progress',
                builder: (context, state) =>
                    const Scaffold(body: Text('PROGRESS')),
              ),
            ],
          ),
        ],
      );

      return MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      );
    }

    testWidgets('renders English navigation labels in AppShell by default',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createLocalizedApp(
          locale: const Locale('en'),
          child: const Scaffold(body: Text('Active Content')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Active Content'), findsOneWidget);
    });

    testWidgets('renders Spanish navigation labels in AppShell when locale is es',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createLocalizedApp(
          locale: const Locale('es'),
          child: const Scaffold(body: Text('Contenido Activo')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aprender'), findsOneWidget);
      expect(find.text('Biblioteca'), findsOneWidget);
      expect(find.text('Progreso'), findsOneWidget);
      expect(find.text('Contenido Activo'), findsOneWidget);
    });
  });
}

