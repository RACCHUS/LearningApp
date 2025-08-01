import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/components/home/search_bar.dart';

class HeroSection extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  const HeroSection({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primaryColor.withOpacity(0.1),
              theme.scaffoldBackgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start Learning',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover new lessons and expand your knowledge',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            HomeSearchBar(
              controller: searchController,
              searchQuery: searchQuery,
              onChanged: onSearchChanged,
              onClear: onClearSearch,
            ),
          ],
        ),
      ),
    );
  }
}
