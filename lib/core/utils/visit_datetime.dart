/// Formatea una fecha al estilo `dd/MM/aaaa HH:mm`, el que ya usa la pantalla
/// de autorizaciones, para que las vistas de QR no se contradigan.
String formatVisitDateTime(DateTime? value) {
  if (value == null) return '—';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}

/// Formatea una hora corta `HH:mm:ss` o `HH:mm`, para la cuenta regresiva.
String formatClock(int totalSeconds) {
  final safe = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = (safe ~/ 3600).toString().padLeft(2, '0');
  final minutes = ((safe % 3600) ~/ 60).toString().padLeft(2, '0');
  final seconds = (safe % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

/// Resumen corto de una duración: `3 h 20 min`, `12 min`, `45 s`.
String formatDuration(int totalSeconds) {
  if (totalSeconds <= 0) return 'vencido';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return minutes > 0 ? '$hours h $minutes min' : '$hours h';
  }
  if (minutes > 0) {
    return seconds > 0 && minutes < 5
        ? '$minutes min $seconds s'
        : '$minutes min';
  }
  return '$seconds s';
}
