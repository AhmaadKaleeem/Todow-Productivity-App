const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String relativeDueLabel(DateTime? due, {DateTime? now}) {
  if (due == null) return '';
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final diff = dueDay.difference(today).inDays;

  if (diff < 0) return 'Overdue · ${_months[dueDay.month - 1]} ${dueDay.day}';
  if (diff == 0) {
    if (due.hour != 0 || due.minute != 0 || due.second != 0) {
      final h = due.hour % 12 == 0 ? 12 : due.hour % 12;
      final m = due.minute != 0 ? ':${due.minute.toString().padLeft(2, '0')}' : '';
      final ampm = due.hour >= 12 ? 'PM' : 'AM';
      return 'Today · $h$m $ampm';
    }
    return 'Today';
  }
  if (diff == 1) {
    if (due.hour != 0 || due.minute != 0 || due.second != 0) {
      final h = due.hour % 12 == 0 ? 12 : due.hour % 12;
      final m = due.minute != 0 ? ':${due.minute.toString().padLeft(2, '0')}' : '';
      final ampm = due.hour >= 12 ? 'PM' : 'AM';
      return 'Tomorrow · $h$m $ampm';
    }
    return 'Tomorrow';
  }
  if (diff == -1) return 'Yesterday';
  if (diff <= 7) return _weekdays[dueDay.weekday - 1];
  if (diff <= 365) return '${_months[dueDay.month - 1]} ${dueDay.day}';
  return '${_months[dueDay.month - 1]} ${dueDay.day}, ${dueDay.year}';
}
