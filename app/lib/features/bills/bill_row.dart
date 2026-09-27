import 'package:flutter/material.dart';

import '../../core/l10n/s.dart';
import '../../data/models.dart';

/// Иконка категории услуги.
IconData catIcon(String cat) => switch (cat) {
      'water' => Icons.water_drop_outlined,
      'power' => Icons.bolt_rounded,
      'trash' => Icons.delete_outline_rounded,
      'gas' => Icons.local_fire_department_outlined,
      'net' => Icons.wifi_rounded,
      'door' => Icons.sensor_door_outlined,
      'mobile' => Icons.smartphone_rounded,
      'kid' => Icons.child_care_rounded,
      'school' => Icons.school_outlined,
      'course' => Icons.menu_book_rounded,
      'tax' => Icons.account_balance_outlined,
      'market' => Icons.confirmation_number_outlined,
      _ => Icons.receipt_long_outlined,
    };

/// Человеческий срок: «просрочено на 2 дня», «осталось 3 дня», «до 25 сент».
({String text, bool overdue, bool soon}) dueLabel(BuildContext context, Bill b) {
  final s = S.of(context);
  final left = b.daysLeft(DateTime.now());
  if (left < 0) {
    final n = -left;
    return (text: '${s.overdue} · $n ${s.daysWord(n)}', overdue: true, soon: false);
  }
  if (left == 0) return (text: s.dueToday, overdue: false, soon: true);
  if (left <= 3) return (text: s.dueInDays(left), overdue: false, soon: true);
  return (text: s.shortDueText(b.due), overdue: false, soon: false);
}
