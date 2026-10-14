import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tokens.dart';
import '../kit.dart';
import '../shell.dart';

/// Интеграция по API — следующий этап. Экран честно говорит, что сейчас
/// работает файл и ручной ввод, и показывает, как будет работать обмен.
class ApiPage extends ConsumerStatefulWidget {
  const ApiPage({super.key});
  @override
  ConsumerState<ApiPage> createState() => _ApiPageState();
}

class _ApiPageState extends ConsumerState<ApiPage> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    Widget way(IconData i, String title, String status, Tone tone, List<String> points) => Expanded(
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SoftIcon(i),
                const Spacer(),
                Chip2(status, tone: tone),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: T.h2),
            const SizedBox(height: 8),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('· $p', style: T.body),
              ),
          ],
        ),
      ),
    );
    Widget box(String t, String sub, {bool dark = false, bool yellow = false}) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: dark ? K.side : (yellow ? const Color(0xFFFFF8DB) : Brand.light2), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dark ? Colors.white : Brand.ink),
            ),
            const SizedBox(height: 3),
            Text(sub, style: TextStyle(fontSize: 12, color: dark ? K.sideInk : Brand.muted, height: 1.4)),
          ],
        ),
      ),
    );
    const arrow = Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.arrow_forward_rounded, color: Brand.p700),
    );

    return PageBody(
      maxWidth: 1300,
      children: [
        const Note(
          icon: Icons.schedule_rounded,
          child: Text('Сейчас абоненты и начисления загружаются файлом из 1С или вручную. Автообмен по API — следующий этап: вот как он будет работать.'),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              way(Icons.upload_file_rounded, 'Файл из 1С', 'работает', Tone.ok, const [
                'Раз в месяц: абоненты и начисления',
                'Колонки 1С узнаются сами',
                '≈ 25 минут бухгалтера в месяц',
              ]),
              const SizedBox(width: 12),
              way(Icons.edit_note_rounded, 'Ручной ввод', 'работает', Tone.ok, const [
                'Новый жилец пришёл в кассу',
                'Проверка лицевого и адреса',
                'Для садиков, школ, ТСЖ',
              ]),
              const SizedBox(width: 12),
              way(Icons.sync_alt_rounded, 'Автообмен по API', 'в проработке', Tone.warn, const [
                'Без файлов и ручной загрузки',
                'Платежи в 1С через 15 минут',
                'Нужна обработка ЭлPay для 1С',
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PanelHead('Как пойдут данные', sub: 'Служба ставит обработку ЭлPay в свою 1С — за 15 минут, без программиста, если конфигурация типовая'),
              Row(
                children: [
                  box('1С службы', 'абоненты и начисления', yellow: true),
                  arrow,
                  box('Обработка ЭлPay для 1С', 'файл .epf, по кнопке или по расписанию'),
                  arrow,
                  box('API ЭлPay', 'проверка, как в мастере импорта', dark: true),
                  arrow,
                  box('Приложение жителей', 'начисления сразу в телефоне'),
                ],
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.subdirectory_arrow_left_rounded, color: Brand.p700, size: 18),
                  SizedBox(width: 6),
                  Expanded(child: Text('Обратно: платежи из ЭлPay попадают в 1С каждые 15 минут — реестр файлом больше не нужен', style: T.sub)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PanelHead('Что понадобится'),
                    Kv([
                      ('Ключ API', 'elp_live_••••••••3f9a — выпустим на этапе пилота'),
                      ('Тестовый режим', 'Сначала — на копии реестра, без жителей'),
                      ('Сервер 1С', 'Его IP-адрес для белого списка'),
                      ('Безопасность', 'Подпись каждого запроса, ключ только у службы'),
                    ], labelWidth: 140),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Пилот API — 3–5 служб Оша, с декабря 2026, сначала в тестовом режиме.', style: T.body),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _asked
                          ? null
                          : () {
                              setState(() => _asked = true);
                              toast(context, 'Заявка передана менеджеру ЭлPay — он свяжется с вами');
                            },
                      icon: Icon(_asked ? Icons.check_rounded : Icons.handshake_outlined, size: 18),
                      label: Text(_asked ? 'Заявка отправлена' : 'Хочу участвовать в пилоте API'),
                    ),
                    const SizedBox(height: 8),
                    const Text('Подробно про варианты API — в записке концепта, экран 19', style: T.tiny),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
