/// Стартовые записи кабинета: службы пилота, сотрудники, журналы.
/// Совпадают с концептом (concept/admin/DATA.md).
library;

import 'mapping.dart';
import 'models.dart';
import 'seed.dart';

const demoCode = '4815';

final pilotOrgs = <Org>[
  const Org(
    id: ovkId, name: 'Ошводоканал', legalName: 'МП «Ошводоканал»', service: 'Холодная вода', cat: 'water',
    inn: '01209199810123', bank: 'ОАО «Айыл Банк»', account: '1240020001234567', bik: '124001',
    contract: '№ 14/26 от 2 марта 2026', commission: 'Комиссию платит житель: 0% при оплате картой Элкарт, 1% — другими картами',
    emailDomain: 'oshvodokanal.kg',
  ),
  const Org(id: 'ose', name: 'Ошэлектро', service: 'Электроэнергия', cat: 'power', subscribers: 18920,
      inAppShare: .271, paidShare: .584, lastImport: '2 окт, 11:30 · начисления · XLSX', emailDomain: 'oshelectro.kg'),
  const Org(id: 'tzl', name: 'Ош-Тазалык', service: 'Вывоз мусора', cat: 'trash', subscribers: 15300,
      inAppShare: .226, paidShare: .491, lastImport: '1 окт, 16:05 · начисления · CSV', emailDomain: 'osh-tazalyk.kg'),
  const Org(id: 'gas', name: 'Газпром Кыргызстан, Ош', service: 'Газ', cat: 'gas', subscribers: 9870,
      inAppShare: .183, paidShare: .710, lastImport: '3 окт, 09:12 · начисления · XLSX', emailDomain: 'gazprom.kg'),
  const Org(id: 'saima', name: 'Сайма Телеком', service: 'Интернет', cat: 'net', subscribers: 4210,
      inAppShare: .352, paidShare: .806, lastImport: '5 окт, 14:48 · абоненты · CSV', emailDomain: 'saima.kg'),
  const Org(id: 'kid14', name: 'Детский сад №14 «Балапан»', service: 'Садик', cat: 'kid', subscribers: 186,
      inAppShare: .64, paidShare: .914, lastImport: '30 сен, 17:20 · начисления · XLSX', emailDomain: 'balapan14.kg'),
  const Org(
    id: 'sch5', name: 'Школа-гимназия №5', legalName: 'Школа-гимназия №5 им. А. С. Пушкина', service: 'Школа', cat: 'school',
    inn: '02108199910456', bank: 'ОАО «РСК Банк»', account: '1290010004567890', bik: '129001',
    contract: '№ 31/26 от 6 октября 2026', commission: 'Комиссию платит школа: 0,8%',
    status: OrgStatus.onboarding, onboardingStep: 3, emailDomain: 'gimnaziya5.kg',
  ),
];

final pilotStaff = <Staff>[
  Staff(id: 'st-jypar', orgId: ovkId, name: 'Жыпар Турсунова', email: 'jypar@oshvodokanal.kg',
      invitedAt: DateTime(2026, 3, 2), lastLoginAt: DateTime(2026, 10, 14, 9, 5), device: 'Chrome · Windows'),
  Staff(id: 'st-bakyt', orgId: ovkId, name: 'Бакыт Осмонов', email: 'bakyt@oshvodokanal.kg',
      invitedAt: DateTime(2026, 3, 2), lastLoginAt: DateTime(2026, 10, 13, 17, 40), device: 'Edge · Windows'),
  Staff(id: 'st-nurgul', orgId: ovkId, name: 'Нургуль Абдыраимова', email: 'nurgul@oshvodokanal.kg',
      invitedAt: DateTime(2026, 10, 12, 15, 30)),
  Staff(id: 'st-sch5', orgId: 'sch5', name: 'Гулмира Асанова', email: 'buh@gimnaziya5.kg', invitedAt: DateTime(2026, 10, 9, 11, 0)),
  // Сотрудники остальных служб пилота — для админа ЭлPay.
  for (final (org, name, mail, day) in const [
    ('ose', 'Эрмек Абдыкадыров', 'ermek@oshelectro.kg', 14),
    ('ose', 'Айпери Маматова', 'aiperi@oshelectro.kg', 13),
    ('ose', 'Улан Исаков', 'ulan@oshelectro.kg', 10),
    ('tzl', 'Чолпон Сыдыкова', 'cholpon@osh-tazalyk.kg', 14),
    ('tzl', 'Медер Касымов', 'meder@osh-tazalyk.kg', 9),
    ('gas', 'Рустам Юлдашев', 'r.yuldashev@gazprom.kg', 14),
    ('gas', 'Наргиза Хамидова', 'n.hamidova@gazprom.kg', 14),
    ('gas', 'Тимур Рахимов', 't.rahimov@gazprom.kg', 12),
    ('gas', 'Гульнара Бакирова', 'g.bakirova@gazprom.kg', 7),
    ('saima', 'Данияр Темиров', 'billing@saima.kg', 13),
    ('kid14', 'Жылдыз Анарбаева', 'zav@balapan14.kg', 11),
  ])
    Staff(id: 'st-$mail', orgId: org, name: name, email: mail,
        invitedAt: DateTime(2026, 3, 2), lastLoginAt: DateTime(2026, 10, day, 9, 30), device: 'Chrome · Windows'),
  Staff(id: 'st-admin', orgId: 'elpay', name: 'Азамат Кадыров', email: 'a.kadyrov@elpay.kg',
      invitedAt: DateTime(2026, 2, 1), lastLoginAt: DateTime(2026, 10, 14, 8, 50), device: 'Safari · macOS', role: Role.admin),
];

/// Журнал загрузок до 14 октября. Старше суток — откатить уже нельзя.
final seedImports = <ImportJob>[
  ImportJob(id: 'imp-1010', kind: ImportKind.charges, fileName: 'nachisleniya_sentyabr.xlsx', at: DateTime(2026, 10, 1, 10, 15),
      by: 'Бакыт Осмонов', rows: 12480, created: 12480, updated: 0, unchanged: 0, errors: 0, period: openPeriod, total: SeedTotals.charged),
  ImportJob(id: 'imp-1009', kind: ImportKind.subscribers, fileName: 'abonenty_2026-10-01.csv', at: DateTime(2026, 10, 1, 9, 42),
      by: 'Жыпар Турсунова', rows: 12498, created: 37, updated: 211, unchanged: 12214, errors: 36),
  ImportJob(id: 'imp-0916', kind: ImportKind.subscribers, fileName: 'abonenty_16-09.xlsx', at: DateTime(2026, 9, 16, 14, 20),
      by: 'Бакыт Осмонов', rows: 12, created: 12, updated: 0, unchanged: 0, errors: 0),
  ImportJob(id: 'imp-0902', kind: ImportKind.charges, fileName: 'nachisleniya_avgust.xlsx', at: DateTime(2026, 9, 1, 10, 5),
      by: 'Бакыт Осмонов', rows: 12431, created: 12431, updated: 0, unchanged: 0, errors: 0, period: const Period(2026, 8), total: 2357420),
  ImportJob(id: 'imp-0901', kind: ImportKind.subscribers, fileName: 'abonenty_2026-09-01.csv', at: DateTime(2026, 9, 1, 9, 30),
      by: 'Жыпар Турсунова', rows: 12447, created: 24, updated: 158, unchanged: 12249, errors: 16),
  ImportJob(id: 'imp-0818', kind: ImportKind.subscribers, fileName: 'abonenty_novye_avgust.csv', at: DateTime(2026, 8, 18, 16, 2),
      by: 'Бакыт Осмонов', rows: 41, created: 41, updated: 0, unchanged: 0, errors: 3, status: ImportStatus.rolledBack),
  ImportJob(id: 'imp-0802', kind: ImportKind.charges, fileName: 'nachisleniya_iyul.xlsx', at: DateTime(2026, 8, 1, 10, 40),
      by: 'Бакыт Осмонов', rows: 12407, created: 12407, updated: 0, unchanged: 0, errors: 0, period: const Period(2026, 7), total: 2349870),
];

/// Шаблон «1С: Абоненты ОВК» — так служба выгружает реестр из 1С.
const seedTemplate = <String, Field>{
  'Лиц_счет': Field.account,
  'Абонент': Field.name,
  'Улица': Field.street,
  'Дом': Field.house,
  'Кв': Field.flat,
  'Кол_прож': Field.residents,
  'Телефон': Field.phone,
  'Примечание': Field.skip,
};
const seedTemplateName = '1С: Абоненты ОВК';

final seedCampaigns = <Campaign>[
  Campaign(id: 'cmp-1005', at: DateTime(2026, 10, 4, 16, 20), sendAt: DateTime(2026, 10, 5, 10, 0), segment: Segment.unpaid,
      template: 'Напоминание о сроке', text: '{имя}, за воду за сентябрь {сумма}. Оплатите до {срок} — без пени.',
      push: 3120, sms: 0, by: 'Жыпар Турсунова', paidAfter: 1044),
];

final seedAudit = <AuditEntry>[
  AuditEntry(at: DateTime(2026, 10, 14, 9, 5), who: 'Жыпар Турсунова', action: 'Вход в кабинет · Chrome · Windows', orgId: ovkId),
  AuditEntry(at: DateTime(2026, 10, 13, 18, 0), who: 'Автовыгрузка', action: 'Реестр платежей отправлен на buh@oshvodokanal.kg', orgId: ovkId),
  AuditEntry(at: DateTime(2026, 10, 12, 15, 30), who: 'Бакыт Осмонов', action: 'Приглашение сотрудника nurgul@oshvodokanal.kg', orgId: ovkId),
  AuditEntry(at: DateTime(2026, 10, 4, 16, 20), who: 'Жыпар Турсунова', action: 'Рассылка «Напоминание о сроке» на 5 окт, 10:00 · 3 120 получателей', orgId: ovkId),
  AuditEntry(at: DateTime(2026, 10, 1, 10, 15), who: 'Бакыт Осмонов', action: 'Начисления за сентябрь загружены: nachisleniya_sentyabr.xlsx, 12 480 строк', orgId: ovkId),
  AuditEntry(at: DateTime(2026, 10, 1, 9, 42), who: 'Жыпар Турсунова', action: 'Импорт абонентов abonenty_2026-10-01.csv: +37, обновлено 211, ошибок 36', orgId: ovkId),
  AuditEntry(at: DateTime(2026, 10, 6, 11, 0), who: 'Азамат Кадыров', action: 'Заведена служба «Школа-гимназия №5», договор № 31/26', orgId: 'sch5'),
  AuditEntry(at: DateTime(2026, 10, 9, 11, 0), who: 'Азамат Кадыров', action: 'Приглашение buh@gimnaziya5.kg в кабинет школы', orgId: 'sch5'),
];

final seedUnmatched = <Unmatched>[
  Unmatched(id: 'um-1', orgId: ovkId, entered: '31-01854', amount: 164, at: DateTime(2026, 10, 11, 16, 40),
      method: 'кошелёк ЭлPay', receipt: 'EP-261011-0466', payerPhone: '+996 505 88 14 37'),
  Unmatched(id: 'um-2', orgId: 'saima', entered: 'OSH-44102', amount: 1000, at: DateTime(2026, 10, 12, 8, 3),
      method: 'карта Элкарт ·· 4417', receipt: 'EP-261012-0088', payerPhone: '+996 777 40 21 63'),
  Unmatched(id: 'um-3', orgId: ovkId, entered: '31-0562', amount: 300, at: DateTime(2026, 10, 13, 21, 14),
      method: 'карта Элкарт ·· 7731', receipt: 'EP-261013-0734', payerPhone: '+996 555 31 82 47'),
];
