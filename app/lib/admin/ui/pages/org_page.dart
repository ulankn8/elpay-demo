import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tokens.dart';
import '../../data/models.dart';
import '../../state/admin_state.dart';
import '../kit.dart';
import '../shell.dart';

/// Подключение службы по шагам: данные → реквизиты → комиссия → доступ → первый файл.
class OrgPage extends ConsumerStatefulWidget {
  const OrgPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<OrgPage> createState() => _OrgPageState();
}

class _OrgPageState extends ConsumerState<OrgPage> {
  late final Org _o = ref.read(adminStoreProvider).org(widget.id);
  late final _legal = TextEditingController(text: _o.legalName);
  late final _inn = TextEditingController(text: _o.inn);
  late final _contract = TextEditingController(text: _o.contract);
  late final _domain = TextEditingController(text: _o.emailDomain);
  late final _bank = TextEditingController(text: _o.bank);
  late final _account = TextEditingController(text: _o.account);
  late final _bik = TextEditingController(text: _o.bik);
  late final _commission = TextEditingController(text: _o.commission);
  final _inviteName = TextEditingController();
  final _inviteEmail = TextEditingController();
  String? _inviteErr;
  int? _open;

  @override
  void dispose() {
    for (final c in [_legal, _inn, _contract, _domain, _bank, _account, _bik, _commission, _inviteName, _inviteEmail]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveStep(Org o, int step, Org next, String what) async {
    final advanced = next.copyWith(onboardingStep: o.onboardingStep > step ? o.onboardingStep : step + 1);
    await ref.read(actionsProvider).run((s) => s.saveOrg(advanced, logAction: '«${o.name}»: $what'));
    setState(() => _open = null);
    if (mounted) toast(context, 'Сохранено');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.admin;
    final o = s.org(widget.id);
    final staff = s.staffOf(o.id);
    final step = o.onboardingStep;
    final current = _open ?? (step >= 5 ? -1 : step);

    Widget stepCard(int i, String title, String doneText, Widget form) {
      final done = i < step;
      final active = i == current;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          border: active ? Brand.primary : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: i <= step ? () => setState(() => _open = active ? -1 : i) : null,
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? Brand.light2 : (active ? Brand.primary : Colors.white),
                        border: Border.all(color: done || active ? Brand.primary : Brand.line, width: 1.5),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, size: 16, color: Brand.p700)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(fontWeight: FontWeight.w700, color: active ? Brand.onPrimary : Brand.muted2),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: T.h3),
                          if (done && !active) Text(doneText, style: T.sub, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (done && !active)
                      const Text(
                        'изменить',
                        style: TextStyle(fontSize: 12.5, color: Brand.p700, fontWeight: FontWeight.w700),
                      ),
                    if (!done && !active) const Chip2('впереди'),
                  ],
                ),
              ),
              if (active) ...[const SizedBox(height: 16), form],
            ],
          ),
        ),
      );
    }

    Widget row(List<Widget> ch) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ch.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: ch[i])],
      ],
    );
    Widget next(VoidCallback on) => Align(
      alignment: Alignment.centerRight,
      child: FilledButton(onPressed: on, child: const Text('Сохранить и дальше')),
    );

    final steps = Column(
      children: [
        stepCard(
          0,
          'Данные службы',
          '${o.legalName} · ИНН ${o.inn} · ${o.contract}',
          Column(
            children: [
              row([
                Field2(
                  label: 'Юридическое название',
                  child: TextField(controller: _legal),
                ),
                Field2(
                  label: 'ИНН',
                  child: TextField(controller: _inn),
                ),
              ]),
              const SizedBox(height: 12),
              row([
                Field2(
                  label: 'Договор с ЭлPay',
                  child: TextField(
                    controller: _contract,
                    decoration: const InputDecoration(hintText: '№ 31/26 от 6 октября 2026'),
                  ),
                ),
                Field2(
                  label: 'Домен рабочей почты',
                  hint: 'Пригласить можно только с него',
                  child: TextField(
                    controller: _domain,
                    decoration: const InputDecoration(hintText: 'gimnaziya5.kg'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              next(
                () => _saveStep(
                  o,
                  0,
                  o.copyWith(legalName: _legal.text, inn: _inn.text, contract: _contract.text, emailDomain: _domain.text.replaceAll('@', '').trim()),
                  'данные службы',
                ),
              ),
            ],
          ),
        ),
        stepCard(
          1,
          'Реквизиты для зачисления',
          '${o.bank} · р/с ${o.account}',
          Column(
            children: [
              row([
                Field2(
                  label: 'Банк',
                  child: TextField(controller: _bank),
                ),
                Field2(
                  label: 'Расчётный счёт',
                  child: TextField(controller: _account),
                ),
                Field2(
                  label: 'БИК',
                  child: TextField(controller: _bik),
                ),
              ]),
              const SizedBox(height: 12),
              const Note(
                tone: Tone.warn,
                icon: Icons.lock_outline_rounded,
                child: Text('Сверьте с письмом руководителя службы: на этот счёт пойдут деньги жителей.'),
              ),
              const SizedBox(height: 12),
              next(() => _saveStep(o, 1, o.copyWith(bank: _bank.text, account: _account.text, bik: _bik.text), 'реквизиты для зачисления')),
            ],
          ),
        ),
        stepCard(
          2,
          'Комиссия и тариф',
          o.commission,
          Column(
            children: [
              Field2(
                label: 'Кто и сколько платит',
                hint: 'Например: «Комиссию платит школа: 0,8%»',
                child: TextField(controller: _commission),
              ),
              const SizedBox(height: 12),
              next(() => _saveStep(o, 2, o.copyWith(commission: _commission.text), 'комиссия')),
            ],
          ),
        ),
        stepCard(
          3,
          'Доступ сотрудникам',
          '${staff.length} ${staff.length == 1 ? 'сотрудник' : 'сотрудника'}: ${staff.map((x) => x.email).join(', ')}',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final st in staff)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: Brand.light2,
                        child: Text(
                          st.initials,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Brand.p700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${st.name} · ${st.email}', style: T.td)),
                      st.pending ? const Chip2('ждёт входа', tone: Tone.warn) : const Chip2('входил', tone: Tone.ok),
                    ],
                  ),
                ),
              row([
                TextField(
                  controller: _inviteName,
                  decoration: const InputDecoration(hintText: 'Имя и фамилия'),
                ),
                TextField(
                  controller: _inviteEmail,
                  decoration: InputDecoration(hintText: 'почта@${o.emailDomain}', errorText: _inviteErr),
                ),
              ]),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final r = await ref.read(actionsProvider).run((x) => x.invite(orgId: o.id, name: _inviteName.text, email: _inviteEmail.text));
                      setState(() => _inviteErr = r.failureOrNull?.message);
                      if (r.isOk) {
                        _inviteName.clear();
                        _inviteEmail.clear();
                      }
                    },
                    child: const Text('Пригласить'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: staff.isEmpty ? null : () => _saveStep(o, 3, o, 'доступ выдан'), child: const Text('Дальше')),
                ],
              ),
            ],
          ),
        ),
        stepCard(
          4,
          'Первый файл абонентов',
          'загружен',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Note(
                icon: Icons.hourglass_top_rounded,
                child: Text(
                  staff.any((x) => !x.pending)
                      ? 'Сотрудник службы уже входил — ждём, когда он загрузит выгрузку из 1С через мастер импорта.'
                      : 'Сотрудник ещё не входил в кабинет. Без него не будет файла с учениками. Напомните по телефону или отправьте приглашение ещё раз.',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => toast(context, 'Приглашение отправлено ещё раз'), child: const Text('Напомнить сотруднику')),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () async {
                      await ref
                          .read(actionsProvider)
                          .run(
                            (x) => x.saveOrg(o.copyWith(onboardingStep: 5, status: OrgStatus.active), logAction: '«${o.name}» запущена: первый файл принят'),
                          );
                      if (context.mounted) toast(context, '${o.name} работает — появится у жителей в каталоге');
                    },
                    child: const Text('Файл принят — запустить службу'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final side = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHead('Что увидят жители'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Brand.soft, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                CatIcon(o.cat, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.name, style: T.h3),
                      Text('${o.service} · Ош · подключить по лицевому', style: T.sub),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            o.status == OrgStatus.active
                ? 'Служба уже в каталоге приложения.'
                : 'Появится в каталоге приложения сразу после запуска — с поиском по названию и лицевому.',
            style: T.sub,
          ),
          const SizedBox(height: 18),
          const Text('Готово к запуску', style: T.h3),
          const SizedBox(height: 8),
          // Каждый пункт — по факту, а не по номеру шага: «вошёл в кабинет»
          // значит, что сотрудник действительно входил.
          for (final (t, ok) in [
            ('Договор и ИНН', step > 0),
            ('Реквизиты сверены', step > 1),
            ('Комиссия согласована', step > 2),
            ('Сотрудник вошёл в кабинет', staff.any((x) => !x.pending)),
            ('Первый файл загружен', o.status == OrgStatus.active),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: ok ? Brand.primary : Brand.muted2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t, style: T.td.copyWith(color: ok ? Brand.ink : Brand.muted)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return PageBody(
      children: [
        Row(
          children: [
            IconButton(onPressed: () => context.go('/adm/orgs'), icon: const Icon(Icons.arrow_back_rounded)),
            CatIcon(o.cat, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.name, style: T.h1),
                  Text(o.status == OrgStatus.active ? 'Работает' : 'Подключение: готово $step из 5 шагов', style: T.sub),
                ],
              ),
            ),
            o.status == OrgStatus.active ? const Chip2('Работает', tone: Tone.ok) : Chip2('$step из 5', tone: Tone.warn),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: steps),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: side),
          ],
        ),
      ],
    );
  }
}
