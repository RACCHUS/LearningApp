import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/companion/video_embed.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/screens/companion/add_resource_screen.dart';
import 'package:learning_pwa/screens/companion/companion_screen.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';

/// Whether two links point at the same thing for the purpose of finding the
/// learner's resource: the same YouTube video, or the same address once the
/// fragment and a trailing slash are set aside. Both must already be cleaned
/// by `normalizeLearnerLink`.
bool sameResourceLink(String a, String b) {
  final va = VideoEmbed.youTubeId(a), vb = VideoEmbed.youTubeId(b);
  if (va != null || vb != null) return va == vb;
  String bare(String url) {
    final u = Uri.parse(url).removeFragment();
    final path = u.path.endsWith('/')
        ? u.path.substring(0, u.path.length - 1)
        : u.path;
    return u.replace(path: path).toString();
  }

  return bare(a) == bare(b);
}

/// The learner's resource whose link is [url], in any of their goals. Null
/// while loading or when there is none.
final resourceForLinkProvider = FutureProvider.family<LearnerResource?, String>(
  (ref, url) async {
    for (final goal in ref.watch(captureGoalsProvider)) {
      final resources = await ref.watch(
        learnerResourcesProvider(goal.targetId).future,
      );
      for (final r in resources) {
        if (r.url != null && sameResourceLink(r.url!, url)) return r;
      }
    }
    return null;
  },
);

/// What the browser extension opens (companion plan v1.0 §5.4, EX-9): the
/// companion for the page the learner is on if it is one of their
/// resources, otherwise the form to add it. The address and title arrive in
/// the URL fragment from the learner's own click; nothing is fetched, and
/// nothing is saved until they choose to. Behind
/// `content.companion_extension`.
class CompanionForLinkScreen extends ConsumerWidget {
  const CompanionForLinkScreen({super.key, this.url, this.title});

  final String? url;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget message(String text, String key) => Scaffold(
      appBar: AppBar(
        title: const Text('LearningApp companion'),
        actions: const [HelpAction()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Text(text, key: Key(key)),
      ),
    );

    if (!ref.watch(companionExtensionEnabledProvider)) {
      return message(
        'The LearningApp browser extension is not available right now. '
            'You can still open LearningApp and add what you are studying from a goal.',
        'extension_unavailable',
      );
    }
    final cleaned = normalizeLearnerLink(url ?? '');
    final link = cleaned.url;
    if (link == null) {
      // No address, or one LearningApp does not keep (not https, a browser
      // page, a local file): start from the plain form.
      return AddResourceScreen(initialTitle: title, viaExtension: true);
    }
    final match = ref.watch(resourceForLinkProvider(link));
    if (match.isLoading) {
      return Scaffold(
        appBar: AppBar(actions: const [HelpAction()]),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final resource = match.valueOrNull;
    if (resource != null) {
      return CompanionRouteScreen(
        targetId: resource.targetId,
        resourceId: resource.id,
      );
    }
    return AddResourceScreen(
      initialUrl: link,
      initialTitle: title,
      viaExtension: true,
    );
  }
}
