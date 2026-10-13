import 'package:flutter/material.dart';

import 'logger.dart';
import 'tokens.dart';

/// Категория услуги. Незнакомое значение с сервера становится [other]
/// и рисуется нейтрально, а не роняет иконку и не красит в случайный цвет.
///
/// Раньше `cat` был свободной строкой: неизвестное значение молча давало
/// серый градиент 'city' и иконку receipt_long, и отличить «город» от
/// «бэкенд прислал новую категорию» было нельзя.
enum ServiceCat {
  water,
  power,
  trash,
  kid,
  school,
  gas,
  net,
  door,
  course,
  tax,
  mobile,
  paid,
  market,
  city,
  other;

  /// Разбор значения из API. null и незнакомое → [other], с записью в Log.
  static ServiceCat parse(String? raw) {
    final key = raw?.trim().toLowerCase() ?? '';
    if (key.isEmpty) return other;
    for (final c in values) {
      if (c != other && c.name == key) return c;
    }
    Log.w('cat', 'незнакомая категория «$raw» → other');
    return other;
  }

  /// Значение для отправки на сервер и для ключа кэша.
  String get wire => name;

  /// Ключ для Brand.category и Brand.gradient (для [other] — 'city').
  String get token => this == other ? 'city' : name;

  bool get isKnown => this != other;
}

/// Иконка категории. Переехала сюда из features/bills/bill_row.dart,
/// где её легко не найти и продублировать.
IconData iconOf(ServiceCat cat) => switch (cat) {
      ServiceCat.water => Icons.water_drop_outlined,
      ServiceCat.power => Icons.bolt_rounded,
      ServiceCat.trash => Icons.delete_outline_rounded,
      ServiceCat.gas => Icons.local_fire_department_outlined,
      ServiceCat.net => Icons.wifi_rounded,
      ServiceCat.door => Icons.sensor_door_outlined,
      ServiceCat.mobile => Icons.smartphone_rounded,
      ServiceCat.kid => Icons.child_care_rounded,
      ServiceCat.school => Icons.school_outlined,
      ServiceCat.course => Icons.menu_book_rounded,
      ServiceCat.tax => Icons.account_balance_outlined,
      ServiceCat.market => Icons.confirmation_number_outlined,
      ServiceCat.paid => Icons.receipt_long_outlined,
      ServiceCat.city => Icons.receipt_long_outlined,
      ServiceCat.other => Icons.receipt_long_outlined,
    };

/// Градиент категории из Brand.category.
LinearGradient gradientOf(ServiceCat cat) => Brand.gradient(cat.token);

/// Цвета категории [начало, конец] — когда нужен не градиент, а оттенок.
List<Color> colorsOf(ServiceCat cat) =>
    Brand.category[cat.token] ?? Brand.category['city']!;

/// Иконка по сырой строке — мост для экранов, которые ещё держат `String cat`.
/// Новый код берёт [iconOf] и [ServiceCat], а эта обёртка уйдёт вместе
/// с последним строковым `cat` в моделях.
IconData iconOfRaw(String? raw) => iconOf(ServiceCat.parse(raw));
