import 'package:flutter/material.dart';

import '../../core/l10n/s.dart';
import '../../core/service_cat.dart';
import '../../data/models.dart';

/// Иконка категории услуги.
///
/// Тонкая обёртка над [iconOf]: сам switch по категориям переехал в
/// core/service_cat.dart, где рядом лежат градиент и разбор значения
/// с сервера. Обёртка оставлена, чтобы не править десятки мест вызова
/// разом — она уйдёт вместе с последним строковым `cat` в моделях.
IconData catIcon(String cat) => iconOfRaw(cat);

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
