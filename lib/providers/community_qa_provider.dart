import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';

/// The Community Q&A service used by learning screens' in-context Q&A sheet.
///
/// Defaults to the real service (it resolves the Supabase client lazily).
/// Tests override it with a service backed by an explicitly offline client,
/// so "offline" is exercised deliberately instead of through an
/// uninitialized global client.
final communityQaServiceProvider = Provider<CommunityQaService>(
  (ref) => CommunityQaService(),
);
