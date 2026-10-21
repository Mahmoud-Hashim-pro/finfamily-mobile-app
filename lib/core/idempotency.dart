import 'dart:math';

/// Generates a cryptographically random, collision-resistant idempotency key (FF-12).
String generateIdempotencyKey([String prefix = 'req']) {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '$prefix-$timestamp-$hex';
}
