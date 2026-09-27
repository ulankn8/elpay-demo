import 'models.dart';

/// Сторисы главной. Сейчас — заготовленный набор; когда появится бэкенд,
/// меняется только реализация: экраны и состояние остаются прежними.
abstract class StoriesRepository {
  Future<List<StoryItem>> stories();
}

class MockStoriesRepository implements StoriesRepository {
  @override
  Future<List<StoryItem>> stories() async => const [
        StoryItem(
          id: 's-water',
          tag: 'Сегодня',
          preview: 'Завтра\nбез воды',
          cat: 'water',
          icon: 'water',
          author: 'Ошводоканал',
          ago: '2 ч назад',
          frames: [
            StoryFrame(
              title: 'Завтра без холодной воды',
              text: 'С 10:00 до 17:00 на ул. Курманжан Датка — плановый ремонт сети.\n\n'
                  'Наберите воду заранее. Если воды не будет дольше, напишем ещё раз.',
              ctaLabel: 'Смотреть адреса',
              ctaRoute: '/notices',
            ),
            StoryFrame(
              title: 'Какие дома отключают',
              text: 'Курманжан Датка: 200–240.\nМасалиева: 40–60.\nНавои: 12–34.\n\n'
                  'Если вашего адреса нет в списке — вода будет как обычно.',
            ),
            StoryFrame(
              title: 'Счётчик тоже остановится',
              text: 'Показания за эти часы не начислят. Передавать ничего не нужно — '
                  'мы пересчитаем сами.',
              ctaLabel: 'Мои счета',
              ctaRoute: '/accounts',
            ),
          ],
        ),
        StoryItem(
          id: 's-due',
          tag: 'Срок',
          preview: 'Оплатите\nдо 25-го',
          cat: 'power',
          icon: 'power',
          author: 'ЭлPay',
          ago: 'вчера',
          frames: [
            StoryFrame(
              title: 'Оплатите до 25-го — без пени',
              text: 'За свет и воду пеня начинается с 26-го числа: 0,1% за каждый день.\n\n'
                  'Сейчас к оплате 4 919,44 сом по объекту «Дом».',
              ctaLabel: 'Открыть счета',
              ctaRoute: '/accounts',
            ),
            StoryFrame(
              title: 'Включите автоплатёж',
              text: 'ЭлPay оплатит сам 25-го числа и пришлёт квитанцию. '
                  'Выключить можно в любой момент.',
              ctaLabel: 'Настроить автоплатёж',
              ctaRoute: '/autopay',
            ),
          ],
        ),
        StoryItem(
          id: 's-kid',
          tag: 'Садик',
          preview: 'Октябрь\nуже открыт',
          cat: 'kid',
          icon: 'kid',
          author: 'Садик «Балапан»',
          ago: '2 дня назад',
          frames: [
            StoryFrame(
              title: 'Оплата за октябрь уже открыта',
              text: 'Сумма за месяц — 3 500 сом. Оплатить можно до 10 октября, '
                  'квитанция придёт в приложение.',
              ctaLabel: 'Оплатить садик',
              ctaRoute: '/accounts',
            ),
            StoryFrame(
              title: 'Что входит в сумму',
              text: 'Питание — 2 400 сом.\nУчебные материалы — 700 сом.\nОхрана — 400 сом.',
            ),
            StoryFrame(
              title: 'Нужна справка для работы',
              text: 'Квитанция из истории платежей подходит как подтверждение оплаты: '
                  'её можно сохранить в PDF.',
              ctaLabel: 'История платежей',
              ctaRoute: '/history',
            ),
          ],
        ),
        StoryItem(
          id: 's-market',
          tag: 'Афиша',
          preview: 'Концерт\n3 октября',
          cat: 'market',
          icon: 'market',
          author: 'Маркет ЭлPay',
          ago: '3 дня назад',
          frames: [
            StoryFrame(
              title: 'Концерт «Ош сезону»',
              text: '3 октября, 19:00, Ошский драмтеатр.\nБилеты от 800 сом, места свободные.',
              ctaLabel: 'Купить билет',
              ctaRoute: '/market',
            ),
            StoryFrame(
              title: 'Билет — это QR в приложении',
              text: 'Распечатывать ничего не нужно: на входе покажите QR с экрана. '
                  'Вернуть билет можно за сутки до начала.',
              ctaLabel: 'Мои билеты',
              ctaRoute: '/tickets',
            ),
          ],
        ),
        StoryItem(
          id: 's-howto',
          tag: 'Совет',
          preview: 'Счёт\nза минуту',
          cat: 'paid',
          icon: 'net',
          author: 'ЭлPay',
          ago: 'неделю назад',
          frames: [
            StoryFrame(
              title: 'Подключите счёт за минуту',
              text: 'Нажмите на значок услуги на главной, выберите «Подключить счёт» '
                  'и введите номер с бумажной квитанции.',
              ctaLabel: 'Подключить счёт',
              ctaRoute: '/accounts',
            ),
            StoryFrame(
              title: 'Дальше всё само',
              text: 'Начисления будут приходить каждый месяц, а ЭлPay напомнит о сроке '
                  'и предупредит об отключениях по вашему адресу.',
            ),
            StoryFrame(
              title: 'Семья видит те же счета',
              text: 'Добавьте супруга или родителей в семейный доступ — они увидят '
                  'начисления и смогут оплатить со своей карты.',
              ctaLabel: 'Семейный доступ',
              ctaRoute: '/family',
            ),
          ],
        ),
      ];
}
