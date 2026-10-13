import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics.dart';
import '../core/failure.dart';
import '../core/ids.dart';
import '../core/logger.dart';
import '../core/result.dart';
import '../data/connect_rules.dart';
import '../data/models.dart';
import 'providers.dart';

/// Шаги мастера подключения.
///
/// [preview] — отдельный шаг: пользователь видит, что именно ему начислено,
/// ПРЕЖДЕ чем подключить счёт.
enum ConnectStep { form, results, preview, done }

/// Почему не подключился один конкретный счёт.
@immutable
class ConnectFailure {
  const ConnectFailure(this.candidateId, this.title, this.failure);

  final String candidateId, title;
  final AppFailure failure;
}

/// Итог подключения с ЧЕСТНЫМ частичным успехом.
///
/// Два счёта подключились, третий упал — это не «ошибка» и не «успех»,
/// и интерфейс обязан показать оба факта. Раньше при частичном успехе
/// ошибка затиралась, и про упавший счёт пользователь не узнавал вообще.
@immutable
class ConnectOutcome {
  const ConnectOutcome({
    this.connected = const [],
    this.charges = const [],
    this.failed = const [],
    this.queued = const [],
  });

  static const empty = ConnectOutcome();

  final List<ConnectedAccount> connected;

  /// Начисления, пришедшие вместе со счетами. Счёт без начисления его
  /// не получает: Bill на 0 сом не создаётся.
  final List<Bill> charges;

  final List<ConnectFailure> failed;

  /// Ушли в очередь — подключим, когда появится сеть (s.offlineQueued).
  final List<String> queued;

  int get total => connected.length + failed.length + queued.length;

  bool get isSuccess => connected.isNotEmpty && failed.isEmpty && queued.isEmpty;
  bool get isPartial => connected.isNotEmpty && (failed.isNotEmpty || queued.isNotEmpty);
  bool get isTotalFailure => connected.isEmpty && failed.isNotEmpty;
  bool get isEmpty => total == 0;

  AppFailure? get firstFailure => failed.isEmpty ? null : failed.first.failure;
}

/// Состояние мастера: поиск → разбор найденного → предпросмотр → итог.
///
/// Правил здесь нет: все решения приходят из [ConnectRules], поэтому
/// одно и то же правило проверяется юнит-тестом и работает в интерфейсе.
@immutable
class ConnectState {
  const ConnectState({
    this.step = ConnectStep.form,
    this.byAddress = false,
    this.providerId,
    this.objectId,
    this.suggestedObjectId,
    this.searching = false,
    this.connecting = false,
    this.confirming = const {},
    this.views = const [],
    this.selected = const {},
    this.previewOf,
    this.preview,
    this.outcome,
    this.keys = const {},
    this.fieldErrors = const {},
    this.failure,
  });

  final ConnectStep step;

  /// Выбран поиск по адресу, а не по лицевому счёту.
  final bool byAddress;

  /// Поставщик, с которым пришли (значок услуги на главной).
  final String? providerId;

  /// Объект, к которому подключаем. Живёт в состоянии, а не в State экрана:
  /// иначе открытие шторки подтверждения теряло выбор.
  final String? objectId;

  /// Что предложили правила по совпадению адреса.
  final String? suggestedObjectId;

  final bool searching, connecting;

  /// candidateId, по которым идёт проверка кода: спиннер только в этой
  /// строке, остальные строки списка живые.
  final Set<String> confirming;

  final List<CandidateView> views;
  final Set<String> selected;

  /// Кандидат, чью расшифровку открыли.
  final CandidateView? previewOf;

  /// Предпросмотр начислений по выбранному.
  final ChargesPreview? preview;

  final ConnectOutcome? outcome;

  /// Ключи идемпотентности по кандидатам: повтор после обрыва не создаёт
  /// второго счёта.
  final Map<String, IdempotencyKey> keys;

  /// 'accountNo' | 'city' | 'street' | 'house' | 'code' | 'objectId' →
  /// техническое пояснение. Текст для пользователя экран берёт из
  /// failure_text.dart по [failure], а не печатает это поле как есть.
  final Map<String, String> fieldErrors;

  final AppFailure? failure;

  /// Кандидаты, которые можно отметить галочкой.
  List<CandidateView> get selectable => [
        for (final v in views)
          if (v.selectable) v,
      ];

  /// Отмеченные галочкой.
  List<CandidateView> get chosen => [
        for (final v in views)
          if (selected.contains(v.id)) v,
      ];

  /// Среди отмеченных есть счёт на другое имя — сначала код из квитанции.
  bool get needsConfirm => chosen.any((v) => v.needsConfirm);

  double get selectedSum => chosen.fold(0.0, (sum, v) => sum + v.candidate.amount);

  /// Можно нажимать «Подключить»: есть что подключать, есть куда,
  /// и ничего не ждёт подтверждения.
  bool get canConnect =>
      !connecting && chosen.any((v) => v.ready) && (objectId ?? suggestedObjectId) != null;

  /// ПЕРЕХОДНЫЕ ГЕТТЕРЫ для экранов, которые ещё не знают про CandidateView.
  /// Уходят вместе с переводом connect_page на views/outcome.
  List<AccountCandidate> get found => [for (final v in views) v.candidate];

  List<ConnectedAccount> get connected => outcome?.connected ?? const [];

  ConnectState copyWith({
    ConnectStep? step,
    bool? byAddress,
    String? providerId,
    String? objectId,
    String? suggestedObjectId,
    bool? searching,
    bool? connecting,
    Set<String>? confirming,
    List<CandidateView>? views,
    Set<String>? selected,
    CandidateView? previewOf,
    ChargesPreview? preview,
    ConnectOutcome? outcome,
    Map<String, IdempotencyKey>? keys,
    Map<String, String>? fieldErrors,
    AppFailure? failure,
    bool clearFailure = false,
    bool clearFieldErrors = false,
    bool clearPreview = false,
  }) =>
      ConnectState(
        step: step ?? this.step,
        byAddress: byAddress ?? this.byAddress,
        providerId: providerId ?? this.providerId,
        objectId: objectId ?? this.objectId,
        suggestedObjectId: suggestedObjectId ?? this.suggestedObjectId,
        searching: searching ?? this.searching,
        connecting: connecting ?? this.connecting,
        confirming: confirming ?? this.confirming,
        views: views ?? this.views,
        selected: selected ?? this.selected,
        previewOf: clearPreview ? null : (previewOf ?? this.previewOf),
        preview: clearPreview ? null : (preview ?? this.preview),
        outcome: outcome ?? this.outcome,
        keys: keys ?? this.keys,
        fieldErrors: clearFieldErrors ? const {} : (fieldErrors ?? this.fieldErrors),
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

/// Мастер подключения счёта. Оркестрация, и только она: проверка номера,
/// разбор найденного, состав плана и предпросмотр живут в [ConnectRules].
class ConnectNotifier extends Notifier<ConnectState> {
  static const _tag = 'connect-state';

  ConnectRules get _rules => ref.read(rulesProvider);

  @override
  ConnectState build() => const ConnectState();

  /// Вход в мастер: сбрасывает состояние и отмечает, откуда пришли.
  void start({String? providerId, String? objectId, String source = 'manual'}) {
    state = ConnectState(providerId: providerId, objectId: objectId);
    ref.read(analyticsProvider).track(AnalyticsEvent.connectStarted(source));
  }

  /// Смена режима поиска очищает найденное, но не теряет, с чем пришли.
  void setMode({required bool byAddress}) => state = ConnectState(
        byAddress: byAddress,
        providerId: state.providerId,
        objectId: state.objectId,
      );

  void reset() => state = const ConnectState();

  void pickObject(String objectId) =>
      state = state.copyWith(objectId: objectId, clearFieldErrors: true);

  void pickProvider(String? providerId) =>
      state = state.copyWith(providerId: providerId, clearFieldErrors: true);

  // ───────────────────────── поиск ─────────────────────────

  /// Поиск по сырой строке формы. Сначала правила проверяют формат номера
  /// по маске поставщика: невалидный номер НЕ ТРАТИТ запрос, а ошибка
  /// садится в errorText поля.
  Future<void> searchByAccount(String rawAccountNo) async {
    final catalog = ref.read(catalogNowProvider);
    final id = state.providerId;
    final query = _rules.buildAccountQuery(
      rawAccountNo,
      provider: id == null ? null : catalog.providerById(id),
    );
    switch (query) {
      case Ok(:final value):
        await search(value);
      case Fail(:final failure):
        _rejectForm(failure, ConnectRules.fieldAccountNo);
    }
  }

  Future<void> searchByAddress({
    required String city,
    required String street,
    required String house,
    String flat = '',
  }) async {
    final query = _rules.buildAddressQuery(
      city: city,
      street: street,
      house: house,
      flat: flat,
      providerId: state.providerId,
    );
    switch (query) {
      case Ok(:final value):
        await search(value);
      case Fail(:final failure):
        _rejectForm(failure, 'city');
    }
  }

  /// Поиск по готовому запросу.
  ///
  /// ПЕРЕХОДНАЯ ТОЧКА ВХОДА: экран пока собирает [AccountQuery] сам.
  /// Когда он перейдёт на [searchByAccount]/[searchByAddress], метод
  /// станет приватным.
  Future<void> search(AccountQuery query) async {
    state = state.copyWith(
      searching: true,
      byAddress: !query.isByAccount,
      clearFailure: true,
      clearFieldErrors: true,
      clearPreview: true,
    );

    final result = await ref.read(accountsRepoProvider).search(query);
    state = result.fold(_classify, (failure) {
      Log.w(_tag, 'поиск не удался: ${failure.message}');
      return state.copyWith(searching: false, failure: failure);
    });
  }

  /// Подключённые счета для сверки на дубликат. Список мог ещё не
  /// загрузиться, а сверять надо сейчас, поэтому запасной вариант —
  /// кэш репозитория: он читается синхронно.
  List<ConnectedAccount> get _connected {
    final loaded = ref.read(accountsProvider).value?.accounts;
    if (loaded != null && loaded.isNotEmpty) return loaded;
    return ref.read(accountsRepoProvider).cachedAccounts();
  }

  /// Объекты пользователя — с тем же запасным вариантом.
  List<PayObject> get _objects {
    final loaded = ref.read(objectsProvider);
    if (loaded.isNotEmpty) return loaded;
    return ref.read(billsRepoProvider).cached().objects;
  }

  ConnectState _classify(List<AccountCandidate> found) {
    final catalog = ref.read(catalogNowProvider);
    final views = _rules.classify(
      found: found,
      connected: _connected,
      session: ref.read(sessionProvider),
      // Каталог не загрузился — не повод объявить всех поставщиков
      // неизвестными: это наша проблема, а не пользователя.
      catalog: catalog.isEmpty ? null : catalog,
    );
    final selected = _rules.preselect(views);
    final suggested = _rules.suggestObject(
      chosen: [
        for (final v in views)
          if (selected.contains(v.id)) v,
      ],
      objects: _objects,
    );
    return state.copyWith(
      searching: false,
      step: ConnectStep.results,
      views: views,
      selected: selected,
      suggestedObjectId: suggested,
      objectId: state.objectId ?? suggested,
      outcome: ConnectOutcome.empty,
    );
  }

  void _rejectForm(AppFailure failure, String fallbackField) => state = state.copyWith(
        searching: false,
        failure: failure,
        fieldErrors: {failure.field ?? fallbackField: failure.message},
      );

  // ───────────────────────── выбор ─────────────────────────

  void toggle(String candidateId) {
    final next = {...state.selected};
    if (!next.remove(candidateId)) next.add(candidateId);
    state = state.copyWith(selected: next, clearFailure: true);
  }

  void selectAll() => state = state.copyWith(
        selected: {for (final v in state.selectable) v.id},
        clearFailure: true,
      );

  void selectNone() => state = state.copyWith(selected: const {}, clearFailure: true);

  // ───────────────────────── предпросмотр ─────────────────────────

  /// Предпросмотр начислений — СИНХРОННО и без сети: всё нужное уже
  /// лежит в кандидатах. [candidate] = null — показать по всем выбранным.
  void preview(CandidateView? candidate) {
    final chosen = candidate == null ? state.chosen : [candidate];
    state = state.copyWith(
      step: ConnectStep.preview,
      previewOf: candidate,
      preview: _rules.preview(chosen, now: ref.read(clockProvider)()),
    );
  }

  void refreshPreview() {
    if (state.preview == null) return;
    final chosen = state.previewOf == null ? state.chosen : [state.previewOf!];
    state = state.copyWith(
      preview: _rules.preview(chosen, now: ref.read(clockProvider)()),
    );
  }

  /// Назад к списку найденного из предпросмотра.
  void backToResults() =>
      state = state.copyWith(step: ConnectStep.results, clearPreview: true);

  // ───────────────────────── подтверждение владения ─────────────────────────

  /// Код из квитанции. Неверный → fieldErrors['code'], кандидат остаётся
  /// непроверенным, остальные строки списка живые.
  Future<Result<CandidateView>> confirm(String candidateId, String code) async {
    state = state.copyWith(
      confirming: {...state.confirming, candidateId},
      clearFieldErrors: true,
      clearFailure: true,
    );
    final result = await ref
        .read(accountsRepoProvider)
        .confirm(candidateId: candidateId, code: code);

    final busy = {...state.confirming}..remove(candidateId);
    return result.fold(
      (updated) {
        final views = [
          for (final v in state.views)
            if (v.id == updated.id) v.copyWith(candidate: updated, confirmed: true) else v,
        ];
        state = state.copyWith(confirming: busy, views: views);
        final view = views.firstWhere(
          (v) => v.id == updated.id,
          orElse: () => CandidateView(candidate: updated, confirmed: true),
        );
        return Ok(view);
      },
      (failure) {
        state = state.copyWith(
          confirming: busy,
          fieldErrors: {'code': failure.message},
          failure: failure,
        );
        return Fail<CandidateView>(failure);
      },
    );
  }

  // ───────────────────────── подключение ─────────────────────────

  /// Подключает выбранные по одному, каждому — свой ключ идемпотентности.
  /// НИКОГДА не бросает: всё описано в [ConnectOutcome].
  Future<ConnectOutcome> connectChosen() async {
    final planned = _rules.plan(
      views: state.views,
      selected: state.selected,
      objectId: state.objectId ?? state.suggestedObjectId,
      objects: _objects,
      ids: ref.read(idGenProvider),
      reuse: state.keys,
    );

    switch (planned) {
      case Fail(:final failure):
        // Раньше в этом случае метод молча выходил: ни снека, ни подсказки.
        Log.w(_tag, 'подключать нечего: ${failure.message}');
        state = state.copyWith(
          connecting: false,
          failure: failure,
          fieldErrors: {
            if (failure.field != null) failure.field!: failure.message,
          },
        );
        return ConnectOutcome.empty;

      case Ok(:final value):
        state = state.copyWith(
          connecting: true,
          keys: {...state.keys, ...value.keys},
          clearFailure: true,
          clearFieldErrors: true,
        );

        final batch = await ref.read(accountsRepoProvider).connectPlan(value);
        final outcome = ConnectOutcome(
          connected: batch.connected,
          charges: batch.charges,
          queued: batch.queued,
          failed: [
            for (final item in batch.failed)
              ConnectFailure(
                item.candidateId,
                item.title,
                item.failure ?? const AppFailure(FailureKind.unknown),
              ),
          ],
        );

        if (outcome.connected.isNotEmpty) {
          final accounts = ref.read(accountsProvider.notifier);
          for (final account in outcome.connected) {
            accounts.applyConnected(account);
          }
          // Начисления дописываем сразу — счёт виден на главной, не дожидаясь
          // полного перезапроса; затем перечитываем источник.
          await ref.read(billsProvider.notifier).mergeCharges(outcome.charges);
          ref.invalidate(accountsProvider);
          await ref.read(billsProvider.notifier).refresh();
        }

        state = state.copyWith(
          connecting: false,
          outcome: outcome,
          // Пока ничего не подключилось, остаёмся на списке: экран итога
          // с «подключено 0» ничего пользователю не говорит.
          step: outcome.connected.isEmpty ? ConnectStep.results : ConnectStep.done,
          // Частичный успех — не ошибка: ошибка ставится только когда
          // не прошло вообще ничего. Всё ушло в очередь — это отказ сети,
          // и экран обязан сказать, что подключим, когда она появится.
          failure: outcome.connected.isNotEmpty
              ? null
              : outcome.firstFailure ??
                  (outcome.queued.isEmpty
                      ? null
                      : const AppFailure.network('подключим, когда появится сеть')),
          // Прошедшие кандидаты из выбора уходят: повторять по ним нечего.
          selected: {
            for (final id in state.selected)
              if (!outcome.connected.any((a) => _isSameCandidate(a, id))) id,
          },
        );
        // Операция легла в очередь: список счетов при этом не менялся
        // (строки в офлайне не появляется), сеть тоже, а pendingOpsProvider
        // пересчитывается только по ним — подпись «ждёт отправки»
        // оставалась нулевой сразу после «подключим, когда появится сеть».
        if (outcome.queued.isNotEmpty) ref.invalidate(pendingOpsProvider);
        return outcome;
    }
  }

  /// Подключённый счёт соответствует кандидату: id кандидата сервер не
  /// возвращает, поэтому сверяем по нормализованному номеру счёта.
  bool _isSameCandidate(ConnectedAccount account, String candidateId) {
    final view = state.views.where((v) => v.id == candidateId).firstOrNull;
    if (view == null) return false;
    return AccountMask.keyOf(view.candidate.accountNo) ==
        AccountMask.keyOf(account.accountNo);
  }

  /// ПЕРЕХОДНАЯ ОБЁРТКА над [connectChosen]: экран ещё держит выбранный
  /// объект у себя и ждёт число подключённых. Уходит вместе с переводом
  /// connect_page на ConnectOutcome.
  Future<int> connectSelected(String objectId) async {
    if (objectId.isNotEmpty) pickObject(objectId);
    final outcome = await connectChosen();
    return outcome.connected.length;
  }
}

final connectProvider = NotifierProvider<ConnectNotifier, ConnectState>(ConnectNotifier.new);
