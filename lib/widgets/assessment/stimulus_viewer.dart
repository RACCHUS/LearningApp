import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/assessment_stimulus.dart';

class StimulusViewer extends StatefulWidget {
  final AssessmentStimulus stimulus;
  final bool initiallyExpanded;

  const StimulusViewer({
    super.key,
    required this.stimulus,
    this.initiallyExpanded = true,
  });

  @override
  State<StimulusViewer> createState() => _StimulusViewerState();
}

class _StimulusViewerState extends State<StimulusViewer> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stim = widget.stimulus;

    final typeInfo = _getTypeInfo(stim.stimulusType);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: typeInfo.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(typeInfo.icon, size: 18, color: typeInfo.color),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeInfo.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeInfo.label,
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: typeInfo.color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stim.title.isNotEmpty ? stim.title : 'Exhibit Reference',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded Content Body
            if (_expanded)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stim.body != null && stim.body!.isNotEmpty) ...[
                      Text(
                        stim.body!,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          height: 1.55,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    // Structured Data Table / Key-Values (e.g. Clinical Vitals / Log Entries)
                    if (stim.structuredData.isNotEmpty) ...[
                      _buildStructuredDataView(context, stim.structuredData, isDark),
                      const SizedBox(height: 12),
                    ],
                    // Asset references (diagrams / images)
                    if (stim.assetRefs.isNotEmpty) ...[
                      _buildAssetRefsView(context, stim.assetRefs, isDark),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredDataView(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.dataset_rounded, size: 14, color: Color(0xFF3B82F6)),
                const SizedBox(width: 6),
                Text(
                  'EXHIBIT DATA',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
          ...data.entries.map((entry) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      entry.key.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAssetRefsView(
    BuildContext context,
    List<dynamic> assetRefs,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: assetRefs.map((asset) {
        final url = asset is Map ? (asset['url'] ?? asset['src'] ?? '') : asset.toString();
        if (url.isEmpty) return const SizedBox.shrink();
        final isNetwork = url.startsWith('http://') || url.startsWith('https://');

        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: isNetwork
                ? Image.network(url, fit: BoxFit.contain)
                : Image.asset(url, fit: BoxFit.contain),
          ),
        );
      }).toList(),
    );
  }

  _StimulusTypeInfo _getTypeInfo(AssessmentStimulusType type) {
    switch (type) {
      case AssessmentStimulusType.clinicalCase:
        return const _StimulusTypeInfo(
          label: 'CLINICAL CASE',
          icon: Icons.local_hospital_rounded,
          color: Color(0xFFEF4444), // Rose
        );
      case AssessmentStimulusType.architectureDiagram:
        return const _StimulusTypeInfo(
          label: 'ARCHITECTURE',
          icon: Icons.hub_rounded,
          color: Color(0xFF0284C7), // Sky Blue
        );
      case AssessmentStimulusType.codeSnippet:
        return const _StimulusTypeInfo(
          label: 'CODE EXHIBIT',
          icon: Icons.code_rounded,
          color: Color(0xFF10B981), // Emerald
        );
      case AssessmentStimulusType.dataTable:
        return const _StimulusTypeInfo(
          label: 'DATA TABLE',
          icon: Icons.table_view_rounded,
          color: Color(0xFFF59E0B), // Amber
        );
      case AssessmentStimulusType.scenario:
        return const _StimulusTypeInfo(
          label: 'SCENARIO',
          icon: Icons.assignment_rounded,
          color: Color(0xFF6366F1), // Indigo
        );
      case AssessmentStimulusType.passage:
        return const _StimulusTypeInfo(
          label: 'PASSAGE',
          icon: Icons.article_rounded,
          color: Color(0xFF8B5CF6), // Purple
        );
    }
  }
}

class _StimulusTypeInfo {
  final String label;
  final IconData icon;
  final Color color;

  const _StimulusTypeInfo({
    required this.label,
    required this.icon,
    required this.color,
  });
}
