import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/utils/uuid_validator.dart';

void main() {
  group('UUID Validator Tests', () {
    test('identifies standard RFC 4122 UUID v4 strings as valid', () {
      expect(isValidUuid('123e4567-e89b-12d3-a456-426614174000'), isTrue);
      expect(isValidUuid('c8d4e94f-1729-4592-88ec-6946890373e9'), isTrue);
      expect(isValidUuid('C8D4E94F-1729-4592-88EC-6946890373E9'), isTrue);
    });

    test('rejects non-UUID slugs and keywords', () {
      expect(isValidUuid(null), isFalse);
      expect(isValidUuid(''), isFalse);
      expect(isValidUuid('local-user'), isFalse);
      expect(isValidUuid('guest'), isFalse);
      expect(isValidUuid('anonymous'), isFalse);
      expect(isValidUuid('foundational-literacy'), isFalse);
      expect(isValidUuid('course-123'), isFalse);
      expect(isValidUuid('12345'), isFalse);
    });

    test('rejects invalid length or malformed hyphen placements', () {
      expect(isValidUuid('123e4567-e89b-12d3-a456-42661417400'), isFalse); // 35 chars
      expect(isValidUuid('123e4567-e89b-12d3-a456-4266141740000'), isFalse); // 37 chars
      expect(isValidUuid('123e4567e89b12d3a456426614174000'), isFalse); // no hyphens
      expect(isValidUuid('123e4567-e89b-12d3-a456_426614174000'), isFalse); // underscore
      expect(isValidUuid('g23e4567-e89b-12d3-a456-426614174000'), isFalse); // non-hex 'g'
    });
  });
}
