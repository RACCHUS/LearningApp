import 'package:flutter/material.dart';

/// Career path completion certificate widget
class CareerCertificate extends StatelessWidget {
  final String careerPathTitle;
  final String userName;
  final DateTime completedAt;
  final int coursesCompleted;
  final int skillsAcquired;
  final String? certificateId;

  const CareerCertificate({
    super.key,
    required this.careerPathTitle,
    required this.userName,
    required this.completedAt,
    required this.coursesCompleted,
    required this.skillsAcquired,
    this.certificateId,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Certificate of completion for $careerPathTitle, awarded to '
          '$userName${certificateId != null ? ', certificate ID $certificateId' : ''}.',
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37), // Gold border
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with decorative pattern
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  color: Color(0xFFD4AF37),
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  'CERTIFICATE OF COMPLETION',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),

          // Certificate body
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Text(
                  'This is to certify that',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),

                // User name
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'has successfully completed the',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),

                // Career path title
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    careerPathTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A237E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Career Path',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),

                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatItem(
                      icon: Icons.school,
                      value: '$coursesCompleted',
                      label: 'Courses',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    _StatItem(
                      icon: Icons.psychology,
                      value: '$skillsAcquired',
                      label: 'Skills',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Completed on ${_formatDate(completedAt)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),

                // Certificate ID
                if (certificateId != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Certificate ID: $certificateId',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Footer with seal
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(13)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4AF37),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Color(0xFFD4AF37),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Learning App',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Verified Achievement',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF1A237E), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// Compact certificate card for lists
class CertificateCard extends StatelessWidget {
  final String careerPathTitle;
  final DateTime completedAt;
  final VoidCallback? onTap;

  const CertificateCard({
    super.key,
    required this.careerPathTitle,
    required this.completedAt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Color(0xFFD4AF37),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      careerPathTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Completed ${_formatShortDate(completedAt)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatShortDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

/// Full screen certificate viewer
class CertificateViewerScreen extends StatelessWidget {
  final String careerPathTitle;
  final String userName;
  final DateTime completedAt;
  final int coursesCompleted;
  final int skillsAcquired;
  final String? certificateId;

  const CertificateViewerScreen({
    super.key,
    required this.careerPathTitle,
    required this.userName,
    required this.completedAt,
    required this.coursesCompleted,
    required this.skillsAcquired,
    this.certificateId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text('Certificate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing coming soon!')),
              );
            },
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download coming soon!')),
              );
            },
            tooltip: 'Download',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: CareerCertificate(
              careerPathTitle: careerPathTitle,
              userName: userName,
              completedAt: completedAt,
              coursesCompleted: coursesCompleted,
              skillsAcquired: skillsAcquired,
              certificateId: certificateId,
            ),
          ),
        ),
      ),
    );
  }
}
