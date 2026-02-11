import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  String get formattedDate => DateFormat('dd/MM/yyyy').format(this);

  String get formattedTime => DateFormat('HH:mm').format(this);

  String get formattedDateTime => DateFormat('dd/MM/yyyy HH:mm').format(this);

  String get formattedShort => DateFormat('dd/MM').format(this);

  String get dayOfWeekName => DateFormat('EEEE', 'pt_BR').format(this);

  String get monthName => DateFormat('MMMM', 'pt_BR').format(this);

  String timeAgo() {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) return 'Agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atras';
    if (diff.inHours < 24) return '${diff.inHours}h atras';
    if (diff.inDays < 7) return '${diff.inDays}d atras';
    return formattedDate;
  }

  String countdown() {
    final now = DateTime.now();
    final diff = difference(now);

    if (diff.isNegative) return 'Expirado';
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}min';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min';
    return '${diff.inSeconds}s';
  }

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }
}
