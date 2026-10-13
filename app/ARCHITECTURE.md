# Архитектура приложения ЭлPay

Документ для того, кто будет писать код дальше: где что лежит, по каким
правилам добавляется новое и что нужно поменять, когда появятся боевой
бэкенд и платёжный шлюз.

## Слои

```
UI (lib/features/**)        экраны и виджеты, ничего не знают про сеть
    ↕ Riverpod
Состояние (lib/state)       Notifier/AsyncNotifier, хранят то, что видит экран
    ↕ Result<T>
Репозитории (lib/data)      сеть + кэш + очередь, отдают Result, не бросают
    ↕ ElPayApi
Источник (lib/data/api)     MockElPayApi (демо) или HttpElPayApi (бой)
    ↕ ApiClient
Инфраструктура (lib/core)   конфиг, ошибки, кэш, сеть, логи, аналитика
```

Правило одно: **зависимости идут сверху вниз**. Экран не импортирует
`api/`, репозиторий не знает про виджеты, `core` не знает ни о ком.

## Что где лежит

| Папка | Что внутри |
|---|---|
| `lib/core` | Токены и тема, форматы, локализация (`l10n/s.dart`), `AppConfig`, `Result`/`AppFailure`, кэш (`cache/local_store.dart`), сеть (`net/connectivity.dart`, `net/outbox.dart`), логи и аналитика, общие виджеты. |
| `lib/data` | Модели (`models.dart`), демо-данные (`demo_data.dart`, `registry_data.dart`), контракт бэкенда (`api/elpay_api.dart`) с двумя реализациями, репозитории. |
| `lib/state` | Провайдеры Riverpod: сессия, счета, подключённые счета, мастер подключения, кошелёк, история, настройки. |
| `lib/features` | Экраны по разделам: `auth`, `home`, `accounts`, `bills`, `objects`, `payments`, `history`, `reports`, `market`, `notices`, `stories`, `profile`, `shell`. |

## Ошибки и результат

Репозитории не бросают исключения, а возвращают `Result<T>`:

```dart
final result = await repo.search(query);
result.fold(
  (list) => показатьНайденное(list),
  (failure) => показатьОшибку(failure),   // AppFailure с типом
);
```

`AppFailure.kind` — это `network`, `server`, `validation`, `notFound`,
`auth`, `cancelled`, `unknown`. По типу UI решает, что показать:
`ErrorView` подставляет текст из `S`, а не техническое сообщение.
Исключения превращаются в `AppFailure` функцией `guard()` на границе
слоя данных.

## Данные: кэш и офлайн

1. Экран открывается — репозиторий отдаёт **сохранённое** из `LocalStore`
   (JSON поверх SharedPreferences), поэтому список виден сразу.
2. Параллельно идёт запрос в источник. Ответ пишется в кэш.
3. Если сети нет — показывается кэш плюс плашка `OfflineBanner`.
4. Действия пользователя, которые нельзя выполнить без сети (например,
   подключение счёта), ложатся в `Outbox` и уходят, когда связь появится
   (`flushOutbox()`), максимум пять попыток.

Состояние сети даёт `ConnectivityService`. В демо это `ManualConnectivity`
с переключателем в профиле («Для демонстрации» → «Режим без сети»),
в бою сюда подставляется реализация поверх `connectivity_plus`.

## Подключение счетов

Главный сценарий фичи (`lib/features/accounts`):

1. **Поиск.** `ConnectAccountPage` — два способа: по лицевому счёту или
   по адресу (город, улица, дом, квартира). Адрес подставляется из профиля.
2. **Результаты.** `AccountsRepository.search()` возвращает
   `AccountCandidate` — что нашли в реестре поставщика: владелец, адрес,
   последнее начисление и расшифровка. Уже подключённые помечены и не
   выбираются.
3. **Подтверждение.** Если счёт оформлен на другого человека
   (`needsConfirm`), открывается `confirm_sheet.dart` и просит код
   (в демо — `4815`).
4. **Подключение.** `connect()` создаёт `ConnectedAccount` и, если
   начисление уже выставлено, `Bill`. Оба попадают в кэш, провайдеры
   `accountsProvider` и `billsProvider` обновляются.
5. **Жизнь счёта.** `AccountsPage` показывает подключённые счета по
   объектам, статус синхронизации (`ok` / `syncing` / `failed`), время
   последнего обновления; «Обновить» зовёт `sync()`, меню строки —
   `disconnect()`.

## Переключение на боевой бэкенд

Весь обмен с сервером описан одним контрактом `ElPayApi`
(`lib/data/api/elpay_api.dart`). Реализаций две:

* `MockElPayApi` — отвечает из `demo_data.dart` и `registry_data.dart`,
  имитирует задержку и честно падает `AppFailure.network`, когда в демо
  выключена сеть;
* `HttpElPayApi` — те же методы поверх `ApiClient` (таймауты, повторы,
  коды ответа → `AppFailure`). Эндпоинты уже зафиксированы.

Переключение — флагом сборки, кода менять не нужно:

```bash
flutter build apk --dart-define=API_BASE_URL=https://api.elpay.kg/v1 \
                  --dart-define=USE_MOCK=false
```

`AppConfig` (`lib/core/app_config.dart`) читает `--dart-define` и решает,
какую реализацию отдаст `apiProvider`. Там же флаги `PAYMENTS_ENABLED` и
`REAL_AUTH_ENABLED` — ими включаются боевой шлюз и боевой вход, когда
появятся их реализации.

### Что ещё остаётся заглушкой

| Что | Где | Чем заменить |
|---|---|---|
| Вход по SMS и Telegram | `data/auth_repository.dart` | реализация `AuthRepository` поверх своего OTP-сервиса |
| Оплата | `data/payments_repository.dart` | реализация `PaymentsRepository` поверх эквайринга |

Оба подставляются одной строкой в `lib/state/providers.dart` — экраны
оплаты и входа трогать не придётся.

## Добавить новую фичу

1. Модель — в `lib/data/models.dart` (с `toJson`/`fromJson`, иначе не
   попадёт в кэш).
2. Метод — в `ElPayApi` и в обе реализации.
3. Репозиторий — в `lib/data`, возвращает `Result`, пишет в `LocalStore`.
4. Провайдер — в `lib/state/providers.dart`.
5. Экран — в `lib/features/<фича>`, состояния `loading` / `error` /
   `empty` обязательны (`LoadingRows`, `ErrorView`, `EmptyState`).
6. Строки — только через `tool/l10n_add.py` (русский и кыргызский сразу).
7. Тест — в `test/`, на репозиторий и на граничные случаи.

## Проверка

```bash
flutter analyze      # должно быть «No issues found»
flutter test         # 43 теста: core, репозитории, подключение счетов, экраны
```
