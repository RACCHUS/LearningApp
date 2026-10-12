import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Item definition for the visual picture-tile catalog grid.
class PreReaderPictureTileItem {
  final String id;
  final String title;
  final String subtitle;
  final String iconEmoji;
  final String route;
  final Color accentColor;
  final String spokenDescription;

  const PreReaderPictureTileItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconEmoji,
    required this.route,
    required this.accentColor,
    required this.spokenDescription,
  });
}

/// Catalog of all 8 core picture-tile modules.
const List<PreReaderPictureTileItem> officialPictureTileItems = [
  PreReaderPictureTileItem(
    id: 'tile_citizenship',
    title: 'US Citizenship',
    subtitle: '2025 Naturalization civics & oral N-400 interview drill',
    iconEmoji: '🇺🇸',
    route: '/milestones?category=citizenship',
    accentColor: Colors.blue,
    spokenDescription:
        'US Citizenship. Practice the official 2025 civics test and oral N-400 interview questions with spoken audio.',
  ),
  PreReaderPictureTileItem(
    id: 'tile_driver',
    title: 'Driver\'s License',
    subtitle: 'Florida DMV road signs, right-of-way rules & mock exam',
    iconEmoji: '🚗',
    route: '/milestones?category=driver',
    accentColor: Colors.teal,
    spokenDescription:
        'Driver\'s License. Learn Florida DMV road sign shapes and colors, right-of-way rules, and take the 50-question audio practice test.',
  ),
  PreReaderPictureTileItem(
    id: 'tile_ged',
    title: 'GED® Reading Bridge',
    subtitle: 'ABE Levels 1 to 3 with synchronized line-by-line audio',
    iconEmoji: '🎓',
    route: '/milestones?category=ged',
    accentColor: Colors.amber,
    spokenDescription:
        'GED Reading Bridge. Build reading skills step-by-step with synchronized spoken lines, preparing for adult basic education.',
  ),
  PreReaderPictureTileItem(
    id: 'tile_workplace',
    title: 'Workplace Safety',
    subtitle: 'OSHA PPE gear, GHS chemical symbols & lockout tagout',
    iconEmoji: '🦺',
    route: '/domains?category=workplace',
    accentColor: Colors.orange,
    spokenDescription:
        'Workplace Safety. Personal protective equipment, hazardous chemical symbols, ladder rules, and lockout tagout.',
  ),
  PreReaderPictureTileItem(
    id: 'tile_food',
    title: 'Food Safety',
    subtitle: 'FDA temperatures, cutting boards & 20s handwash timer',
    iconEmoji: '🍳',
    route: '/domains?category=food',
    accentColor: Colors.green,
    spokenDescription:
        'Food Safety. FDA temperature danger zone, color-coded cutting boards, Big 9 food allergens, and handwashing timer.',
  ),
  PreReaderPictureTileItem(
    id: 'tile_health',
    title: 'Health & First Aid',
    subtitle: 'Rx prescription bottle labels & cool water burn care',
    iconEmoji: '💊',
    route: '/domains?category=health',
    accentColor: Colors.pink,
    spokenDescription:
        'Health and First Aid. Read prescription medicine bottles, ask your pharmacist, and treat burns with cool running tap water.',
  ),
  PreReaderPictureTileItem(
    id: 'tile_cash',
    title: 'Cash & ATM Practice',
    subtitle: 'US coins, dollar bills & step-by-step ATM withdrawal',
    iconEmoji: '💵',
    route: '/domains?category=cash',
    accentColor: Colors.indigo,
    spokenDescription:
        'Cash and ATM Practice. Identify US coins and paper bills, practice using an ATM cash machine, and verify change.',
  ),
  PreReaderPictureTileItem(
    id: 'tile_phonics',
    title: 'Alphabet & Phonics',
    subtitle: 'Letter sounds, finger tracing & CVC word blending',
    iconEmoji: '🔤',
    route: '/literacy',
    accentColor: Colors.purple,
    spokenDescription:
        'Alphabet and Phonics Hub. Learn letter sounds, finger tracing on touch screen, sound blending, and survival signs.',
  ),
];

/// An accessible, high-contrast picture-tile grid designed specifically for
/// pre-readers and visual learners. Direct Access Rule compliant: $\le 1$ tap to launch.
class PreReaderPictureGridWidget extends ConsumerWidget {
  final VoidCallback? onAnyTileTapped;

  const PreReaderPictureGridWidget({super.key, this.onAnyTileTapped});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final audio = ref.read(preReaderAudioServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with audio read-all button
        Row(
          children: [
            const Text('🖼️', style: TextStyle(fontSize: 24)),
            const SizedBox(width: DesignTokens.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visual Picture Directory',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Tap any picture card to start learning immediately.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up),
              tooltip: 'Hear visual directory instructions',
              onPressed: () {
                audio.speak(
                    'Visual Picture Directory. Tap any picture card to start learning immediately, or tap the small speaker on any card to listen first.');
              },
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.space3),

        // 2-column or responsive Grid of picture tiles
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 580 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: officialPictureTileItems.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: DesignTokens.space3,
                mainAxisSpacing: DesignTokens.space3,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (context, index) {
                final tile = officialPictureTileItems[index];
                return _buildTileCard(context, ref, tile, theme, colorScheme);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildTileCard(
    BuildContext context,
    WidgetRef ref,
    PreReaderPictureTileItem tile,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final audio = ref.read(preReaderAudioServiceProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('picture-tile-${tile.id}'),
        onTap: () {
          onAnyTileTapped?.call();
          try {
            context.push(tile.route);
          } catch (_) {
            // Gracefully ignore in non-GoRouter test environments
          }
        },
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? tile.accentColor.withValues(alpha: 0.15)
                : tile.accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            border: Border.all(
              color: tile.accentColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(DesignTokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    tile.iconEmoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.volume_up, size: 18),
                    tooltip: 'Listen to ${tile.title}',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      audio.speak(tile.spokenDescription);
                    },
                  ),
                ],
              ),
              const Spacer(),
              Text(
                tile.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tile.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
