/// Formats a duration in milliseconds as `m:ss` for Spanish UI labels.
String formatDurationMs(int ms) {
  final safeMs = ms < 0 ? 0 : ms;
  final totalSeconds = safeMs ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
