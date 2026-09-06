import 'package:intl/intl.dart';

/// "Saturday, 29 August 2026"
String formatFullDate(DateTime date) =>
    DateFormat('EEEE, d MMMM yyyy').format(date);

/// A time-of-day greeting.
///
/// It takes [now] as a parameter instead of calling DateTime.now() inside,
/// which makes it a pure function — easy to unit test later.
String greetingForTime(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}
