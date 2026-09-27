import 'package:flutter/widgets.dart';

import '../format.dart';

/// Строки приложения. Два языка: русский и кыргызский.
/// Типизированно — без кодогенерации, чтобы перевод нельзя было забыть:
/// новая строка не скомпилируется, пока не появится в обоих классах.
abstract class S {
  static S of(BuildContext context) => Localizations.of<S>(context, S)!;
  static const delegate = _SDelegate();

  String get langName;

  // Общее
  String get appName;
  String get byElbagar;
  String get cont;
  String get cancel;
  String get save;
  String get ready;
  String get back;
  String get close;
  String get details;
  String get pay;
  String get payAll;
  String get selected;
  String get selectAll;
  String get unselectAll;
  String get total;
  String get som;
  String get skip;

  // Приветствие и вход
  String get welcomeTitle1;
  String get welcomeTitle2;
  String get welcomeLead;
  String get start;
  String get haveAccount;
  String get loginTitle;
  String get loginLead;
  String get byPhone;
  String get byEmail;
  String get byTelegram;
  String get phoneLabel;
  String get phoneHint;
  String get emailLabel;
  String get emailHint;
  String get getCode;
  String get telegramLead;
  String get openTelegram;
  String get telegramWait;
  String get telegramDone;
  String get phoneError;
  String get emailError;
  String get agreement;

  // Код
  String get otpTitle;
  String otpSentPhone(String to);
  String otpSentEmail(String to);
  String get otpChange;
  String get otpDemo;
  String get otpPaste;
  String otpResendIn(String time);
  String get otpResend;
  String get otpChecking;
  String get otpWrong;
  String get otpOk;

  // Знакомство
  String get setupTitle;
  String get setupLead;
  String get nameLabel;
  String get nameHint;
  String get addressLabel;
  String get addressHint;
  String get cityLabel;
  String get finish;

  // Вкладки
  String get tabHome;
  String get tabPayments;
  String get tabReports;
  String get tabProfile;

  // Главная
  String hello(String name);
  String get toPay;
  String get billsWord;
  String billsCount(int n);
  String paidOf(int paid, int all);
  String get allPaid;
  String get newPayment;
  String get noBillsTitle;
  String get noBillsLead;
  String get soonHere;

  // Счета и детали
  String get billsTitle;
  String get period;
  String get dueDate;
  String get account;
  String get object;
  String get howCharged;
  String get requisites;
  String get requisitesHint;
  String get payments;
  String get recipient;
  String get inn;
  String get bank;
  String get bik;
  String get settlementAccount;
  String get purpose;
  String get copied;
  String get overdue;
  String dueInDays(int n);
  String get dueToday;

  // Оплата
  String get checkoutTitle;
  String get checkoutOne;
  String get whatFor;
  String get payMethod;
  String get walletBalance;
  String get paidTitle;
  String get paidLead;
  String get done;
  String get shareReceipts;
  String get paymentsStub;

  // Профиль
  String get profileTitle;
  String get personal;
  String get security;
  String get appSection;
  String get theme;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get language;
  String get logout;
  String get logoutConfirm;
  String get version;

  // Платежи, история, отчёты, профиль
  String get paymentsTitle;
  String get walletTitle;
  String get topUp;
  String get topUpTitle;
  String get topUpDone;
  String get newPaymentLead;
  String get qrPay;
  String get qrPayLead;
  String get catalogTitle;
  String get methodsTitle;
  String get addCard;
  String get historyTitle;
  String get historyLead;
  String get autopayTitle;
  String get autopayLead;
  String get autopayOn;
  String get autopayOff;
  String get chooseProvider;
  String get searchHint;
  String get amountLabel;
  String get checkAccount;
  String get accountError;
  String get amountError;
  String get confirmTitle;
  String get qrLead;
  String get qrDemoBtn;
  String get qrFound;
  String get cameraStub;
  String get historyEmpty;
  String get receiptTitle;
  String get receiptNo;
  String get paidAt;
  String get methodLabel;
  String get share;
  String get savePdf;
  String get repeatPay;
  String get filterAll;
  String get nothingFound;
  String get reportsTitle;
  String get periodMonth;
  String get periodYear;
  String get spentTotal;
  String get byCategory;
  String get byObject;
  String get exportCsv;
  String get noDataPeriod;
  String paymentsCount(int n);
  String get vsPrevMore;
  String get vsPrevLess;
  String get personalData;
  String get personalLead;
  String get objectsTitle;
  String get objectsLead;
  String get accountsTitle;
  String get accountsLead;
  String get addressesTitle;
  String get addressesLead;
  String get familyTitle;
  String get familyLead;
  String get notifyTitle;
  String get notifyLead;
  String get securityTitle;
  String get securityLead;
  String get tariffsTitle;
  String get tariffsLead;
  String get supportTitle;
  String get supportLead;
  String get deleteAccount;
  String get pinTitle;
  String get pinLead;
  String get faceId;
  String get confirmBig;
  String get devicesTitle;
  String get logoutAll;
  String get thisDevice;
  String get notifyBills;
  String get notifyOutages;
  String get notifyMarket;
  String get quietHours;
  String get invite;
  String get canPay;
  String get canView;
  String get removeWord;
  String get editWord;
  String get addWord;
  String get nothingYet;
  String get soonWord;

  // Названия категорий
  String catName(String c);

  // Профиль: объекты, счета, семья, безопасность
  String get saved;
  String get nameFull;
  String get phoneChange;
  String get phoneChangeLead;
  String get objectName;
  String get objectAddressLabel;
  String get newObject;
  String get editObject;
  String get deleteObjectConfirm;
  String get addAccountTitle;
  String get accountNumber;
  String get chooseObject;
  String get deleteAccountConfirm;
  String get accountAdded;
  String get addressTitleLabel;
  String get newAddress;
  String get deleteAddressConfirm;
  String get inviteMember;
  String get memberName;
  String get memberPhone;
  String get memberRole;
  String get memberRights;
  String get removeMemberConfirm;
  String get inviteSent;
  String get pinOnMsg;
  String get pinOffMsg;
  String get pinEnter;
  String get pinRepeat;
  String get pinMismatch;
  String get devicesLead;
  String get logoutAllDone;
  String get revokeDevice;
  String get supportChat;
  String get supportCall;
  String get supportHours;
  String get deleteAccountLead;
  String get deleteAccountDone;
  String get tariffsNote;
  String get tariffsLead2;
  String get offer;
  String get myAccounts;
  String get objectBills;
  List<(String, String, String)> get tariffRows;

  // Счётчики в профиле
  String addressCount(int n);
  String membersCount(int n);
  String get sectionAccess;

  // Новая оплата
  String get newPaymentHint;

  // Разделы вкладки «Платежи»
  String get sectionHistoryAuto;

  // Безопасность
  String get confirmBigShort;
  String get confirmBigLead;
  String get pinFirst;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();
  @override
  bool isSupported(Locale locale) => ['ru', 'ky'].contains(locale.languageCode);
  @override
  Future<S> load(Locale locale) async =>
      locale.languageCode == 'ky' ? const SKy() : const SRu();
  @override
  bool shouldReload(_SDelegate old) => false;
}

class SRu implements S {
  const SRu();
  @override String get langName => 'Русский';
  @override String get appName => 'ЭлPay';
  @override String get byElbagar => 'продукт ELBAGAR';
  @override String get cont => 'Продолжить';
  @override String get cancel => 'Отмена';
  @override String get save => 'Сохранить';
  @override String get ready => 'Готово';
  @override String get back => 'Назад';
  @override String get close => 'Закрыть';
  @override String get details => 'Детали';
  @override String get pay => 'Оплатить';
  @override String get payAll => 'Оплатить всё';
  @override String get selected => 'Выбрано';
  @override String get selectAll => 'Выбрать все';
  @override String get unselectAll => 'Снять все';
  @override String get total => 'Итого';
  @override String get som => 'сом';
  @override String get skip => 'Пропустить';

  @override String get welcomeTitle1 => 'Все платежи семьи —';
  @override String get welcomeTitle2 => 'одним тапом';
  @override String get welcomeLead =>
      'Коммунальные счета, детский сад и школа — в одной ленте. Реквизиты вводятся один раз, а об отключениях воды и света ЭлPay предупреждает заранее.';
  @override String get start => 'Начать';
  @override String get haveAccount => 'У меня уже есть аккаунт';
  @override String get loginTitle => 'Вход в ЭлPay';
  @override String get loginLead => 'Выберите удобный способ — код придёт за пару секунд.';
  @override String get byPhone => 'Телефон';
  @override String get byEmail => 'Почта';
  @override String get byTelegram => 'Telegram';
  @override String get phoneLabel => 'Номер телефона';
  @override String get phoneHint => '555 12 34 56';
  @override String get emailLabel => 'Электронная почта';
  @override String get emailHint => 'name@example.com';
  @override String get getCode => 'Получить код';
  @override String get telegramLead =>
      'Откройте бота @elpay_bot и нажмите «Войти». Код придёт в чат — введите его на следующем шаге.';
  @override String get openTelegram => 'Открыть Telegram';
  @override String get telegramWait => 'Ждём подтверждения в Telegram…';
  @override String get telegramDone => 'Telegram подтвердил вход';
  @override String get phoneError => 'Нужно 9 цифр после +996';
  @override String get emailError => 'Проверьте адрес — например, name@example.com';
  @override String get agreement =>
      'Продолжая, вы соглашаетесь с офертой и политикой конфиденциальности';

  @override String get otpTitle => 'Введите код';
  @override String otpSentPhone(String to) => 'Отправили SMS на $to';
  @override String otpSentEmail(String to) => 'Отправили письмо на $to';
  @override String get otpChange => 'Изменить';
  @override String get otpDemo => 'Код в демо: 4815';
  @override String get otpPaste => 'Вставить';
  @override String otpResendIn(String time) => 'Отправить повторно через $time';
  @override String get otpResend => 'Отправить код ещё раз';
  @override String get otpChecking => 'Проверяем код…';
  @override String get otpWrong => 'Неверный код. В демо это 4815';
  @override String get otpOk => 'Код подтверждён';

  @override String get setupTitle => 'Давайте познакомимся';
  @override String get setupLead =>
      'Адрес нужен, чтобы подтягивать счета и предупреждать об отключениях именно у вас.';
  @override String get nameLabel => 'Фамилия и имя';
  @override String get nameHint => 'Токтогулова Айгерим';
  @override String get addressLabel => 'Улица, дом, квартира';
  @override String get addressHint => 'ул. Курманжан Датка, 212, кв. 14';
  @override String get cityLabel => 'Город';
  @override String get finish => 'Готово, открыть ЭлPay';

  @override String get tabHome => 'Главная';
  @override String get tabPayments => 'Платежи';
  @override String get tabReports => 'Отчёты';
  @override String get tabProfile => 'Профиль';

  @override String hello(String name) => 'Салам, $name';
  @override String get toPay => 'К оплате';
  @override String get billsWord => 'Счета';
  @override String billsCount(int n) =>
      '$n ${plural3(n, 'счёт', 'счёта', 'счетов')}';
  @override String paidOf(int paid, int all) => 'оплачено $paid из $all';
  @override String get allPaid => 'Все счета оплачены';
  @override String get newPayment => 'Новая оплата';
  @override String get noBillsTitle => 'Пока нет счетов';
  @override String get noBillsLead => 'Подключите услуги — счета появятся здесь сами';
  @override String get soonHere => 'Раздел в разработке';

  @override String get billsTitle => 'Счета';
  @override String get period => 'Период';
  @override String get dueDate => 'Оплатить до';
  @override String get account => 'Лицевой счёт';
  @override String get object => 'Объект';
  @override String get howCharged => 'Как начислено';
  @override String get requisites => 'Реквизиты платежа';
  @override String get requisitesHint =>
      'Нажмите на строку, чтобы скопировать. ЭлPay подставляет реквизиты сам.';
  @override String get payments => 'Платежи по этому счёту';
  @override String get recipient => 'Получатель';
  @override String get inn => 'ИНН';
  @override String get bank => 'Банк';
  @override String get bik => 'БИК';
  @override String get settlementAccount => 'Расчётный счёт';
  @override String get purpose => 'Назначение';
  @override String get copied => 'Скопировано';
  @override String get overdue => 'просрочено';
  @override String dueInDays(int n) =>
      'осталось $n ${plural3(n, 'день', 'дня', 'дней')}';
  @override String get dueToday => 'сегодня последний день';

  @override String get checkoutTitle => 'Оплата счетов';
  @override String get checkoutOne => 'Оплата';
  @override String get whatFor => 'За что платим';
  @override String get payMethod => 'Способ оплаты';
  @override String get walletBalance => 'Баланс';
  @override String get paidTitle => 'Оплачено';
  @override String get paidLead => 'Квитанции сохранены в истории платежей';
  @override String get done => 'Готово';
  @override String get shareReceipts => 'Поделиться квитанциями';
  @override String get paymentsStub =>
      'Платёжный шлюз ещё не подключён: в этой сборке оплата имитируется.';

  @override String get profileTitle => 'Профиль';
  @override String get personal => 'Личные данные';
  @override String get security => 'Безопасность';
  @override String get appSection => 'Приложение';
  @override String get theme => 'Тема';
  @override String get themeSystem => 'Системная';
  @override String get themeLight => 'Светлая';
  @override String get themeDark => 'Тёмная';
  @override String get language => 'Язык';
  @override String get logout => 'Выйти';
  @override String get logoutConfirm => 'Выйти из аккаунта?';
  @override String get version => 'Версия';

  // Платежи, история, отчёты, профиль
  @override String get paymentsTitle => 'Платежи';
  @override String get walletTitle => 'Кошелёк ЭлPay';
  @override String get topUp => 'Пополнить';
  @override String get topUpTitle => 'Пополнение кошелька';
  @override String get topUpDone => 'Кошелёк пополнен';
  @override String get newPaymentLead => 'По реквизитам или лицевому счёту';
  @override String get qrPay => 'Оплата по QR';
  @override String get qrPayLead => 'С бумажной квитанции';
  @override String get catalogTitle => 'Куда платить';
  @override String get methodsTitle => 'Способы оплаты';
  @override String get addCard => 'Добавить карту';
  @override String get historyTitle => 'История платежей';
  @override String get historyLead => 'Квитанции и выписки';
  @override String get autopayTitle => 'Автоплатежи';
  @override String get autopayLead => 'Списываем сами 25-го числа';
  @override String get autopayOn => 'Автоплатёж включён';
  @override String get autopayOff => 'Автоплатёж выключен';
  @override String get chooseProvider => 'Выберите получателя';
  @override String get searchHint => 'Поставщик или номер счёта';
  @override String get amountLabel => 'Сумма';
  @override String get checkAccount => 'Проверить';
  @override String get accountError => 'Проверьте номер — такого счёта нет';
  @override String get amountError => 'Введите сумму от 1 до 100 000 сом';
  @override String get confirmTitle => 'Проверьте платёж';
  @override String get qrLead => 'Наведите камеру на QR-код в квитанции';
  @override String get qrDemoBtn => 'Показать пример квитанции';
  @override String get qrFound => 'Квитанция распознана';
  @override String get cameraStub => 'Камера работает в приложении на телефоне. Здесь — пример распознанной квитанции.';
  @override String get historyEmpty => 'Платежей пока нет';
  @override String get receiptTitle => 'Квитанция';
  @override String get receiptNo => 'Номер квитанции';
  @override String get paidAt => 'Когда';
  @override String get methodLabel => 'Способ оплаты';
  @override String get share => 'Поделиться';
  @override String get savePdf => 'Сохранить PDF';
  @override String get repeatPay => 'Повторить платёж';
  @override String get filterAll => 'Все';
  @override String get nothingFound => 'Ничего не нашлось';
  @override String get reportsTitle => 'Отчёты';
  @override String get periodMonth => 'Месяц';
  @override String get periodYear => 'Год';
  @override String get spentTotal => 'Потрачено';
  @override String get byCategory => 'По категориям';
  @override String get byObject => 'По объектам';
  @override String get exportCsv => 'Выгрузить CSV';
  @override String get noDataPeriod => 'За этот период платежей не было';
  @override String paymentsCount(int n) =>
      '$n ${plural(n, 'платёж', 'платежа', 'платежей')}';
  @override String get vsPrevMore => 'больше, чем месяцем раньше';
  @override String get vsPrevLess => 'меньше, чем месяцем раньше';
  @override String get personalData => 'Личные данные';
  @override String get personalLead => 'Имя, телефон, почта';
  @override String get objectsTitle => 'Объекты';
  @override String get objectsLead => 'Дом, квартира родителей, дача';
  @override String get accountsTitle => 'Счета и реквизиты';
  @override String get accountsLead => 'Что подключено к ЭлPay';
  @override String get addressesTitle => 'Адреса уведомлений';
  @override String get addressesLead => 'Куда присылать об отключениях';
  @override String get familyTitle => 'Семейный доступ';
  @override String get familyLead => 'Кто видит счета и может платить';
  @override String get notifyTitle => 'Уведомления';
  @override String get notifyLead => 'Счета, отключения, тихие часы';
  @override String get securityTitle => 'Безопасность';
  @override String get securityLead => 'Код-пароль, Face ID, устройства';
  @override String get tariffsTitle => 'Тарифы и комиссии';
  @override String get tariffsLead => 'Сколько стоит платёж';
  @override String get supportTitle => 'Поддержка';
  @override String get supportLead => 'Чат и телефон 0 (3222) 5-12-12';
  @override String get deleteAccount => 'Удалить аккаунт';
  @override String get pinTitle => 'Код-пароль';
  @override String get pinLead => 'Спрашивать при входе в приложение';
  @override String get faceId => 'Вход по Face ID';
  @override String get confirmBig => 'Подтверждать платежи от 20 000 сом';
  @override String get devicesTitle => 'Устройства и входы';
  @override String get logoutAll => 'Выйти на всех устройствах';
  @override String get thisDevice => 'Это устройство';
  @override String get notifyBills => 'Счета и сроки оплаты';
  @override String get notifyOutages => 'Отключения воды и света';
  @override String get notifyMarket => 'Афиша и билеты';
  @override String get quietHours => 'Тихие часы 22:00 — 08:00';
  @override String get invite => 'Пригласить';
  @override String get canPay => 'Может платить';
  @override String get canView => 'Только смотрит';
  @override String get removeWord => 'Удалить';
  @override String get editWord => 'Изменить';
  @override String get addWord => 'Добавить';
  @override String get nothingYet => 'Пока пусто';
  @override String get soonWord => 'Скоро';

  // Названия категорий
  @override String catName(String c) => switch (c) {
        'water' => 'Вода',
        'power' => 'Свет',
        'trash' => 'Мусор',
        'gas' => 'Газ',
        'net' => 'Интернет',
        'door' => 'Домофон',
        'mobile' => 'Связь',
        'kid' => 'Садик',
        'school' => 'Школа',
        'course' => 'Курсы',
        'tax' => 'Налоги',
        'market' => 'Билеты',
        _ => 'Другое',
      };

  // Профиль: объекты, счета, семья, безопасность
  @override String get saved => 'Сохранено';
  @override String get nameFull => 'Фамилия и имя';
  @override String get phoneChange => 'Сменить номер';
  @override String get phoneChangeLead => 'Подтвердим новый номер кодом из SMS';
  @override String get objectName => 'Название объекта';
  @override String get objectAddressLabel => 'Адрес объекта';
  @override String get newObject => 'Новый объект';
  @override String get editObject => 'Изменить объект';
  @override String get deleteObjectConfirm => 'Удалить объект вместе с его счетами?';
  @override String get addAccountTitle => 'Добавить счёт';
  @override String get accountNumber => 'Номер лицевого счёта';
  @override String get chooseObject => 'К какому объекту';
  @override String get deleteAccountConfirm => 'Убрать этот счёт из ЭлPay?';
  @override String get accountAdded => 'Счёт подключён';
  @override String get addressTitleLabel => 'Название';
  @override String get newAddress => 'Добавить адрес';
  @override String get deleteAddressConfirm => 'Удалить адрес?';
  @override String get inviteMember => 'Пригласить в семью';
  @override String get memberName => 'Имя';
  @override String get memberPhone => 'Телефон';
  @override String get memberRole => 'Кем приходится';
  @override String get memberRights => 'Права';
  @override String get removeMemberConfirm => 'Убрать из семейного доступа?';
  @override String get inviteSent => 'Приглашение отправлено';
  @override String get pinOnMsg => 'Код-пароль включён';
  @override String get pinOffMsg => 'Код-пароль выключен';
  @override String get pinEnter => 'Придумайте код из 4 цифр';
  @override String get pinRepeat => 'Повторите код';
  @override String get pinMismatch => 'Коды не совпали';
  @override String get devicesLead => 'Где вы входили в ЭлPay';
  @override String get logoutAllDone => 'Вышли на всех устройствах, кроме этого';
  @override String get revokeDevice => 'Выйти';
  @override String get supportChat => 'Написать в чат';
  @override String get supportCall => 'Позвонить 0 (3222) 5-12-12';
  @override String get supportHours => 'Отвечаем с 8:00 до 20:00, без выходных';
  @override String get deleteAccountLead => 'Аккаунт, счета и история будут удалены. Отменить будет нельзя.';
  @override String get deleteAccountDone => 'Аккаунт удалён';
  @override String get tariffsNote => 'Поставщик платит 0,8% с принятого платежа — это дешевле, чем содержать кассу и бумажные квитанции.';
  @override String get tariffsLead2 => 'Для пользователя переводы бесплатны. ЭлPay зарабатывает на комиссии поставщиков и билетах маркета.';
  @override String get offer => 'Публичная оферта';
  @override String get myAccounts => 'Подключённые счета';
  @override String get objectBills => 'счетов на объекте';
  @override List<(String, String, String)> get tariffRows => const [
    ('Коммунальные платежи', 'Вода, свет, мусор, газ, интернет', '0 сом'),
    ('Садик, школа, курсы', 'Оплата по шаблону с реквизитами', '0 сом'),
    ('Налоги и патент', 'Начисления по ИНН', '0 сом'),
    ('Пополнение кошелька', 'С карты любого банка', '0 сом'),
    ('Билеты в маркете', 'Комиссия площадки уже в цене билета', '5%'),
    ('Квитанции и выписки', 'PDF и CSV, без ограничений', '0 сом'),
  ];

  // Счётчики в профиле
  @override String addressCount(int n) => '$n ${plural(n, 'адрес', 'адреса', 'адресов')}';
  @override String membersCount(int n) => '$n ${plural(n, 'участник', 'участника', 'участников')}';
  @override String get sectionAccess => 'Доступ и уведомления';

  // Новая оплата
  @override String get newPaymentHint => 'Реквизиты подставятся сами — вводить их не нужно. Сумму возьмите из квитанции.';

  // Разделы вкладки «Платежи»
  @override String get sectionHistoryAuto => 'История и автоплатежи';

  // Безопасность
  @override String get confirmBigShort => 'Подтверждать крупные платежи';
  @override String get confirmBigLead => 'От 20 000 сом — кодом или Face ID';
  @override String get pinFirst => 'Сначала включите код-пароль';
}

class SKy implements S {
  const SKy();
  @override String get langName => 'Кыргызча';
  @override String get appName => 'ЭлPay';
  @override String get byElbagar => 'ELBAGAR продуктусу';
  @override String get cont => 'Улантуу';
  @override String get cancel => 'Жокко чыгаруу';
  @override String get save => 'Сактоо';
  @override String get ready => 'Даяр';
  @override String get back => 'Артка';
  @override String get close => 'Жабуу';
  @override String get details => 'Чоо-жайы';
  @override String get pay => 'Төлөө';
  @override String get payAll => 'Баарын төлөө';
  @override String get selected => 'Тандалды';
  @override String get selectAll => 'Баарын тандоо';
  @override String get unselectAll => 'Баарын алып салуу';
  @override String get total => 'Жыйынтык';
  @override String get som => 'сом';
  @override String get skip => 'Өткөрүп жиберүү';

  @override String get welcomeTitle1 => 'Үй-бүлөнүн бардык төлөмдөрү —';
  @override String get welcomeTitle2 => 'бир басуу менен';
  @override String get welcomeLead =>
      'Коммуналдык эсептер, бала бакча жана мектеп — бир лентада. Реквизиттер бир жолу киргизилет, ал эми суу менен жарыктын өчүрүлүшү тууралуу ЭлPay алдын ала эскертет.';
  @override String get start => 'Баштоо';
  @override String get haveAccount => 'Менде аккаунт бар';
  @override String get loginTitle => 'ЭлPay кирүү';
  @override String get loginLead => 'Ыңгайлуу ыкманы тандаңыз — код бир нече секундда келет.';
  @override String get byPhone => 'Телефон';
  @override String get byEmail => 'Почта';
  @override String get byTelegram => 'Telegram';
  @override String get phoneLabel => 'Телефон номери';
  @override String get phoneHint => '555 12 34 56';
  @override String get emailLabel => 'Электрондук почта';
  @override String get emailHint => 'name@example.com';
  @override String get getCode => 'Код алуу';
  @override String get telegramLead =>
      '@elpay_bot ботун ачып, «Кирүү» баскычын басыңыз. Код чатка келет — кийинки кадамда киргизиңиз.';
  @override String get openTelegram => 'Telegram ачуу';
  @override String get telegramWait => 'Telegramдан ырастоону күтүп жатабыз…';
  @override String get telegramDone => 'Telegram кирүүнү ырастады';
  @override String get phoneError => '+996 дан кийин 9 сан керек';
  @override String get emailError => 'Дарегиңизди текшериңиз — мисалы, name@example.com';
  @override String get agreement =>
      'Улантуу менен сиз оферта жана купуялык саясаты менен макул болосуз';

  @override String get otpTitle => 'Кодду киргизиңиз';
  @override String otpSentPhone(String to) => '$to номерине SMS жөнөттүк';
  @override String otpSentEmail(String to) => '$to дарегине кат жөнөттүк';
  @override String get otpChange => 'Өзгөртүү';
  @override String get otpDemo => 'Демодогу код: 4815';
  @override String get otpPaste => 'Коюу';
  @override String otpResendIn(String time) => '$time кийин кайра жөнөтүү';
  @override String get otpResend => 'Кодду кайра жөнөтүү';
  @override String get otpChecking => 'Кодду текшерип жатабыз…';
  @override String get otpWrong => 'Код туура эмес. Демодо бул 4815';
  @override String get otpOk => 'Код ырасталды';

  @override String get setupTitle => 'Таанышып алалы';
  @override String get setupLead =>
      'Дарек эсептерди тартып алуу жана өчүрүүлөр тууралуу эскертүү үчүн керек.';
  @override String get nameLabel => 'Аты-жөнү';
  @override String get nameHint => 'Токтогулова Айгерим';
  @override String get addressLabel => 'Көчө, үй, батир';
  @override String get addressHint => 'Курманжан Датка көч., 212, 14-батир';
  @override String get cityLabel => 'Шаар';
  @override String get finish => 'Даяр, ЭлPay ачуу';

  @override String get tabHome => 'Башкы';
  @override String get tabPayments => 'Төлөмдөр';
  @override String get tabReports => 'Отчёттор';
  @override String get tabProfile => 'Профиль';

  @override String hello(String name) => 'Салам, $name';
  @override String get toPay => 'Төлөөгө';
  @override String get billsWord => 'Эсептер';
  @override String billsCount(int n) => '$n эсеп';
  @override String paidOf(int paid, int all) => '$all эсептен $paid төлөндү';
  @override String get allPaid => 'Бардык эсептер төлөндү';
  @override String get newPayment => 'Жаңы төлөм';
  @override String get noBillsTitle => 'Азырынча эсеп жок';
  @override String get noBillsLead => 'Кызматтарды туташтырыңыз — эсептер өзү пайда болот';
  @override String get soonHere => 'Бөлүм иштелип жатат';

  @override String get billsTitle => 'Эсептер';
  @override String get period => 'Мезгил';
  @override String get dueDate => 'Төлөө мөөнөтү';
  @override String get account => 'Жеке эсеп';
  @override String get object => 'Объект';
  @override String get howCharged => 'Кантип эсептелди';
  @override String get requisites => 'Төлөмдүн реквизиттери';
  @override String get requisitesHint =>
      'Көчүрүү үчүн сапты басыңыз. ЭлPay реквизиттерди өзү коёт.';
  @override String get payments => 'Бул эсеп боюнча төлөмдөр';
  @override String get recipient => 'Алуучу';
  @override String get inn => 'ИНН';
  @override String get bank => 'Банк';
  @override String get bik => 'БИК';
  @override String get settlementAccount => 'Эсептешүү эсеби';
  @override String get purpose => 'Багыты';
  @override String get copied => 'Көчүрүлдү';
  @override String get overdue => 'мөөнөтү өттү';
  @override String dueInDays(int n) => '$n күн калды';
  @override String get dueToday => 'бүгүн акыркы күн';

  @override String get checkoutTitle => 'Эсептерди төлөө';
  @override String get checkoutOne => 'Төлөм';
  @override String get whatFor => 'Эмне үчүн төлөйбүз';
  @override String get payMethod => 'Төлөм ыкмасы';
  @override String get walletBalance => 'Баланс';
  @override String get paidTitle => 'Төлөндү';
  @override String get paidLead => 'Квитанциялар төлөм тарыхында сакталды';
  @override String get done => 'Даяр';
  @override String get shareReceipts => 'Квитанциялар менен бөлүшүү';
  @override String get paymentsStub =>
      'Төлөм шлюзу азырынча туташтырылган жок: бул курулушта төлөм имитацияланат.';

  @override String get profileTitle => 'Профиль';
  @override String get personal => 'Жеке маалымат';
  @override String get security => 'Коопсуздук';
  @override String get appSection => 'Тиркеме';
  @override String get theme => 'Тема';
  @override String get themeSystem => 'Системалык';
  @override String get themeLight => 'Жарык';
  @override String get themeDark => 'Караңгы';
  @override String get language => 'Тил';
  @override String get logout => 'Чыгуу';
  @override String get logoutConfirm => 'Аккаунттан чыгасызбы?';
  @override String get version => 'Версия';

  // Платежи, история, отчёты, профиль
  @override String get paymentsTitle => 'Төлөмдөр';
  @override String get walletTitle => 'ЭлPay капчыгы';
  @override String get topUp => 'Толуктоо';
  @override String get topUpTitle => 'Капчыкты толуктоо';
  @override String get topUpDone => 'Капчык толукталды';
  @override String get newPaymentLead => 'Реквизиттер же жеке эсеп боюнча';
  @override String get qrPay => 'QR аркылуу төлөм';
  @override String get qrPayLead => 'Кагаз квитанциядан';
  @override String get catalogTitle => 'Кайда төлөө';
  @override String get methodsTitle => 'Төлөм ыкмалары';
  @override String get addCard => 'Карта кошуу';
  @override String get historyTitle => 'Төлөмдөр тарыхы';
  @override String get historyLead => 'Квитанциялар жана көчүрмөлөр';
  @override String get autopayTitle => 'Автотөлөмдөр';
  @override String get autopayLead => 'Ар айдын 25инде өзүбүз алабыз';
  @override String get autopayOn => 'Автотөлөм күйгүзүлдү';
  @override String get autopayOff => 'Автотөлөм өчүрүлдү';
  @override String get chooseProvider => 'Алуучуну тандаңыз';
  @override String get searchHint => 'Камсыздоочу же эсеп номери';
  @override String get amountLabel => 'Сумма';
  @override String get checkAccount => 'Текшерүү';
  @override String get accountError => 'Номерди текшериңиз — мындай эсеп жок';
  @override String get amountError => '1ден 100 000 сомго чейин сумманы жазыңыз';
  @override String get confirmTitle => 'Төлөмдү текшериңиз';
  @override String get qrLead => 'Камераны квитанциядагы QR-кодго багыттаңыз';
  @override String get qrDemoBtn => 'Квитанциянын үлгүсүн көрсөтүү';
  @override String get qrFound => 'Квитанция таанылды';
  @override String get cameraStub => 'Камера телефондогу колдонмодо иштейт. Бул жерде — таанылган квитанциянын үлгүсү.';
  @override String get historyEmpty => 'Азырынча төлөмдөр жок';
  @override String get receiptTitle => 'Квитанция';
  @override String get receiptNo => 'Квитанция номери';
  @override String get paidAt => 'Качан';
  @override String get methodLabel => 'Төлөм ыкмасы';
  @override String get share => 'Бөлүшүү';
  @override String get savePdf => 'PDF сактоо';
  @override String get repeatPay => 'Төлөмдү кайталоо';
  @override String get filterAll => 'Баары';
  @override String get nothingFound => 'Эч нерсе табылган жок';
  @override String get reportsTitle => 'Отчёттор';
  @override String get periodMonth => 'Ай';
  @override String get periodYear => 'Жыл';
  @override String get spentTotal => 'Сарпталды';
  @override String get byCategory => 'Категориялар боюнча';
  @override String get byObject => 'Объекттер боюнча';
  @override String get exportCsv => 'CSV жүктөө';
  @override String get noDataPeriod => 'Бул мезгилде төлөмдөр болгон жок';
  @override String paymentsCount(int n) => '$n төлөм';
  @override String get vsPrevMore => 'бир ай мурункуга караганда көп';
  @override String get vsPrevLess => 'бир ай мурункуга караганда аз';
  @override String get personalData => 'Жеке маалыматтар';
  @override String get personalLead => 'Аты, телефон, почта';
  @override String get objectsTitle => 'Объекттер';
  @override String get objectsLead => 'Үй, ата-энелердин батири, дача';
  @override String get accountsTitle => 'Эсептер жана реквизиттер';
  @override String get accountsLead => 'ЭлPayга эмне туташтырылган';
  @override String get addressesTitle => 'Билдирүү даректери';
  @override String get addressesLead => 'Өчүрүлүүлөр жөнүндө кайда жиберүү';
  @override String get familyTitle => 'Үй-бүлөлүк мүмкүнчүлүк';
  @override String get familyLead => 'Ким эсептерди көрөт жана төлөй алат';
  @override String get notifyTitle => 'Билдирүүлөр';
  @override String get notifyLead => 'Эсептер, өчүрүлүүлөр, тынч саат';
  @override String get securityTitle => 'Коопсуздук';
  @override String get securityLead => 'Код-сырсөз, Face ID, түзмөктөр';
  @override String get tariffsTitle => 'Тарифтер жана комиссиялар';
  @override String get tariffsLead => 'Төлөм канча турат';
  @override String get supportTitle => 'Колдоо';
  @override String get supportLead => 'Чат жана телефон 0 (3222) 5-12-12';
  @override String get deleteAccount => 'Аккаунтту өчүрүү';
  @override String get pinTitle => 'Код-сырсөз';
  @override String get pinLead => 'Колдонмого киргенде суроо';
  @override String get faceId => 'Face ID менен кирүү';
  @override String get confirmBig => '20 000 сомдон жогорку төлөмдөрдү ырастоо';
  @override String get devicesTitle => 'Түзмөктөр жана кирүүлөр';
  @override String get logoutAll => 'Бардык түзмөктөрдөн чыгуу';
  @override String get thisDevice => 'Ушул түзмөк';
  @override String get notifyBills => 'Эсептер жана төлөм мөөнөттөрү';
  @override String get notifyOutages => 'Суу жана жарык өчүрүлүүлөрү';
  @override String get notifyMarket => 'Афиша жана билеттер';
  @override String get quietHours => 'Тынч саат 22:00 — 08:00';
  @override String get invite => 'Чакыруу';
  @override String get canPay => 'Төлөй алат';
  @override String get canView => 'Көрө гана алат';
  @override String get removeWord => 'Өчүрүү';
  @override String get editWord => 'Өзгөртүү';
  @override String get addWord => 'Кошуу';
  @override String get nothingYet => 'Азырынча бош';
  @override String get soonWord => 'Жакында';

  // Названия категорий
  @override String catName(String c) => switch (c) {
        'water' => 'Суу',
        'power' => 'Жарык',
        'trash' => 'Таштанды',
        'gas' => 'Газ',
        'net' => 'Интернет',
        'door' => 'Домофон',
        'mobile' => 'Байланыш',
        'kid' => 'Бакча',
        'school' => 'Мектеп',
        'course' => 'Курстар',
        'tax' => 'Салыктар',
        'market' => 'Билеттер',
        _ => 'Башка',
      };

  // Профиль: объекты, счета, семья, безопасность
  @override String get saved => 'Сакталды';
  @override String get nameFull => 'Аты-жөнү';
  @override String get phoneChange => 'Номерди өзгөртүү';
  @override String get phoneChangeLead => 'Жаңы номерди SMS коду менен ырастайбыз';
  @override String get objectName => 'Объекттин аталышы';
  @override String get objectAddressLabel => 'Объекттин дареги';
  @override String get newObject => 'Жаңы объект';
  @override String get editObject => 'Объектти өзгөртүү';
  @override String get deleteObjectConfirm => 'Объектти эсептери менен өчүрөсүзбү?';
  @override String get addAccountTitle => 'Эсеп кошуу';
  @override String get accountNumber => 'Жеке эсеп номери';
  @override String get chooseObject => 'Кайсы объектке';
  @override String get deleteAccountConfirm => 'Бул эсепти ЭлPayдан алып салабызбы?';
  @override String get accountAdded => 'Эсеп туташтырылды';
  @override String get addressTitleLabel => 'Аталышы';
  @override String get newAddress => 'Дарек кошуу';
  @override String get deleteAddressConfirm => 'Даректи өчүрөбүзбү?';
  @override String get inviteMember => 'Үй-бүлөгө чакыруу';
  @override String get memberName => 'Аты';
  @override String get memberPhone => 'Телефон';
  @override String get memberRole => 'Ким болот';
  @override String get memberRights => 'Укуктар';
  @override String get removeMemberConfirm => 'Үй-бүлөлүк мүмкүнчүлүктөн алып салабызбы?';
  @override String get inviteSent => 'Чакыруу жөнөтүлдү';
  @override String get pinOnMsg => 'Код-сырсөз күйгүзүлдү';
  @override String get pinOffMsg => 'Код-сырсөз өчүрүлдү';
  @override String get pinEnter => '4 сандан турган код ойлоп табыңыз';
  @override String get pinRepeat => 'Кодду кайталаңыз';
  @override String get pinMismatch => 'Коддор дал келген жок';
  @override String get devicesLead => 'ЭлPayга кайдан киргенсиз';
  @override String get logoutAllDone => 'Ушул түзмөктөн башка баарынан чыктык';
  @override String get revokeDevice => 'Чыгуу';
  @override String get supportChat => 'Чатка жазуу';
  @override String get supportCall => '0 (3222) 5-12-12 чалуу';
  @override String get supportHours => '8:00дөн 20:00гө чейин, дем алышсыз жооп беребиз';
  @override String get deleteAccountLead => 'Аккаунт, эсептер жана тарых өчүрүлөт. Кайтарууга болбойт.';
  @override String get deleteAccountDone => 'Аккаунт өчүрүлдү';
  @override String get tariffsNote => 'Камсыздоочу кабыл алынган төлөмдөн 0,8% төлөйт — бул касса менен кагаз квитанцияларды кармагандан арзан.';
  @override String get tariffsLead2 => 'Колдонуучу үчүн которуулар акысыз. ЭлPay камсыздоочулардын комиссиясынан жана маркет билеттеринен киреше алат.';
  @override String get offer => 'Ачык оферта';
  @override String get myAccounts => 'Туташтырылган эсептер';
  @override String get objectBills => 'объекттеги эсептер';
  @override List<(String, String, String)> get tariffRows => const [
    ('Коммуналдык төлөмдөр', 'Суу, жарык, таштанды, газ, интернет', '0 сом'),
    ('Бала бакча, мектеп, курстар', 'Реквизиттери бар шаблон боюнча төлөм', '0 сом'),
    ('Салыктар жана патент', 'ИНН боюнча эсептөөлөр', '0 сом'),
    ('Капчыкты толуктоо', 'Каалаган банктын картасынан', '0 сом'),
    ('Маркеттеги билеттер', 'Аянтчанын комиссиясы билеттин баасына кирген', '5%'),
    ('Квитанциялар жана көчүрмөлөр', 'PDF жана CSV, чектөөсүз', '0 сом'),
  ];

  // Счётчики в профиле
  @override String addressCount(int n) => '$n дарек';
  @override String membersCount(int n) => '$n катышуучу';
  @override String get sectionAccess => 'Мүмкүнчүлүк жана билдирүүлөр';

  // Новая оплата
  @override String get newPaymentHint => 'Реквизиттер өзү коюлат — аларды жазуунун кереги жок. Сумманы квитанциядан алыңыз.';

  // Разделы вкладки «Платежи»
  @override String get sectionHistoryAuto => 'Тарых жана автотөлөмдөр';

  // Безопасность
  @override String get confirmBigShort => 'Ири төлөмдөрдү ырастоо';
  @override String get confirmBigLead => '20 000 сомдон жогору — код же Face ID менен';
  @override String get pinFirst => 'Адегенде код-сырсөздү күйгүзүңүз';
}

String plural3(int n, String one, String few, String many) {
  final d = n % 10, h = n % 100;
  if (d == 1 && h != 11) return one;
  if (d >= 2 && d <= 4 && (h < 10 || h >= 20)) return few;
  return many;
}
