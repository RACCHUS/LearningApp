import 'package:flutter/material.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/models/community/educator_reputation.dart';

/// Renders distinct credential badges for community educators (ECO-04).
///
/// Strictly distinguishes between:
/// 1. Licensed regulatory credentials (e.g., FL DBPR, CNA, CPA, EPA)
/// 2. Platform-vetted credentials (reviewed by editorial staff)
/// 3. Self-declared contributor experience claims (unverified)
class EducatorCredentialBadge extends StatelessWidget {
  final EducatorVerification verification;
  final bool isCompact;

  const EducatorCredentialBadge({
    super.key,
    required this.verification,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (verification.isLicensed) {
      return _buildLicensedBadge(context);
    } else if (verification.isPlatformVetted) {
      return _buildPlatformVettedBadge(context);
    } else {
      return _buildSelfDeclaredBadge(context);
    }
  }

  Widget _buildLicensedBadge(BuildContext context) {
    final jurisdiction = verification.jurisdiction ?? '';
    final issuer = verification.issuer ?? 'State Board';
    final label = isCompact
        ? 'Licensed ($issuer)'
        : 'State Licensed${jurisdiction.isNotEmpty ? ' • $jurisdiction' : ''}';

    return InkWell(
      onTap: () => _showCredentialInfoDialog(
        context,
        title: 'Verified Regulatory Licensure',
        icon: Icons.verified_user,
        color: Colors.teal,
        details: [
          'Type: Official State/Regulatory License',
          'Issuer: $issuer',
          if (jurisdiction.isNotEmpty) 'Jurisdiction: $jurisdiction',
          if (verification.verifiedAt != null)
            'Verified Date: ${verification.verifiedAt!.toLocal().toString().split(' ')[0]}',
          'Verification: Independently validated against official regulatory registries.',
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user, size: 13, color: Colors.teal),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformVettedBadge(BuildContext context) {
    final label = isCompact ? 'Vetted' : 'Platform Vetted';

    return InkWell(
      onTap: () => _showCredentialInfoDialog(
        context,
        title: 'Platform-Vetted Expertise',
        icon: Icons.verified,
        color: Colors.blue,
        details: [
          'Type: Platform Editorial Review',
          if (verification.subjectId != null) 'Subject: ${verification.subjectId}',
          if (verification.verifiedAt != null)
            'Vetted Date: ${verification.verifiedAt!.toLocal().toString().split(' ')[0]}',
          'Verification: Curricular subject expertise reviewed and verified by platform educators.',
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 13, color: Colors.blue),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfDeclaredBadge(BuildContext context) {
    final label = isCompact ? 'Self-Declared' : 'Self-Declared Experience';

    return InkWell(
      onTap: () => _showCredentialInfoDialog(
        context,
        title: 'Self-Declared Contributor Experience',
        icon: Icons.info_outline,
        color: Colors.blueGrey,
        details: [
          'Type: Self-Declared Profile Claim',
          if (verification.issuer != null) 'Claimed Background: ${verification.issuer}',
          'Note: Stated directly by the contributor; not independently verified by platform staff or regulatory bodies.',
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 13, color: Colors.blueGrey),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCredentialInfoDialog(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<String> details,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Flexible(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: details.map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line, style: const TextStyle(fontSize: 13, height: 1.35)),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Renders contributor reputation badge indicating tier and score (ECO-04).
class EducatorReputationBadge extends StatelessWidget {
  final EducatorReputationTier tier;
  final double? score;
  final bool isCompact;

  const EducatorReputationBadge({
    super.key,
    required this.tier,
    this.score,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (tier) {
      EducatorReputationTier.masterContributor => (Icons.military_tech, Colors.amber.shade800),
      EducatorReputationTier.verifiedSpecialist => (Icons.stars, Colors.teal.shade700),
      EducatorReputationTier.activeContributor => (Icons.workspace_premium, Colors.indigo.shade600),
      EducatorReputationTier.newContributor => (Icons.person_outline, Colors.blueGrey),
    };

    final scoreText = score != null ? ' (${score!.toStringAsFixed(1)})' : '';
    final text = isCompact ? '${tier.displayName}$scoreText' : '${tier.displayName}$scoreText';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

