/// Global voice service modules.
/// 
/// This directory contains modular components extracted from GlobalVoiceService
/// to improve maintainability and testability.
/// 
/// Components:
/// - [PhraseAccumulator] - Handles multi-word phrase accumulation
/// - [CommandSynonymMapper] - Maps speech variants to standard commands
/// - [GlobalCommandExecutor] - Executes navigation and actions
/// - [ContextualHelpProvider] - Provides route-specific help text

export 'phrase_accumulator.dart';
export 'command_synonym_mapper.dart';
export 'command_executor.dart';
export 'contextual_help_provider.dart';
