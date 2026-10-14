import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin_state.dart';
import '../kit.dart';
import '../shell.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.admin.demoOrg;
    return PageBody(
      maxWidth: 1000,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CatIcon(o.cat, size: 48),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.legalName.isEmpty ? o.name : o.legalName, style: T.h1),
                      Text('${o.service} · Ош', style: T.sub),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Kv([
                ('ИНН', o.inn),
                ('Банк', o.bank),
                ('Расчётный счёт', o.account),
                ('БИК', o.bik),
                ('Договор с ЭлPay', o.contract),
                ('Комиссия', o.commission),
                ('Рабочая почта', '@${o.emailDomain}'),
              ], labelWidth: 170),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Note(
          icon: Icons.lock_outline_rounded,
          child: Text(
            'Реквизиты для зачисления меняет только ЭлPay — по письму от руководителя службы. Так деньги жителей не уйдут на чужой счёт, даже если кто-то получит доступ к кабинету.',
          ),
        ),
      ],
    );
  }
}
