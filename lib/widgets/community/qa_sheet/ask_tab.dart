part of '../in_context_qa_sheet.dart';

// "Ask" tab: the question composer.
// Moved unchanged from in_context_qa_sheet.dart (code-efficiency plan
// §14, Phase 2); setState calls go through the sheet's _update helper
// because extensions may not call the protected setState directly.
extension _QaAskTab on InContextQaSheetState {
  Widget _buildAskTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask a Question about this Topic',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Your question will be saved privately and reviewed by educators. It will not be posted publicly during Phase 1.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Question Title',
                hintText: 'e.g., How does blending consonant sounds work?',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 5) {
                  return 'Title must be at least 5 characters';
                }
                if (v.trim().length > 200) {
                  return 'Title must not exceed 200 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Details / Context',
                hintText: 'Describe what you find confusing or what you are trying to understand...',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 10) {
                  return 'Details must be at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitDraftQuestion,
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: const Text('Save Private Question'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
