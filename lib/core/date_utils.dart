/// Parses a timestamp sent by the backend (C8).
///
/// The backend stores and serializes naive UTC datetimes (ISO strings without `Z` / offset),
/// so a value without an explicit offset is treated as UTC. Values that carry `Z` or an offset
/// keep their instant. The result is converted to device local time for display/day logic.
/// A date-only value (`2026-10-22`) is a calendar date and is returned as local midnight.
/// Returns null for null, empty or unparseable input.
DateTime? parseServerDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;

  // Date-only values have no time component and no timezone to convert
  final hasTime = raw.contains('T') || raw.contains('t') || raw.contains(' ');
  if (!hasTime) return parsed;

  if (parsed.isUtc) return parsed.toLocal();

  // No offset in the string: DateTime.tryParse read it as local time, but it is UTC
  final asUtc = DateTime.tryParse('${raw}Z');
  if (asUtc != null && asUtc.isUtc) return asUtc.toLocal();
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  ).toLocal();
}
