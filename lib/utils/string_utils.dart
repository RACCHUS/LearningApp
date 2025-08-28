/// String utility functions for the Learning PWA
/// 
/// Provides common string operations, validations, and formatting
/// used throughout the application.
class StringUtils {
  /// Capitalize the first letter of a string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Capitalize the first letter of each word
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map(capitalize).join(' ');
  }

  /// Truncate string to specified length with ellipsis
  static String truncate(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - suffix.length) + suffix;
  }

  /// Remove extra whitespace and normalize spacing
  static String normalizeWhitespace(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Check if string is null, empty, or only whitespace
  static bool isNullOrEmpty(String? text) {
    return text == null || text.trim().isEmpty;
  }

  /// Check if string contains only alphanumeric characters
  static bool isAlphanumeric(String text) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text);
  }

  /// Check if string is a valid email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// Extract initials from a name (first letter of each word)
  static String getInitials(String name, {int maxInitials = 2}) {
    if (name.isEmpty) return '';
    
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .take(maxInitials)
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .where((initial) => initial.isNotEmpty)
        .join();
    
    return initials;
  }

  /// Generate a URL-friendly slug from text
  static String createSlug(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), '-') // Replace spaces with hyphens
        .replaceAll(RegExp(r'-+'), '-') // Replace multiple hyphens with single
        .replaceAll(RegExp(r'^-|-$'), ''); // Remove leading/trailing hyphens
  }

  /// Count words in a string
  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Estimate reading time in minutes (average 200 words per minute)
  static int estimateReadingTime(String text, {int wordsPerMinute = 200}) {
    final wordCount = countWords(text);
    return (wordCount / wordsPerMinute).ceil();
  }

  /// Remove HTML tags from string
  static String stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// Convert string to camelCase
  static String toCamelCase(String text) {
    if (text.isEmpty) return text;
    
    final words = text.toLowerCase().split(RegExp(r'[\s_-]+'));
    if (words.isEmpty) return text;
    
    final first = words.first;
    final rest = words.skip(1).map(capitalize).join();
    return first + rest;
  }

  /// Convert string to snake_case
  static String toSnakeCase(String text) {
    return text
        .replaceAll(RegExp(r'([a-z])([A-Z])'), r'$1_$2') // camelCase to snake
        .replaceAll(RegExp(r'[\s-]+'), '_') // spaces/hyphens to underscores
        .toLowerCase();
  }

  /// Extract hashtags from text
  static List<String> extractHashtags(String text) {
    final regex = RegExp(r'#([a-zA-Z0-9_]+)');
    return regex
        .allMatches(text)
        .map((match) => match.group(1)!)
        .toList();
  }

  /// Extract mentions (@username) from text
  static List<String> extractMentions(String text) {
    final regex = RegExp(r'@([a-zA-Z0-9_]+)');
    return regex
        .allMatches(text)
        .map((match) => match.group(1)!)
        .toList();
  }

  /// Highlight search terms in text
  static String highlightSearchTerms(String text, String searchTerm, 
      {String openTag = '<mark>', String closeTag = '</mark>'}) {
    if (searchTerm.isEmpty) return text;
    
    final regex = RegExp(RegExp.escape(searchTerm), caseSensitive: false);
    return text.replaceAll(regex, '$openTag$searchTerm$closeTag');
  }

  /// Calculate Levenshtein distance between two strings
  static int levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  /// Calculate string similarity (0.0 to 1.0)
  static double calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    
    final maxLength = a.length > b.length ? a.length : b.length;
    if (maxLength == 0) return 1.0;
    
    final distance = levenshteinDistance(a, b);
    return 1.0 - (distance / maxLength);
  }

  /// Generate random string with specified length
  static String generateRandomString(int length, {bool includeNumbers = true}) {
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    
    final chars = includeNumbers ? letters + numbers : letters;
    final random = DateTime.now().millisecondsSinceEpoch;
    
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (i) => chars.codeUnitAt((random + i) % chars.length),
      ),
    );
  }

  /// Validate password strength
  static Map<String, dynamic> validatePasswordStrength(String password) {
    final result = <String, dynamic>{
      'score': 0,
      'strength': 'Very Weak',
      'suggestions': <String>[],
    };

    final suggestions = result['suggestions'] as List<String>;
    int score = result['score'] as int;

    if (password.length < 8) {
      suggestions.add('Use at least 8 characters');
    } else {
      score += 1;
    }

    if (RegExp(r'[a-z]').hasMatch(password)) {
      score += 1;
    } else {
      suggestions.add('Include lowercase letters');
    }

    if (RegExp(r'[A-Z]').hasMatch(password)) {
      score += 1;
    } else {
      suggestions.add('Include uppercase letters');
    }

    if (RegExp(r'[0-9]').hasMatch(password)) {
      score += 1;
    } else {
      suggestions.add('Include numbers');
    }

    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      score += 1;
    } else {
      suggestions.add('Include special characters');
    }

    // Update result with final score
    result['score'] = score;

    // Determine strength
    switch (score) {
      case 0:
      case 1:
        result['strength'] = 'Very Weak';
        break;
      case 2:
        result['strength'] = 'Weak';
        break;
      case 3:
        result['strength'] = 'Fair';
        break;
      case 4:
        result['strength'] = 'Good';
        break;
      case 5:
        result['strength'] = 'Strong';
        break;
    }

    return result;
  }
}
