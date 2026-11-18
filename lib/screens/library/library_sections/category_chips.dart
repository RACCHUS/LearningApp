part of '../library_screen.dart';

// Destination category chips and the Source picker.
// Moved unchanged from LibraryScreen.build (code-efficiency plan §14,
// Phase 2): the 804-line build now computes the results once and hands
// each section exactly the values it reads.
extension _LibraryCategoryChips on _LibraryScreenState {
  Widget _categoryChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            key: const Key('library-filter-all'),
            label: const Text('All Destinations'),
            selected: _selectedCategory == null,
            onSelected: (selected) {
              if (selected) _update(() => _selectedCategory = null);
            },
          ),
          const SizedBox(width: DesignTokens.space2),
          FilterChip(
            key: const Key('library-filter-careers'),
            avatar: const Text('💼'),
            label: const Text('Careers'),
            selected: _selectedCategory == 'career',
            onSelected: (selected) {
              _update(() => _selectedCategory = selected ? 'career' : null);
            },
          ),
          const SizedBox(width: DesignTokens.space2),
          FilterChip(
            key: const Key('library-filter-certs'),
            avatar: const Text('📜'),
            label: const Text('Certifications'),
            selected: _selectedCategory == 'certification',
            onSelected: (selected) {
              _update(() => _selectedCategory = selected ? 'certification' : null);
            },
          ),
          const SizedBox(width: DesignTokens.space2),
          FilterChip(
            key: const Key('library-filter-exams'),
            avatar: const Text('📝'),
            label: const Text('Exams'),
            selected: _selectedCategory == 'exam' || _selectedCategory == 'standardized_exam',
            onSelected: (selected) {
              _update(() => _selectedCategory = selected ? 'exam' : null);
            },
          ),
          const SizedBox(width: DesignTokens.space2),
          FilterChip(
            key: const Key('library-filter-academics'),
            avatar: const Text('🎓'),
            label: const Text('Academic Programs'),
            selected: _selectedCategory == 'academic_program',
            onSelected: (selected) {
              _update(() => _selectedCategory = selected ? 'academic_program' : null);
            },
          ),
          const SizedBox(width: DesignTokens.space2),
          FilterChip(
            key: const Key('library-filter-standards'),
            avatar: const Text('📋'),
            label: const Text('Curriculum Standards'),
            selected: _selectedCategory == 'curriculum_standard',
            onSelected: (selected) {
              _update(() => _selectedCategory = selected ? 'curriculum_standard' : null);
            },
          ),
          const SizedBox(width: DesignTokens.space2),
          FilterChip(
            key: const Key('library-filter-courses'),
            avatar: const Text('📚'),
            label: const Text('Courses & Lessons'),
            selected: _selectedCategory == 'course',
            onSelected: (selected) {
              _update(() => _selectedCategory = selected ? 'course' : null);
            },
          ),
          const SizedBox(width: DesignTokens.space2),
          FilterChip(
            key: const Key('library-filter-milestones'),
            avatar: const Text('🏛️'),
            label: const Text('Life Milestones & Literacy'),
            selected: _selectedCategory == 'milestones',
            onSelected: (selected) {
              _update(() => _selectedCategory = selected ? 'milestones' : null);
            },
          ),
        ],
      ),
    );
  }
}
