import 'dart:async';

import 'package:elpay/core/failure.dart';
import 'package:elpay/core/l10n/failure_text.dart';
import 'package:elpay/core/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/widget_harness.dart';

/// `AsyncSection` — одно место, где решается, что показать вместо данных.
///
/// До него каждый экран решал это сам (а чаще не решал): единственным
/// показом ошибки в приложении был `Text('$e')` на главной — пользователь
/// читал «AppFailure(network): нет связи». Поэтому здесь проверяется
/// именно это: скелетон вместо пустого экрана, текст из S вместо `$e`,
/// плашка офлайна над сохранёнными данными и EmptyState на пустом ответе.
void main() {
  /// Секция со списком строк. [stale] — данные сохранённые.
  Future<void> pumpSection(
    WidgetTester tester, {
    required AsyncValue<List<String>> value,
    VoidCallback? onRetry,
    Widget? skeleton,
    Widget? empty,
    bool stale = false,
    bool compactError = false,
  }) =>
      pumpWidgetUnderTest(
        tester,
        AsyncSection<List<String>>(
          value: value,
          stale: stale,
          compactError: compactError,
          onRetry: onRetry,
          skeleton: skeleton,
          empty: empty,
          isEmpty: (list) => list.isEmpty,
          data: (list) => Column(
            children: [for (final item in list) Text(item)],
          ),
        ),
        scrollable: true,
      );

  /// Секция поверх НАСТОЯЩЕГО провайдера: первый ответ удачный,
  /// обновление — отказ. Возвращает «потянуть вниз».
  ///
  /// Состояние «данные есть, и при этом есть ошибка» склеить руками
  /// нельзя — это внутренность Riverpod. Да и не надо: в бою оно
  /// возникает именно так, pull-to-refresh по нарисованному списку.
  Future<VoidCallback> pumpRefreshFailing(
    WidgetTester tester, {
    required Object error,
    List<String> data = const ['Ошводоканал'],
  }) async {
    var attempt = 0;
    final provider = FutureProvider<List<String>>((ref) async {
      if (attempt++ == 0) return data;
      throw error;
    });
    late WidgetRef captured;

    await pumpWidgetUnderTest(
      tester,
      Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return AsyncSection<List<String>>(
            value: ref.watch(provider),
            onRetry: () {},
            isEmpty: (list) => list.isEmpty,
            data: (list) => Column(
              children: [for (final item in list) Text(item)],
            ),
          );
        },
      ),
      scrollable: true,
    );
    await settleData(tester, steps: 2);
    return () => captured.invalidate(provider);
  }

  group('Загрузка', () {
    testWidgets('Во время загрузки показывается скелетон, а не пустое состояние',
        (tester) async {
      await pumpSection(
        tester,
        value: const AsyncLoading<List<String>>(),
        empty: const EmptyState(icon: Icons.inbox_outlined, title: 'Пусто'),
      );

      expect(find.byType(LoadingRows), findsOneWidget);
      // Пустое состояние на первой загрузке — вранье: данные ещё едут.
      expect(find.text('Пусто'), findsNothing);
      expect(find.byType(ErrorView), findsNothing);
    });

    testWidgets('Свой скелетон заменяет стандартный', (tester) async {
      await pumpSection(
        tester,
        value: const AsyncLoading<List<String>>(),
        skeleton: const Text('своя заглушка'),
      );

      expect(find.text('своя заглушка'), findsOneWidget);
      expect(find.byType(LoadingRows), findsNothing);
    });
  });

  group('Ошибка без данных', () {
    testWidgets('Ошибка показывает текст из S и кнопку повтора, а не \$e',
        (tester) async {
      var retried = 0;
      await pumpSection(
        tester,
        value: AsyncError<List<String>>(
          const AppFailure.network('нет связи'),
          StackTrace.empty,
        ),
        onRetry: () => retried++,
      );

      expect(find.text('Нет связи с сервером'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      // Техническое сообщение пользователю не показывают.
      expect(find.textContaining('AppFailure'), findsNothing);
      expect(find.textContaining('нет связи'), findsNothing);

      await tester.tap(find.text('Повторить'));
      expect(retried, 1);
    });

    testWidgets('Сырое исключение тоже становится человеческим текстом',
        (tester) async {
      await pumpSection(
        tester,
        value: AsyncError<List<String>>(
          Exception('RangeError (index): Invalid value'),
          StackTrace.empty,
        ),
      );

      expect(find.text('Неизвестная ошибка'), findsOneWidget);
      expect(find.textContaining('RangeError'), findsNothing);
    });

    testWidgets('Без onRetry кнопки повтора нет', (tester) async {
      await pumpSection(
        tester,
        value: AsyncError<List<String>>(
          const AppFailure.server(),
          StackTrace.empty,
        ),
      );

      expect(find.text('Сервер не ответил'), findsOneWidget);
      expect(find.text('Повторить'), findsNothing);
    });
  });

  group('Данные есть', () {
    testWidgets('Данные из кэша рисуют плашку офлайна', (tester) async {
      await pumpSection(
        tester,
        value: const AsyncData<List<String>>(['Ошводоканал']),
        stale: true,
        onRetry: () {},
      );

      expect(find.text('Нет сети — показываем сохранённые данные'), findsOneWidget);
      // Данные при этом видны: плашка не вместо них, а над ними.
      expect(find.text('Ошводоканал'), findsOneWidget);
      expect(find.byType(ErrorView), findsNothing);
    });

    testWidgets('Сетевая ошибка поверх данных — это офлайн, а не ошибка',
        (tester) async {
      final refresh = await pumpRefreshFailing(
        tester,
        error: const AppFailure.network(),
      );
      expect(find.text('Ошводоканал'), findsOneWidget);

      refresh();
      await settleData(tester, steps: 2);

      expect(find.byType(OfflineBanner), findsOneWidget);
      // Данные при этом не пропадают: обновить не удалось, а не потеряли.
      expect(find.text('Ошводоканал'), findsOneWidget);
    });

    testWidgets('Серверная ошибка поверх данных офлайном не выдаётся',
        (tester) async {
      final refresh = await pumpRefreshFailing(
        tester,
        error: const AppFailure.server(),
      );

      refresh();
      await settleData(tester, steps: 2);

      // Нет сети и «сервер сломался» — разные сообщения, и подменять
      // второе первым нельзя: пользователь пойдёт проверять вайфай.
      expect(find.byType(OfflineBanner), findsNothing);
      expect(find.text('Сервер не ответил'), findsOneWidget);
      expect(find.text('Ошводоканал'), findsOneWidget);
    });

    testWidgets('Пустые данные показывают EmptyState', (tester) async {
      await pumpSection(
        tester,
        value: const AsyncData<List<String>>([]),
        empty: const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Счетов пока нет',
          lead: 'Подключите первый счёт',
        ),
      );

      expect(find.text('Счетов пока нет'), findsOneWidget);
      expect(find.byType(LoadingRows), findsNothing);
      expect(find.byType(ErrorView), findsNothing);
    });

    testWidgets('Непустые данные рисуются без плашек', (tester) async {
      await pumpSection(
        tester,
        value: const AsyncData<List<String>>(['Ошводоканал', 'Ошэлектро']),
        empty: const EmptyState(icon: Icons.inbox_outlined, title: 'Пусто'),
      );

      expect(find.text('Ошводоканал'), findsOneWidget);
      expect(find.text('Ошэлектро'), findsOneWidget);
      expect(find.text('Пусто'), findsNothing);
      expect(find.byType(OfflineBanner), findsNothing);
      expect(find.byType(ErrorView), findsNothing);
    });
  });

  group('Приведение ошибки', () {
    test('failureOf не выдумывает тип там, где он уже известен', () {
      const known = AppFailure.auth('токен истёк');

      expect(failureOf(known), same(known));
      expect(failureOf(null).kind, FailureKind.unknown);
      expect(failureOf(TimeoutException('ждём')).kind, FailureKind.network);
      // Сетевые исключения приходят разными классами, а dart:io в веб
      // не входит — опознаются по тексту.
      expect(
        failureOf(Exception('SocketException: Failed host lookup')).kind,
        FailureKind.network,
      );
      expect(failureOf(StateError('что-то своё')).kind, FailureKind.unknown);
    });

    test('Повтор предлагается только там, где он помогает', () {
      expect(showRetry(const AppFailure.network()), isTrue);
      expect(showRetry(const AppFailure.server()), isTrue);
      // Неверный номер счёта от повтора верным не станет.
      expect(showRetry(const AppFailure.validation('номер не тот')), isFalse);
      expect(showRetry(const AppFailure.auth()), isFalse);
    });
  });
}
