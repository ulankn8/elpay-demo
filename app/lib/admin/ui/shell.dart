import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/tokens.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../state/admin_state.dart';
import 'kit.dart';

class _Item {
  const _Item(this.path, this.icon, this.label, {this.badge});
  final String path, label;
  final IconData icon;
  final String Function(WidgetRef ref)? badge;
}

final _svcMenu = <Object>[
  'Работа',
  const _Item('/svc/overview', Icons.grid_view_rounded, 'Обзор'),
  _Item('/svc/subscribers', Icons.people_outline_rounded, 'Абоненты', badge: (r) => nf(r.admin.subscribers.length)),
  const _Item('/svc/charges', Icons.receipt_long_outlined, 'Начисления'),
  const _Item('/svc/import', Icons.upload_rounded, 'Импорт из 1С'),
  _Item(
    '/svc/payments',
    Icons.payments_outlined,
    'Платежи и реестр',
    badge: (r) {
      final n = r.admin.pendingExport().length;
      return n == 0 ? '' : nf(n);
    },
  ),
  const _Item('/svc/notify', Icons.notifications_none_rounded, 'Уведомления'),
  'Служба',
  const _Item('/svc/staff', Icons.verified_user_outlined, 'Сотрудники и доступ'),
  _Item('/svc/api', Icons.code_rounded, 'API для 1С', badge: (_) => 'скоро'),
  const _Item('/svc/settings', Icons.settings_outlined, 'Реквизиты'),
];

final _admMenu = <Object>[
  'Пилот: Ош',
  _Item('/adm/orgs', Icons.apartment_rounded, 'Службы', badge: (r) => '${r.admin.orgs.length}'),
  _Item(
    '/adm/unmatched',
    Icons.report_gmailerrorred_rounded,
    'Без сопоставления',
    badge: (r) {
      final n = r.admin.unmatched().where((u) => u.state == UnmatchedState.open).length;
      return n == 0 ? '' : '!$n';
    },
  ),
  const _Item('/adm/audit', Icons.history_rounded, 'Журнал действий'),
  'Кабинет службы',
  const _Item('/svc/overview', Icons.water_drop_outlined, 'Кабинет Ошводоканала'),
];

/// Каркас кабинета: боковая панель и верхняя строка с поиском.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 1080;
    final side = _Side(location: location);
    return Scaffold(
      drawer: wide ? null : Drawer(width: 270, backgroundColor: K.side, child: side),
      body: Row(
        children: [
          if (wide) side,
          Expanded(
            child: Column(
              children: [
                _Top(location: location, wide: wide),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Side extends ConsumerWidget {
  const _Side({required this.location});
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.admin;
    final me = store.session;
    final admin = store.isAdmin;
    final inAdmin = location.startsWith('/adm');
    final menu = inAdmin ? _admMenu : (admin ? [..._svcMenu, 'Админ ЭлPay', const _Item('/adm/orgs', Icons.shield_outlined, 'Вернуться в админку')] : _svcMenu);
    final org = store.demoOrg;
    return Container(
      width: 260,
      color: K.side,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Brand.primary, borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'Эл',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Brand.onPrimary, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ЭлPay',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Text(
                      inAdmin ? 'Администратор' : 'Кабинет службы',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: K.sideMuted, letterSpacing: .3),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: K.side2, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                inAdmin
                    ? Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: Brand.primary, borderRadius: BorderRadius.circular(9)),
                        child: const Icon(Icons.shield_outlined, size: 17, color: Brand.onPrimary),
                      )
                    : CatIcon(org.cat, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inAdmin ? 'ЭлPay' : org.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        inAdmin ? 'Управление пилотом' : '${org.service} · Ош',
                        style: const TextStyle(fontSize: 11, color: K.sideMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                for (final m in menu)
                  if (m is String)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                      child: Text(
                        m.toUpperCase(),
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .8, color: K.sideMuted),
                      ),
                    )
                  else
                    _MenuTile(item: m as _Item, on: location.startsWith(m.path) && !(m.path == '/svc/overview' && inAdmin)),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: K.sideMuted,
                textStyle: const TextStyle(fontFamily: K.font, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Вернуть демо к началу?',
                  text: 'Загруженные файлы, правки, рассылки и выгрузки сотрутся — цифры станут как при первом открытии.',
                  ok: 'Сбросить',
                  danger: true,
                );
                if (!ok) return;
                await ref.read(actionsProvider).run((s) => s.resetDemo());
                if (context.mounted) toast(context, 'Демо-данные вернулись к началу');
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 17),
              label: const Text('Сбросить демо-данные'),
            ),
          ),
          const Divider(color: Color(0x14FFFFFF)),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 0, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFF2E5A4E),
                  child: Text(
                    me?.initials ?? '?',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me?.name ?? '',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(admin ? 'Администратор ЭлPay' : 'Сотрудник службы', style: const TextStyle(fontSize: 11, color: K.sideMuted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Выйти',
                  onPressed: () async {
                    await ref.read(actionsProvider).run((s) => s.signOut());
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout_rounded, color: K.sideMuted, size: 19),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends ConsumerWidget {
  const _MenuTile({required this.item, required this.on});
  final _Item item;
  final bool on;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = item.badge?.call(ref) ?? '';
    final alarm = badge.startsWith('!');
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: on ? const Color(0x291FB886) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) Navigator.of(context).pop();
            context.go(item.path);
          },
          child: SizedBox(
            height: 38,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(item.icon, size: 19, color: on ? Brand.primary : K.sideMuted),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? Colors.white : K.sideInk),
                  ),
                ),
                if (badge.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: alarm ? Brand.danger : const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      alarm ? badge.substring(1) : badge,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: alarm ? Colors.white : K.sideInk),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _titles = {
  '/svc/overview': 'Обзор',
  '/svc/subscribers': 'Абоненты',
  '/svc/charges': 'Начисления',
  '/svc/import/journal': 'Журнал импортов',
  '/svc/import': 'Импорт из 1С',
  '/svc/payments': 'Платежи и реестр',
  '/svc/notify': 'Уведомления',
  '/svc/staff': 'Сотрудники и доступ',
  '/svc/api': 'Интеграция по API',
  '/svc/settings': 'Реквизиты службы',
  '/adm/orgs/': 'Подключение службы',
  '/adm/orgs': 'Службы',
  '/adm/unmatched': 'Платежи без сопоставления',
  '/adm/audit': 'Журнал действий',
};

class _Top extends ConsumerStatefulWidget {
  const _Top({required this.location, required this.wide});
  final String location;
  final bool wide;
  @override
  ConsumerState<_Top> createState() => _TopState();
}

class _TopState extends ConsumerState<_Top> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.admin;
    final title = _titles.entries.firstWhere((e) => widget.location.startsWith(e.key), orElse: () => const MapEntry('', '')).value;
    final inAdmin = widget.location.startsWith('/adm');
    final p = store.openPeriod;
    final crumbs = inAdmin
        ? 'Пилот · Ош · ${store.now().day} ${monthsGen[store.now().month - 1]}'
        : '${store.demoOrg.name} · ${monthsNom[p.month - 1]} ${p.year}';
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Brand.line)),
      ),
      child: Row(
        children: [
          if (!widget.wide) IconButton(onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu_rounded), tooltip: 'Меню'),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crumbs,
                  style: const TextStyle(fontSize: 12, color: Brand.muted2, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(title, style: T.h1, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (!inAdmin && widget.wide)
            SizedBox(
              width: 320,
              child: TextField(
                controller: _q,
                decoration: const InputDecoration(
                  hintText: 'Лицевой счёт, ФИО или адрес',
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: Brand.muted2),
                  filled: true,
                  fillColor: Brand.soft,
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
                onSubmitted: (v) {
                  context.go(Uri(path: '/svc/subscribers', queryParameters: {if (v.trim().isNotEmpty) 'q': v.trim()}).toString());
                  _q.clear();
                },
              ),
            ),
          if (!inAdmin) ...[
            const SizedBox(width: 12),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Brand.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 15, color: Brand.muted),
                  const SizedBox(width: 8),
                  Text(periodTitle(p.year, p.month), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (store.demoOrg.id == ovkId) ...[
                    const SizedBox(width: 8),
                    Chip2('открыт · до ${p.due.day} ${monthsShort[p.due.month - 1]}', tone: Tone.ok),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Тело страницы с прокруткой и полями.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1500});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ),
  );
}
