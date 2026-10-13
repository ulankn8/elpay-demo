import 'package:elpay/data/models.dart';

import 'env.dart';

/// Короткие сборщики моделей для тестов.
///
/// У `AccountCandidate` одиннадцать обязательных полей, и без сборщика
/// каждый тест начинался бы с двадцати строк, из которых к делу относятся
/// две. Здесь у всего есть разумное значение по умолчанию, а тест называет
/// РОВНО то, что проверяет.
///
/// Значения совпадают с демо-реестром (`Registry`) и каталогом (`Demo`),
/// поэтому фикстуры и демо-данные не расходятся.

/// Адрес семьи — тот же, что у объекта «Дом».
const homeAddress = 'Ош, ул. Курманжан Датка, д. 212, кв. 14';

/// Адрес родителей — тот же, что у объекта «Родители».
const parentsAddress = 'Ош, ул. Масалиева, д. 44, кв. 12';

/// Объект «Дом».
const homeObject = PayObject(
  id: 'o1',
  name: 'Дом',
  icon: 'house',
  cat: 'water',
  address: 'Ош, ул. Курманжан Датка, 212',
);

/// Объект «Родители».
const parentsObject = PayObject(
  id: 'o2',
  name: 'Родители',
  icon: 'users',
  cat: 'door',
  address: 'Ош, ул. Масалиева, 44',
);

/// Найденный в реестре счёт.
AccountCandidate candidate({
  required String id,
  required String accountNo,
  String providerId = 'p-water',
  String providerTitle = 'Ошводоканал',
  String serviceTitle = 'Холодная вода',
  String cat = 'water',
  String holder = 'Токтогулова А.',
  String address = homeAddress,
  double amount = 205,
  String period = 'март 2026',
  int dueDay = 20,
  List<Field> calc = const [],
  bool needsConfirm = false,
  bool alreadyConnected = false,
}) =>
    AccountCandidate(
      id: id,
      providerId: providerId,
      providerTitle: providerTitle,
      serviceTitle: serviceTitle,
      cat: cat,
      accountNo: accountNo,
      holder: holder,
      address: address,
      amount: amount,
      period: period,
      dueDay: dueDay,
      calc: calc,
      needsConfirm: needsConfirm,
      alreadyConnected: alreadyConnected,
    );

/// Подключённый счёт.
ConnectedAccount account({
  required String id,
  required String accountNo,
  String providerId = 'p-water',
  String title = 'Ошводоканал',
  String subtitle = 'Холодная вода',
  String cat = 'water',
  String objectId = 'o1',
  String holder = 'Токтогулова А.',
  String address = homeAddress,
  DateTime? connectedAt,
  int dueDay = 20,
  AccountSyncStatus status = AccountSyncStatus.ok,
  AccountOp? pendingOp,
  DateTime? syncedAt,
  String? lastError,
}) =>
    ConnectedAccount(
      id: id,
      providerId: providerId,
      title: title,
      subtitle: subtitle,
      cat: cat,
      accountNo: accountNo,
      objectId: objectId,
      holder: holder,
      address: address,
      connectedAt: connectedAt ?? testNow.subtract(const Duration(days: 40)),
      dueDay: dueDay,
      status: status,
      pendingOp: pendingOp,
      syncedAt: syncedAt,
      lastError: lastError,
    );

/// Начисление.
Bill charge({
  required String id,
  double amount = 205,
  String accountId = '',
  String account = '31-00562',
  String objectId = 'o1',
  String title = 'Ошводоканал',
  String subtitle = 'Холодная вода',
  String cat = 'water',
  String period = 'март 2026',
  DateTime? due,
  bool paid = false,
  bool autopay = false,
}) =>
    Bill(
      id: id,
      title: title,
      subtitle: subtitle,
      cat: cat,
      amount: amount,
      objectId: objectId,
      period: period,
      due: due ?? DateTime(testNow.year, testNow.month, 20),
      account: account,
      accountId: accountId,
      paid: paid,
      autopay: autopay,
    );

/// Пользователь: нужен правилам, чтобы отличить свой счёт от чужого.
const testSession = Session(
  id: 'u1',
  name: 'Токтогулова Айнура',
  phone: '555123456',
  method: AuthMethod.phone,
  address: 'Ош, ул. Курманжан Датка, 212',
);
