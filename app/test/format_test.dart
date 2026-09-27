import 'package:elpay/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Формат сумм', () {
    test('целые — без копеек, дробные — с копейками', () {
      expect(som(180), '180');
      expect(som(3500), '3 500');
      expect(som(4449.44), '4 449,44');
    });
  });

  group('Плюрализация', () {
    test('русские формы', () {
      expect(plural(1, 'счёт', 'счёта', 'счетов'), 'счёт');
      expect(plural(2, 'счёт', 'счёта', 'счетов'), 'счёта');
      expect(plural(5, 'счёт', 'счёта', 'счетов'), 'счетов');
      expect(plural(11, 'счёт', 'счёта', 'счетов'), 'счетов');
      expect(plural(21, 'счёт', 'счёта', 'счетов'), 'счёт');
    });
  });

  group('Телефон', () {
    test('маска по девяти цифрам', () {
      expect(phoneMask('555123456'), '555 12 34 56');
      expect(phoneMask('5551'), '555 1');
    });
  });

  group('Почта', () {
    test('простая проверка адреса', () {
      expect(isValidEmail('name@example.com'), isTrue);
      expect(isValidEmail('name@example'), isFalse);
      expect(isValidEmail('без собаки'), isFalse);
    });
  });

  group('Даты', () {
    final d = DateTime(2026, 10, 5);
    test('человеческие форматы', () {
      expect(longDate(d), '5 октября 2026');
      expect(shortDue(d), 'до 5 окт');
      expect(monthTitle(d), 'Октябрь 2026');
      expect(dayMonth(d), '5 окт');
      expect(hhmm(DateTime(2026, 10, 5, 9, 7)), '09:07');
    });
  });
}
