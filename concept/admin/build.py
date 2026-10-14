# -*- coding: utf-8 -*-
"""Собирает концепт кабинета служб ЭлPay в один index.html.

Каждый экран — файл screens/NN-имя.html. Первая строка файла — метаданные:
    <!-- group: Кабинет службы | cap: Обзор | sub: что видно на экране -->
Дальше — разметка экрана (обычно <div class="desk">…</div>).

Заготовки, которые разворачивает сборка (чтобы боковая панель и значки
были одинаковыми на всех экранах):
    {{i:имя}}            — значок 24×24 (список ниже, в ICONS)
    {{ic:кат:имя}}       — цветной квадратик услуги, кат = water|power|trash|kid|school|net|gas
    {{side:svc:пункт}}   — боковая панель кабинета службы, пункт подсвечен
    {{side:adm:пункт}}   — боковая панель админа ЭлPay, пункт подсвечен
    {{top:Заголовок|Крошки}} — верхняя строка с поиском (крошки необязательны)

Запуск: python3 build.py  (из папки concept/admin)
"""
import glob, io, os, re

ICONS = {
 'water':'<path d="M12 3s6 6.2 6 10a6 6 0 1 1-12 0c0-3.8 6-10 6-10Z"/>',
 'power':'<path d="M13 2 4.5 13H11l-1 9 8.5-11H12l1-9Z"/>',
 'trash':'<path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13"/>',
 'kid':'<circle cx="12" cy="12" r="8"/><path d="M9.5 15c1.6 1.2 3.4 1.2 5 0"/>',
 'school':'<path d="M12 4 3 9l9 5 9-5-9-5Z"/><path d="M7 12v5c0 1.5 2.4 3 5 3s5-1.5 5-3v-5"/>',
 'net':'<path d="M2.5 9a14 14 0 0 1 19 0M6 12.5a9 9 0 0 1 12 0M9.5 16a4 4 0 0 1 5 0"/><circle cx="12" cy="19.5" r=".9"/>',
 'gas':'<path d="M12 3c3 4 6 5.5 6 9a6 6 0 1 1-12 0c0-2 1-3.4 2.5-4.6"/>',
 'home':'<path d="M4 11 12 4l8 7"/><path d="M6 10v9h12v-9"/>',
 'grid':'<rect x="4" y="4" width="7" height="7" rx="2"/><rect x="13" y="4" width="7" height="7" rx="2"/><rect x="4" y="13" width="7" height="7" rx="2"/><rect x="13" y="13" width="7" height="7" rx="2"/>',
 'users':'<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19c.6-3 2.9-4.6 5.5-4.6S14 16 14.6 19"/><path d="M16.2 5.6a3.2 3.2 0 0 1 0 6.2"/><path d="M17.2 14.7c2 .5 3.4 2 3.8 4.3"/>',
 'user':'<circle cx="12" cy="8" r="3.6"/><path d="M4.5 20c.8-3.8 3.7-5.8 7.5-5.8s6.7 2 7.5 5.8"/>',
 'useradd':'<circle cx="10" cy="8" r="3.6"/><path d="M3 20c.8-3.8 3.4-5.8 7-5.8 1.4 0 2.7.3 3.8.9"/><path d="M18 14v6M15 17h6"/>',
 'doc':'<path d="M6.5 3h7l4 4v14h-11z"/><path d="M13.5 3v4h4M9.5 12h5M9.5 16h5"/>',
 'upload':'<path d="M12 16V4M7 9l5-5 5 5"/><path d="M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3"/>',
 'download':'<path d="M12 4v12M7 11l5 5 5-5"/><path d="M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3"/>',
 'card':'<rect x="3" y="6" width="18" height="13" rx="3"/><path d="M3 10.5h18"/>',
 'coins':'<ellipse cx="9" cy="7" rx="5.5" ry="2.5"/><path d="M3.5 7v4c0 1.4 2.5 2.5 5.5 2.5s5.5-1.1 5.5-2.5V7"/><path d="M9.5 16.3c.5.1 1 .2 1.5.2 3 0 5.5-1.1 5.5-2.5V10"/><path d="M15 9.6c3 .2 5.5 1.3 5.5 2.4v4c0 1.4-2.5 2.5-5.5 2.5-1.8 0-3.4-.4-4.4-1"/>',
 'bell':'<path d="M18 16V11a6 6 0 1 0-12 0v5l-1.6 2.6h15.2L18 16Z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
 'send':'<path d="M21 3 10 14"/><path d="M21 3 14.5 21l-4-8.5L2 8.5Z"/>',
 'key':'<circle cx="8" cy="15" r="4"/><path d="m11 12 9-9M17 6l3 3M14 9l2 2"/>',
 'shield':'<path d="M12 3 4.5 6v5.5c0 4.5 3.2 8.2 7.5 9.5 4.3-1.3 7.5-5 7.5-9.5V6Z"/><path d="m9 12 2.2 2.2L15.5 10"/>',
 'gear':'<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.6 1.6 0 0 0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1Z"/>',
 'search':'<circle cx="11" cy="11" r="6.5"/><path d="m20 20-4.2-4.2"/>',
 'filter':'<path d="M4 5h16l-6 7.5V19l-4 1.5v-8Z"/>',
 'cal':'<rect x="3.5" y="5" width="17" height="15" rx="3"/><path d="M8 3v4M16 3v4M3.5 10h17"/>',
 'chart':'<path d="M5 19V9M12 19V5M19 19v-7"/>',
 'plus':'<path d="M12 5v14M5 12h14"/>',
 'check':'<path d="m5 12.5 4.5 4.5L19 7"/>',
 'x':'<path d="M6 6l12 12M18 6 6 18"/>',
 'alert':'<path d="M12 4 2.8 19.5h18.4Z"/><path d="M12 10v4.5M12 17.2v.2"/>',
 'info':'<circle cx="12" cy="12" r="9"/><path d="M12 11v5.5M12 7.8v.2"/>',
 'clock':'<circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 2"/>',
 'refresh':'<path d="M20 11a8 8 0 0 0-14.5-4.5L4 8"/><path d="M4 4v4h4"/><path d="M4 13a8 8 0 0 0 14.5 4.5L20 16"/><path d="M20 20v-4h-4"/>',
 'link':'<path d="M10 14a4.5 4.5 0 0 0 6.4 0l3-3a4.5 4.5 0 0 0-6.4-6.4l-1 1"/><path d="M14 10a4.5 4.5 0 0 0-6.4 0l-3 3a4.5 4.5 0 0 0 6.4 6.4l1-1"/>',
 'edit':'<path d="M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16Z"/><path d="m13.5 6.5 4 4"/>',
 'phone':'<rect x="7" y="3" width="10" height="18" rx="3"/><path d="M11 18h2"/>',
 'sms':'<path d="M4 5h16v11H9l-5 4Z"/><path d="M8 10h.1M12 10h.1M16 10h.1"/>',
 'building':'<path d="M4 21V6l8-3v18M12 21h8V10l-8-3"/><path d="M7.5 9h1M7.5 13h1M7.5 17h1M15.5 13h1M15.5 17h1"/>',
 'history':'<path d="M3.5 12a8.5 8.5 0 1 0 2.6-6.1L3.5 8.5"/><path d="M3.5 4v4.5H8M12 8v4.5l3 2"/>',
 'arrow':'<path d="M5 12h13M13 7l5 5-5 5"/>',
 'back':'<path d="M19 12H5M11 6l-6 6 6 6"/>',
 'chev':'<path d="m9 5 7 7-7 7"/>',
 'down':'<path d="m6 9 6 6 6-6"/>',
 'more':'<circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/>',
 'pin':'<path d="M12 21s7-6.2 7-11a7 7 0 1 0-14 0c0 4.8 7 11 7 11Z"/><circle cx="12" cy="10" r="2.5"/>',
 'table':'<rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><path d="M3.5 9.5h17M3.5 14.5h17M9.5 9.5v10"/>',
 'swap':'<path d="M7 4 3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7"/>',
 'lock':'<rect x="5" y="11" width="14" height="10" rx="2.5"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
 'mail':'<rect x="3" y="5" width="18" height="14" rx="3"/><path d="m4 7 8 6 8-6"/>',
 'code':'<path d="m8 8-4 4 4 4M16 8l4 4-4 4M13.5 5l-3 14"/>',
 'eye':'<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z"/><circle cx="12" cy="12" r="2.8"/>',
 'zap':'<path d="M13 3 6 13h5l-1 8 7-10h-5l1-8Z"/>',
 'ticket':'<path d="M4 7h16v3a2 2 0 0 0 0 4v3H4v-3a2 2 0 0 0 0-4Z"/><path d="M14 7v10"/>',
 'chat':'<path d="M4 5h16v11H9l-5 4Z"/>',
}

def icon(name):
    return '<svg viewBox="0 0 24 24">%s</svg>' % ICONS[name]

def catbox(cat, name):
    return '<span class="ic" style="background:var(--g-%s)">%s</span>' % (cat, icon(name))

SVC_MENU = [
  ('sec', 'Работа'),
  ('obzor', 'grid', 'Обзор', ''),
  ('abon', 'users', 'Абоненты', '<i class="n">12 480</i>'),
  ('nach', 'doc', 'Начисления', ''),
  ('import', 'upload', 'Импорт из 1С', ''),
  ('pay', 'coins', 'Платежи и реестр', '<i class="n">382</i>'),
  ('notify', 'bell', 'Уведомления', ''),
  ('sec', 'Служба'),
  ('access', 'shield', 'Сотрудники и доступ', ''),
  ('api', 'code', 'Интеграция по API', '<i class="n">скоро</i>'),
  ('settings', 'gear', 'Реквизиты и настройки', ''),
]
ADM_MENU = [
  ('sec', 'Пилот: Ош'),
  ('services', 'building', 'Службы', '<i class="n">7</i>'),
  ('unmatched', 'alert', 'Платежи без сопоставления', '<i>3</i>'),
  ('allpay', 'coins', 'Все платежи', ''),
  ('support', 'chat', 'Обращения жителей', ''),
  ('sec', 'Система'),
  ('accessadm', 'shield', 'Доступы и журнал', ''),
  ('settings', 'gear', 'Настройки', ''),
]

def side(kind, active):
    if kind == 'svc':
        menu, title, org = SVC_MENU, 'Кабинет службы', (
            '<div class="org">%s<div class="grow"><b>Ошводоканал</b><small>Холодная вода · Ош</small></div></div>'
            % catbox('water', 'water'))
        me = '<div class="me"><span class="av">ЖТ</span><div><b>Жыпар Турсунова</b><small>Сотрудник службы</small></div></div>'
    else:
        menu, title, org = ADM_MENU, 'Администратор', (
            '<div class="org"><span class="ic" style="background:#1FB886">%s</span><div class="grow"><b>ЭлPay</b><small>Управление пилотом</small></div></div>'
            % icon('shield'))
        me = '<div class="me"><span class="av">АК</span><div><b>Азамат Кадыров</b><small>Администратор ЭлPay</small></div></div>'
    out = ['<aside class="side"><div class="logo"><b>Эл</b><div><span>ЭлPay</span><small>%s</small></div></div>' % title, org,
           '<nav class="menu">']
    for m in menu:
        if m[0] == 'sec':
            out.append('<div class="sec">%s</div>' % m[1])
            continue
        key, ico, label, badge = m
        out.append('<a class="%s">%s%s%s</a>' % ('on' if key == active else '', icon(ico), label, badge))
    out.append('</nav>%s</aside>' % me)
    return ''.join(out)

def top(spec):
    parts = spec.split('|')
    title = parts[0]
    crumbs = parts[1] if len(parts) > 1 else ''
    c = '<div class="crumbs">%s</div>' % crumbs if crumbs else ''
    return ('<header class="top"><div>%s<h2>%s</h2></div><div class="grow"></div>'
            '<div class="search">%s Лицевой счёт, ФИО или адрес</div>'
            '<div class="period">%s Сентябрь 2026 %s</div></header>' % (c, title, icon('search'), icon('cal'), icon('down')))

TEXT = re.compile(r'>([^<]+)<')

def nbsp(html):
    """Неразрывный пробел в числах и перед единицами: «1 905» и «205 сом»
    не должны разрываться переносом строки. Только в тексте, не в атрибутах."""
    def fix(m):
        t = m.group(1)
        t = re.sub(r'(\d) (?=\d{3}\b)', '\\1\u00a0', t)
        t = re.sub(r'(\d) (?=(сом|чел|абонент|строк|платеж|дн|мин|%))', '\\1\u00a0', t)
        return '>' + t + '<'
    prev = None
    while prev != html:          # «12 480 000» требует двух проходов
        prev, html = html, TEXT.sub(fix, html)
    return html

def expand(html):
    html = re.sub(r'\{\{i:(\w+)\}\}', lambda m: icon(m.group(1)), html)
    html = re.sub(r'\{\{ic:(\w+):(\w+)\}\}', lambda m: catbox(m.group(1), m.group(2)), html)
    html = re.sub(r'\{\{side:(svc|adm):(\w+)\}\}', lambda m: side(m.group(1), m.group(2)), html)
    html = re.sub(r'\{\{top:([^}]*)\}\}', lambda m: top(m.group(1)), html)
    return nbsp(html)

META = re.compile(r'^\s*<!--\s*group:\s*(.*?)\s*\|\s*cap:\s*(.*?)\s*\|\s*sub:\s*(.*?)\s*-->', re.S)

def main():
    here = os.path.dirname(os.path.abspath(__file__))
    files = sorted(glob.glob(os.path.join(here, 'screens', '*.html')))
    sections, toc, last_group = [], [], None
    for f in files:
        raw = io.open(f, encoding='utf-8').read()
        m = META.match(raw)
        if not m:
            raise SystemExit('нет строки метаданных: ' + f)
        group, cap, sub = m.groups()
        body = expand(raw[m.end():])
        no = os.path.basename(f).split('-')[0]
        if group != last_group:
            sections.append('<div class="group">%s</div>' % group)
            last_group = group
        sections.append('<section class="item" id="s%s"><div class="cap"><span class="no">%s</span>%s<span>%s</span></div>%s</section>'
                        % (no, no, cap, sub, body))
        toc.append('<a href="#s%s">%s · %s</a>' % (no, no, cap))
    page = ('<!doctype html><html lang="ru"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=1520">'
            '<title>Кабинет служб ЭлPay</title><link rel="stylesheet" href="admin.css"></head><body>'
            '<div class="intro"><h1>Кабинет служб ЭлPay — концепт</h1>'
            '<p>Веб-кабинет для водоканала, электросети, садиков и других служб: служба сама добавляет абонентов '
            '(выгрузкой из 1С или вручную), раз в месяц загружает начисления, видит, кто оплатил, выгружает реестр '
            'платежей обратно в 1С и напоминает должникам. Админ ЭлPay заводит службы и разбирает спорные платежи. '
            'Все цифры вымышленные и сходятся между экранами: см. DATA.md.</p>'
            '<div class="toc">%s</div></div>%s</body></html>' % (''.join(toc), ''.join(sections)))
    # Через временный файл: экраны собирают параллельно, и снимок не должен
    # прочитать наполовину записанную страницу.
    tmp = os.path.join(here, '.index.%d.tmp' % os.getpid())
    io.open(tmp, 'w', encoding='utf-8').write(page)
    os.replace(tmp, os.path.join(here, 'index.html'))
    print('экранов:', len(files))

if __name__ == '__main__':
    main()
