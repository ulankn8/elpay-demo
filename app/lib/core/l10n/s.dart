import 'package:flutter/widgets.dart';

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
}

String plural3(int n, String one, String few, String many) {
  final d = n % 10, h = n % 100;
  if (d == 1 && h != 11) return one;
  if (d >= 2 && d <= 4 && (h < 10 || h >= 20)) return few;
  return many;
}
