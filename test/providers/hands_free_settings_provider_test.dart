import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/hands_free_settings.dart';
import 'package:learning_pwa/providers/hands_free_settings_provider.dart';
import 'package:learning_pwa/services/hands_free_settings_service.dart';
import 'package:mockito/mockito.dart';

class MockHandsFreeSettingsService extends Mock
    implements HandsFreeSettingsService {}

void main() {
  group('HandsFreeSettingsProvider with mockito', () {
    late ProviderContainer container;
    late MockHandsFreeSettingsService mockService;
    late StreamController<HandsFreeSettings> settingsController;
    late StreamController<bool> stateController;

    setUp(() {
      mockService = MockHandsFreeSettingsService();
      settingsController = StreamController<HandsFreeSettings>.broadcast();
      stateController = StreamController<bool>.broadcast();

      when(mockService.initialize()).thenAnswer((_) => Future.value());
      when(mockService.settings).thenReturn(const HandsFreeSettings());
      when(mockService.isHandsFreeEnabled).thenReturn(false);
      when(mockService.settingsStream).thenAnswer((_) => settingsController.stream);
      when(mockService.stateStream).thenAnswer((_) => stateController.stream);
      when(mockService.updateSetting(any, any)).thenAnswer((invocation) {
        final key = invocation.positionalArguments[0];
        return Future.value(key ?? '');
      });
      when(mockService.saveSettings(any)).thenAnswer((invocation) {
        final settings = invocation.positionalArguments[0];
        return Future.value(settings ?? const HandsFreeSettings());
      });

      container = ProviderContainer(overrides: [
        handsFreeSettingsServiceProvider.overrideWithValue(mockService),
      ]);
    });

    tearDown(() async {
      await settingsController.close();
      await stateController.close();
      container.dispose();
    });

    test('initial state uses service defaults', () async {
      final settings = container.read(handsFreeSettingsProvider);
      expect(settings.defaultHandsFreeMode, false);
      verify(mockService.initialize()).called(1);
    });

    test('toggleDefaultHandsFreeMode delegates to service', () async {
      final notifier = container.read(handsFreeSettingsProvider.notifier);

      await notifier.toggleDefaultHandsFreeMode();

      verify(mockService.updateSetting('defaultHandsFreeMode', true)).called(1);
    });

    test('settings stream updates provider state', () async {
      const updated = HandsFreeSettings(defaultHandsFreeMode: true);

      settingsController.add(updated);
      await Future.delayed(const Duration(milliseconds: 10));

      final settings = container.read(handsFreeSettingsProvider);
      expect(settings.defaultHandsFreeMode, true);
    });
  });
}
