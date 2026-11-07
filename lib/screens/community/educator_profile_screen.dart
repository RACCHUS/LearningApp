import 'package:flutter/material.dart';
import 'package:learning_pwa/models/community/educator_profile.dart';
import 'package:learning_pwa/models/community/educator_subject.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/models/community/educator_reputation.dart';
import 'package:learning_pwa/models/community/community_resource.dart';
import 'package:learning_pwa/services/community/educator_service.dart';
import 'package:learning_pwa/services/community/educator_reputation_service.dart';
import 'package:learning_pwa/services/community/community_resource_service.dart';
import 'package:learning_pwa/widgets/community/educator_profile_card.dart';
import 'package:learning_pwa/widgets/community/educator_credential_badge.dart';
import 'package:learning_pwa/widgets/community/educator_profile_edit_dialog.dart';
import 'package:learning_pwa/widgets/community/resource_card.dart';
import 'package:learning_pwa/screens/community/resource_authoring_screen.dart';

/// Full screen view for an educator's profile and credentials (ECO-04).
///
/// Implements Phase 2 & 3 Requirements:
/// - Distinguishes verified state licensure from platform-vetted and self-declared claims.
/// - Invariant: "Teacher does not own the subject or course."
/// - Surfaces evidence-weighted reputation metrics.
/// - Surfaces educator's standalone authored resources and creator studio (ECO-06).
class EducatorProfileScreen extends StatefulWidget {
  final String educatorId;
  final EducatorService? service;
  final EducatorReputationService? reputationService;
  final CommunityResourceService? resourceService;

  const EducatorProfileScreen({
    super.key,
    required this.educatorId,
    this.service,
    this.reputationService,
    this.resourceService,
  });

  @override
  State<EducatorProfileScreen> createState() => _EducatorProfileScreenState();
}

class _EducatorProfileScreenState extends State<EducatorProfileScreen> {
  late final EducatorService _service;
  late final EducatorReputationService _reputationService;
  late final CommunityResourceService _resourceService;

  EducatorProfile? _profile;
  List<EducatorSubject> _subjects = [];
  List<EducatorVerification> _verifications = [];
  EducatorReputation? _reputation;
  List<CommunityResource> _authoredResources = [];
  bool _isFollowing = false;
  bool _isLoading = true;
  String? _error;

  bool get _isOwner => _service.currentUserId == widget.educatorId;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EducatorService();
    _reputationService = widget.reputationService ?? EducatorReputationService(educatorService: _service);
    _resourceService = widget.resourceService ?? CommunityResourceService();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _service.fetchProfile(widget.educatorId);
      final subjects = await _service.fetchSubjects(widget.educatorId);
      final verifications = _isOwner
          ? await _service.fetchVerifications(widget.educatorId)
          : await _service.fetchPublicVerifications(widget.educatorId);
      final reputation = await _reputationService.fetchReputation(widget.educatorId);
      final isFollowing = await _service.isFollowing(widget.educatorId);
      final resources = await _resourceService.fetchAuthorResources(widget.educatorId);

      if (mounted) {
        setState(() {
          _profile = profile;
          _subjects = subjects;
          _verifications = verifications;
          _reputation = reputation;
          _authoredResources = resources;
          _isFollowing = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load educator profile';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow(bool follow) async {
    final prev = _isFollowing;
    setState(() => _isFollowing = follow);

    final success = follow
        ? await _service.followEducator(widget.educatorId)
        : await _service.unfollowEducator(widget.educatorId);

    if (!success && mounted) {
      setState(() => _isFollowing = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update follow status')),
      );
    }
  }

  void _openEditDialog() {
    EducatorProfileEditDialog.show(
      context,
      initialProfile: _profile,
      initialSubjects: _subjects,
      service: _service,
      onSaved: _loadProfileData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Educator Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Educator Profile')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Educator profile not found'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadProfileData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final p = _profile!;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.displayName),
        actions: [
          if (_isOwner)
            IconButton(
              key: const Key('edit_profile_icon_button'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profile',
              onPressed: _openEditDialog,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Profile Card
                EducatorProfileCard(
                  profile: p,
                  subjects: _subjects,
                  verifications: _verifications,
                  reputation: _reputation,
                  isFollowing: _isFollowing,
                  onFollowToggle: _isOwner ? null : _toggleFollow,
                  showFollowButton: !_isOwner,
                ),
                const SizedBox(height: 20),

                // Credentials & Verifications Section
                Text(
                  'Verified Credentials & Experience',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_verifications.isEmpty)
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No verified credentials submitted yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ..._verifications.map((v) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: ListTile(
                      leading: Icon(
                        v.isLicensed ? Icons.verified_user : (v.isPlatformVetted ? Icons.verified : Icons.info_outline),
                        color: v.isLicensed ? Colors.teal : (v.isPlatformVetted ? Colors.blue : Colors.blueGrey),
                      ),
                      title: Text(v.issuer ?? (v.isLicensed ? 'Regulatory Licensure' : 'Contributor Claim')),
                      subtitle: Text(
                        v.isLicensed
                            ? 'Verified State/Regulatory License (${v.jurisdiction ?? 'FL'})'
                            : (v.isPlatformVetted ? 'Platform Editorial Review' : 'Self-Declared Claim'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: EducatorCredentialBadge(verification: v, isCompact: true),
                    ),
                  )),

                const SizedBox(height: 20),

                // Reputation Breakdown
                if (_reputation != null) ...[
                  Text(
                    'Contributor Evidence & Reputation',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetric(
                                label: 'Accepted Answers',
                                value: '${_reputation!.acceptedAnswersCount}',
                                icon: Icons.check_circle,
                                color: Colors.green,
                              ),
                              _buildMetric(
                                label: 'Community Upvotes',
                                value: '${_reputation!.upvotesCount}',
                                icon: Icons.thumb_up,
                                color: Colors.blue,
                              ),
                              _buildMetric(
                                label: 'Reputation Score',
                                value: '${_reputation!.score}',
                                icon: Icons.military_tech,
                                color: Colors.amber[800]!,
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Contributor Tier:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                              EducatorReputationBadge(tier: _reputation!.tier),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Acceptance Quality Ratio:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                              Text('${(_reputation!.qualityRatio * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Authored Resources & Guides Section (ECO-06, Phase 3)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Authored Resources & Guides',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (_isOwner)
                      TextButton.icon(
                        key: const Key('author_new_resource_button'),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Author Resource'),
                        onPressed: () async {
                          final created = await Navigator.of(context).push<CommunityResource>(
                            MaterialPageRoute(
                              builder: (ctx) => ResourceAuthoringScreen(
                                resourceService: _resourceService,
                                authorId: widget.educatorId,
                                authorName: _profile?.displayName ?? 'Educator',
                                authorHeadline: _profile?.headline,
                              ),
                            ),
                          );
                          if (created != null) {
                            _loadProfileData();
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_authoredResources.isEmpty)
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No standalone resources published yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ..._authoredResources.map((res) => ResourceCard(resource: res)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

