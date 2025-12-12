import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/hands_free_settings.dart';
import 'package:learning_pwa/providers/hands_free_settings_provider.dart';
import 'package:learning_pwa/services/hands_free_settings_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'hands_free_settings_provider_test.mocks.dart';

@GenerateMocks([HandsFreeSettingsService])
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

      when(mockService.initialize()).thenAnswer((_) async {});
      when(mockService.settings).thenReturn(const HandsFreeSettings());
      when(mockService.isHandsFreeEnabled).thenReturn(false);
      when(mockService.settingsStream).thenAnswer((_) => settingsController.stream);
      when(mockService.stateStream).thenAnswer((_) => stateController.stream);
      when(mockService.updateSetting(any, any)).thenAnswer((_) async {});
      when(mockService.saveSettings(any)).thenAnswer((_) async {});

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
      // First read the provider to initialize it
      container.read(handsFreeSettingsProvider);
      await Future.delayed(const Duration(milliseconds: 50));
      
      const updated = HandsFreeSettings(defaultHandsFreeMode: true);
      settingsController.add(updated);
      await Future.delayed(const Duration(milliseconds: 50));

      final settings = container.read(handsFreeSettingsProvider);
      expect(settings.defaultHandsFreeMode, true);
    });
  });
}
