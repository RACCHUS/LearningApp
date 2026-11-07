import 'package:flutter/material.dart';
import 'package:learning_pwa/models/community/educator_profile.dart';
import 'package:learning_pwa/models/community/educator_subject.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/models/community/educator_reputation.dart';
import 'package:learning_pwa/widgets/community/educator_credential_badge.dart';

/// Interactive profile card for community educators (ECO-04).
///
/// Implements Phase 2 Requirements:
/// - Bio, canonical subjects taught, languages.
/// - Clear distinction between self-declared and verified credentials.
/// - Evidence-weighted reputation badge.
/// - Follow/unfollow toggle action for learners.
class EducatorProfileCard extends StatelessWidget {
  final EducatorProfile profile;
  final List<EducatorSubject> subjects;
  final List<EducatorVerification> verifications;
  final EducatorReputation? reputation;
  final bool isFollowing;
  final ValueChanged<bool>? onFollowToggle;
  final VoidCallback? onViewProfile;
  final bool showFollowButton;
  final bool isCompact;

  const EducatorProfileCard({
    super.key,
    required this.profile,
    this.subjects = const [],
    this.verifications = const [],
    this.reputation,
    this.isFollowing = false,
    this.onFollowToggle,
    this.onViewProfile,
    this.showFollowButton = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = profile.displayName.isNotEmpty
        ? profile.displayName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'ED';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onViewProfile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: isCompact ? 20 : 26,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: Text(initials, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isCompact ? 13 : 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.displayName,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profile.isAcceptingQuestions) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Accepting questions',
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (profile.headline != null && profile.headline!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            profile.headline!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            maxLines: isCompact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showFollowButton) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: Key('follow_button_${profile.id}'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: isFollowing ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
                      ),
                      icon: Icon(
                        isFollowing ? Icons.check : Icons.person_add_alt_1,
                        size: 14,
                        color: isFollowing ? theme.colorScheme.primary : null,
                      ),
                      label: Text(
                        isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          fontSize: 12,
                          color: isFollowing ? theme.colorScheme.primary : null,
                        ),
                      ),
                      onPressed: onFollowToggle != null ? () => onFollowToggle!(!isFollowing) : null,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Badges: Reputation Tier & Credential Badges
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (reputation != null)
                    EducatorReputationBadge(
                      tier: reputation!.tier,
                      score: reputation!.score,
                      isCompact: isCompact,
                    ),
                  for (final v in verifications)
                    EducatorCredentialBadge(
                      verification: v,
                      isCompact: isCompact,
                    ),
                ],
              ),

              // Bio
              if (!isCompact && profile.bio != null && profile.bio!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  profile.bio!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Subjects
              if (subjects.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: subjects.map((s) => Chip(
                    label: Text(s.subjectName, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

