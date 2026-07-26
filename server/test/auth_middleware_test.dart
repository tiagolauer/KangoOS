import 'package:kangoos_server/src/auth_middleware.dart';
import 'package:test/test.dart';

void main() {
  group('constantTimeEquals', () {
    test('equal strings match', () {
      expect(constantTimeEquals('Bearer abc123', 'Bearer abc123'), isTrue);
    });

    test('different strings of the same length do not match', () {
      expect(constantTimeEquals('Bearer abc123', 'Bearer abc124'), isFalse);
    });

    test('different lengths do not match', () {
      expect(constantTimeEquals('Bearer abc', 'Bearer abc123'), isFalse);
      expect(constantTimeEquals('Bearer abc123', 'Bearer abc'), isFalse);
    });

    test('empty inputs', () {
      expect(constantTimeEquals('', ''), isTrue);
      expect(constantTimeEquals('a', ''), isFalse);
      expect(constantTimeEquals('', 'a'), isFalse);
    });
  });
}
