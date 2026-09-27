# -*- coding: utf-8 -*-
"""Собирает HTML-концепт новых экранов ЭлPay (v4)."""
import io

I = {
 'water':'<path d="M12 3s6 6.2 6 10a6 6 0 1 1-12 0c0-3.8 6-10 6-10Z"/>',
 'power':'<path d="M13 2 4.5 13H11l-1 9 8.5-11H12l1-9Z"/>',
 'trash':'<path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13"/>',
 'kid':'<circle cx="12" cy="12" r="8"/><path d="M9.5 15c1.6 1.2 3.4 1.2 5 0"/><circle cx="9.6" cy="10.6" r=".9" stroke="none" fill="currentColor"/><circle cx="14.4" cy="10.6" r=".9" stroke="none" fill="currentColor"/>',
 'school':'<path d="M12 4 3 9l9 5 9-5-9-5Z"/><path d="M7 12v5c0 1.5 2.4 3 5 3s5-1.5 5-3v-5"/>',
 'net':'<path d="M2.5 9a14 14 0 0 1 19 0M6 12.5a9 9 0 0 1 12 0M9.5 16a4 4 0 0 1 5 0"/><circle cx="12" cy="19.5" r=".9" stroke="none" fill="currentColor"/>',
 'gas':'<path d="M12 3c3 4 6 5.5 6 9a6 6 0 1 1-12 0c0-2 1-3.4 2.5-4.6"/>',
 'tax':'<path d="M3.5 9 12 4l8.5 5"/><path d="M5 10v8M19 10v8M9.5 10v8M14.5 10v8M3.5 20h17"/>',
 'mobile':'<rect x="7" y="3" width="10" height="18" rx="3"/><path d="M11 18h2"/>',
 'home':'<path d="M4 11 12 4l8 7"/><path d="M6 10v9h12v-9"/>',
 'users':'<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19c.6-3 2.9-4.6 5.5-4.6S14 16 14.6 19"/><path d="M16.2 5.6a3.2 3.2 0 0 1 0 6.2"/><path d="M17.2 14.7c2 .5 3.4 2 3.8 4.3"/>',
 'cal':'<rect x="3.5" y="5" width="17" height="15" rx="3"/><path d="M8 3v4M16 3v4M3.5 10h17"/>',
 'plus':'<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>',
 'arrow':'<path d="M5 12h13M13 7l5 5-5 5"/>',
 'qr':'<rect x="3.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5"/><path d="M13.5 14h3v3h-3zM19.5 13.5v2M19.5 19v1.5M14 20.5h2.5"/>',
 'doc':'<path d="M6.5 3h7l4 4v14h-11z"/><path d="M13.5 3v4h4M9.5 12h5M9.5 16h5"/>',
 'chev':'<path d="m9 5 7 7-7 7"/>',
 'back':'<path d="M19 12H5M11 6l-6 6 6 6"/>',
 'bell':'<path d="M18 16V11a6 6 0 1 0-12 0v5l-1.6 2.6h15.2L18 16Z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
 'pin':'<path d="M12 21s7-6.2 7-11a7 7 0 1 0-14 0c0 4.8 7 11 7 11Z"/><circle cx="12" cy="10" r="2.5"/>',
 'card':'<rect x="3" y="6" width="18" height="13" rx="3"/><path d="M3 10.5h18"/>',
 'chart':'<path d="M5 19V9M12 19V5M19 19v-7"/>',
 'person':'<circle cx="12" cy="8" r="3.6"/><path d="M4.5 20c.8-3.8 3.7-5.8 7.5-5.8s6.7 2 7.5 5.8"/>',
 'check':'<path d="m5 12.5 4.5 4.5L19 7"/>',
 'info':'<circle cx="12" cy="12" r="9"/><path d="M12 11v5.5M12 7.8v.2"/>',
 'gauge':'<circle cx="12" cy="12" r="8.5"/><path d="M12 12l4.2-3.2M12 4v1.5M20 12h-1.5M12 20v-1.5M4 12h1.5"/>',
 'save':'<path d="M5 5h11l3 3v11H5z"/><path d="M8 5v5h7V5M8 19v-5h8v5"/>',
 'bolt2':'<path d="M13 3 6 13h5l-1 8 7-10h-5l1-8Z"/>',
 'close':'<path d="M6 6l12 12M18 6 6 18"/>',
}

def svg(name, cls=''):
    return '<svg viewBox="0 0 24 24"%s>%s</svg>' % ((' class="%s"' % cls) if cls else '', I[name])

def ic(cat, name, size=44, radius=12):
    return ('<span class="ic" style="width:%dpx;height:%dpx;border-radius:%dpx;background:var(--g-%s)">%s</span>'
            % (size, size, radius, cat, svg(name)))

def ic_soft(cat, name, size=44, radius=12):
    tint = {'water':'#3F7BE0','power':'#C9902B','trash':'#F0643F','kid':'#E0428D','school':'#5B45D9',
            'net':'#6B7EE0','gas':'#C0553F','tax':'#3C4A55','mobile':'#1FA894'}[cat]
    return ('<span class="ic soft" style="width:%dpx;height:%dpx;border-radius:%dpx;background:%s1F;color:%s">%s</span>'
            % (size, size, radius, tint, tint, svg(name)))

NAV = ('<div class="nav">'
       '<div class="on"><span class="n">%s</span>Главная</div>'
       '<div><span class="n">%s</span>Платежи</div>'
       '<div><span class="n">%s</span>Отчёты</div>'
       '<div><span class="n">%s</span>Профиль</div></div>'
       % (svg('home'), svg('card'), svg('chart'), svg('person')))

HEAD = ('<div class="head">'
        '<div class="ava">АЙ</div>'
        '<div class="grow"><div class="name">Салам, Айгерим</div>'
        '<div class="addr">%s ул. Курманжан Датка, 212, кв. 14</div></div>'
        '<div class="bell">%s<b>2</b></div></div>'
        % (svg('pin').replace('<svg', '<svg style="width:13px;height:13px;stroke:var(--mut);fill:none;stroke-width:2"'),
           svg('bell').replace('<svg', '<svg style="width:23px;height:23px;stroke:var(--ink);fill:none;stroke-width:1.8"')))

STORIES = [
 ('linear-gradient(160deg,#3F7BE0,#2456B0)', 'Сегодня', 'Завтра<br>без воды', 3, 1, 'water'),
 ('linear-gradient(160deg,#F6C453,#E08A2F)', 'Срок', 'Оплатите<br>до 25-го', 2, 1, 'power'),
 ('linear-gradient(160deg,#FF7DBE,#D62F82)', 'Садик', 'Октябрь<br>уже открыт', 3, 1, 'kid'),
 ('linear-gradient(160deg,#46BEDC,#1F8EAE)', 'Афиша', 'Концерт<br>3 октября', 2, 1, 'school'),
 ('linear-gradient(160deg,#1FB886,#05804F)', 'Совет', 'Счёт<br>за минуту', 3, 1, 'net'),
]

def story_card(i, s):
    bg, tag, txt, n, on, cat = s
    bars = ''.join('<i class="%s"></i>' % ('on' if k < on else '') for k in range(n))
    deco = ('<svg viewBox="0 0 120 170" style="position:absolute;inset:0;width:100%;height:100%;opacity:.28">'
            '<circle cx="96" cy="34" r="38" fill="#fff"/><circle cx="18" cy="112" r="26" fill="#fff" opacity=".6"/></svg>')
    ring = ' ring' if i == 0 else ''
    return ('<div class="story%s" style="background:%s">%s<div class="bars">%s</div>'
            '<div class="tag">%s</div><div class="txt">%s</div></div>' % (ring, bg, deco, bars, tag, txt))

HOME_STORIES = '<div class="stories">%s</div>' % ''.join(story_card(i, s) for i, s in enumerate(STORIES))

def hero(name, icon, cnt, due, amount, paid, parts, alt=False):
    bar = ''.join('<span style="width:%s;background:%s"></span>' % (w, c) for _, w, c, _ in parts)
    leg = ''.join('<b><i style="background:%s"></i>%s <u>%s</u></b>' % (c, t, v)
                  for t, _, c, v in parts if t)
    return ('<div class="hero%s"><div class="top"><span class="box">%s</span><b>%s</b><span>%s</span></div>'
            '<div class="lab">К оплате <span class="due">%s срок %s</span></div>'
            '<div class="big">%s<i>сом</i></div><div class="cnt">%s</div>'
            '<div class="bar">%s</div><div class="leg">%s</div>'
            '<div class="act">Оплатить %s</div></div>'
            % (' b' if alt else '', svg(icon), name, cnt,
               svg('cal').replace('<svg', '<svg style="width:13px;height:13px;stroke:#fff;fill:none;stroke-width:2"'),
               due, amount, paid, bar, leg,
               svg('arrow').replace('<svg', '<svg style="width:18px;height:18px;stroke:var(--onp);fill:none;stroke-width:2.2"')))

HERO_HOME = hero('Дом', 'home', '4 счёта', '25 сент', '4 919,44', '4 счёта · оплачено 0 из 4', [
    ('Садик', '71%', '#E0428D', '3 500'),
    ('Свет', '11.5%', '#E0A93F', '564,44'),
    ('Вода', '4.2%', '#3F7BE0', '205'),
    ('Мусор', '3.6%', '#F0643F', '180'),
    ('', '9.7%', 'rgba(255,255,255,.18)', ''),
])
HERO_PAR = hero('Родители', 'users', '2 счёта', '20 сент', '470', '2 счёта · оплачено 0 из 2', [
    ('Свет', '68%', '#E0A93F', '320'),
    ('Вода', '32%', '#3F7BE0', '150'),
], alt=True)
HERO_PAR = HERO_PAR.replace('<div class="leg">', '<div class="leg">').replace('<b><i style="background:rgba', '<b style="display:none"><i style="background:rgba')

SVC_ROW = ('<div class="svcs">'
  + ''.join('<div class="svc"><span class="c" style="background:var(--g-%s)">%s</span><span>%s</span></div>'
            % (cat, svg(icon), label)
            for cat, icon, label in [('water','water','Вода'), ('power','power','Свет'), ('trash','trash','Мусор'),
                                     ('kid','kid','Садик'), ('school','school','Школа'), ('net','net','Интернет')])
  + '</div>')

def screen(body, extra=''):
    return '<div class="screen"%s>%s</div>' % (extra, body)

def item(cap, sub, body, extra=''):
    return ('<div class="item"><div class="cap">%s<span>%s</span></div>%s</div>'
            % (cap, sub, screen(body, extra)))

SCREENS = []

# ── 1. Главная ────────────────────────────────────────────────
SCREENS.append(item('1. Главная', 'Сторисы сверху, карточки объектов в середине, «Новая оплата» и услуги — внизу. Ленты «Мои счета» больше нет.',
  HEAD + HOME_STORIES
  + '<div style="height:14px"></div>'
  + '<div class="heroes">%s%s</div>' % (HERO_HOME, HERO_PAR)
  + '<div class="dots"><i class="on"></i><i></i></div>'
  + '<div class="pad" style="margin-top:16px"><div class="btn ghost">%s Новая оплата</div></div>'
    % svg('plus').replace('<svg', '<svg style="width:20px;height:20px;stroke:var(--p7);fill:none;stroke-width:1.9"')
  + '<div style="height:16px"></div>' + SVC_ROW
  + NAV))

# ── 2. Сторис ─────────────────────────────────────────────────
_close = svg('close').replace('<svg', '<svg style="width:22px;height:22px;stroke:#fff;fill:none;stroke-width:2"')
_drop = svg('water').replace('<svg', '<svg style="width:46px;height:46px;stroke:#fff;fill:none;stroke-width:1.6"')
story_full = (
  '<div style="position:absolute;inset:0;background:linear-gradient(165deg,#3F7BE0 0%,#2456B0 60%,#123C86 100%)">'
  '<svg viewBox="0 0 393 852" style="position:absolute;inset:0;width:100%;height:100%;opacity:.3">'
  '<circle cx="330" cy="150" r="150" fill="#fff"/><circle cx="60" cy="470" r="110" fill="#fff" opacity=".55"/>'
  '<circle cx="300" cy="640" r="70" fill="#fff" opacity=".4"/></svg>'
  '<div style="position:absolute;left:14px;right:14px;top:14px;display:flex;gap:4px">'
  '<i style="flex:1;height:3px;border-radius:2px;background:#fff"></i>'
  '<i style="flex:1;height:3px;border-radius:2px;background:rgba(255,255,255,.4)"></i>'
  '<i style="flex:1;height:3px;border-radius:2px;background:rgba(255,255,255,.4)"></i></div>'
  '<div style="position:absolute;left:18px;right:18px;top:32px;display:flex;align-items:center;gap:10px;color:#fff">'
  '<span style="width:30px;height:30px;border-radius:9px;background:rgba(255,255,255,.2);display:flex;'
  'align-items:center;justify-content:center;font-weight:700;font-size:12px">ЭП</span>'
  '<b style="font-size:13.5px;font-weight:700">Ошводоканал</b>'
  '<span style="font-size:12px;color:rgba(255,255,255,.7)">2 ч назад</span>'
  '<span style="margin-left:auto">' + _close + '</span></div>'
  '<div style="position:absolute;left:24px;right:24px;top:170px;color:#fff">'
  '<div style="width:96px;height:96px;border-radius:28px;background:rgba(255,255,255,.18);display:flex;'
  'align-items:center;justify-content:center;margin-bottom:26px">' + _drop + '</div>'
  '<div style="font-size:34px;font-weight:700;line-height:1.14;letter-spacing:-.8px">Завтра без<br>холодной воды</div>'
  '<div style="font-size:16px;line-height:1.5;margin-top:16px;color:rgba(255,255,255,.88)">'
  'С 10:00 до 17:00 на ул. Курманжан Датка — плановый ремонт сети.<br><br>'
  'Наберите воду заранее. Если воды не будет дольше, напишем ещё раз.</div></div>'
  '<div style="position:absolute;left:20px;right:20px;bottom:34px">'
  '<div class="btn" style="background:#fff;color:#14222A">Смотреть адреса</div>'
  '<div style="text-align:center;color:rgba(255,255,255,.75);font-size:12.5px;margin-top:14px">'
  '1 из 3 · листайте вправо</div></div></div>')
SCREENS.append(item('2. Сторис на весь экран', 'В одной рамке до трёх кадров — полоски сверху. Иллюстрация, текст и кнопка-ссылка.', story_full))

# ── 3. Объект «Дом» ───────────────────────────────────────────
def bill_row(cat, icon, title, sub, amount, checked=True, due_cls='', due=''):
    return ('<div class="row" style="align-items:flex-start;padding:14px 16px">'
      '<span class="check%s" style="margin-top:2px">%s</span>' % (' on' if checked else '', svg('check') if checked else '')
      + ic_soft(cat, icon, 42, 12)
      + '<div class="grow">'
        '<div style="display:flex;align-items:baseline;gap:10px">'
        '<div class="h3 grow ell">%s</div><div class="amt">%s<i>сом</i></div></div>'
        '<div class="sub ell" style="margin-top:2px">%s</div>'
        '<div style="display:flex;align-items:center;gap:10px;margin-top:10px">'
        '<span class="chip %s">%s</span><span class="grow"></span>'
        '<span class="pill">Оплатить</span></div>'
        '</div></div>' % (title, amount, sub, due_cls, due))

obj_screen = ('<div class="appbar"><span class="b">%s</span><span class="t">Дом</span></div>' % svg('back')
  + '<div class="pad">'
  + '<div class="card" style="padding:16px 16px 14px;margin-bottom:14px">'
    '<div style="display:flex;align-items:center;gap:10px">'
    + ic_soft('water', 'home', 40, 12)
    + '<div class="grow"><div class="h3">Дом</div><div class="sub">ул. Курманжан Датка, 212, кв. 14</div></div></div>'
    '<div style="display:flex;align-items:flex-end;justify-content:space-between;margin-top:14px">'
    '<div><div class="tiny">К оплате</div>'
    '<div style="font-size:28px;font-weight:700;letter-spacing:-.8px;margin-top:2px">4 919,44<i style="font-style:normal;font-size:14px;color:var(--mut);font-weight:600;margin-left:4px">сом</i></div></div>'
    '<span class="chip warn">срок 25 сент</span></div></div>'
  + '<div style="display:flex;align-items:center;gap:10px;margin:2px 2px 10px">'
    '<span class="check on">%s</span>' % svg('check')
  + '<div class="grow" style="font-size:13.5px;font-weight:600">Выбраны все 4 счёта</div>'
    '<div style="font-size:13px;font-weight:700;color:var(--p7)">Снять все</div></div>'
  + '<div class="card">'
  + bill_row('kid', 'kid', 'Садик «Балапан»', 'Амир · сентябрь · Д-2291', '3 500', True, 'soft', 'до 5 окт')
  + bill_row('power', 'power', 'Электросеть', 'Электроэнергия · 7710-3348', '564,44', True, 'bad', 'просрочено · 2 дня')
  + bill_row('water', 'water', 'Водоканал', 'Холодная вода · 31-00562', '205', True, 'bad', 'просрочено · 2 дня')
  + bill_row('trash', 'trash', 'Ош-Тазалык', 'Вывоз мусора · 04-118725', '180', True, 'warn', 'осталось 1 день')
  + '</div></div>'
  + '<div class="bottombar"><div class="total"><b>Итого</b><div class="v">4 919,44<i>сом</i></div></div>'
    '<div class="btn">Оплатить всё · 4 919,44 сом</div></div>')
SCREENS.append(item('3. Объект «Дом»', 'Кнопка на карточке объекта ведёт сюда. Галочки у всех, у каждой услуги своя кнопка «Оплатить», внизу — «Оплатить всё».', obj_screen))

# ── 4. Услуга: вода ───────────────────────────────────────────
def svc_screen(title, cat, icon, sub, amount, chip, chip_cls, kv, calc_title, calc, req):
    return ('<div class="appbar"><span class="b">%s</span><span class="t">%s</span></div>' % (svg('back'), title)
      + '<div class="pad" style="padding-bottom:150px">'
      + '<div class="card" style="padding:18px 16px 16px;text-align:center">'
      + ic(cat, icon, 56, 16).replace('<span class="ic"', '<span class="ic" ').replace('style="width:56px', 'style="margin:0 auto;width:56px')
      + '<div class="h2" style="margin-top:10px">%s</div>' % title
      + '<div class="sub" style="margin-top:3px">%s</div>' % sub
      + '<div style="font-size:32px;font-weight:700;letter-spacing:-1px;margin-top:12px">%s'
        '<i style="font-style:normal;font-size:15px;color:var(--mut);font-weight:600;margin-left:4px">сом</i></div>'
        '<div style="margin-top:10px"><span class="chip %s">%s</span></div></div>' % (amount, chip_cls, chip)
      + '<div class="h3" style="margin:18px 2px 9px">За что платим</div>'
      + '<div class="kv">%s</div>' % ''.join('<div><span>%s</span><b>%s</b></div>' % kvp for kvp in kv)
      + '<div class="h3" style="margin:18px 2px 9px">%s</div>' % calc_title
      + '<div class="kv">%s</div>' % ''.join('<div><span>%s</span><b>%s</b></div>' % c for c in calc)
      + '<div class="h3" style="margin:18px 2px 9px">Реквизиты платежа</div>'
      + '<div class="card">%s</div>' % ''.join(
            '<div class="row" style="padding:11px 16px"><div class="grow">'
            '<div class="tiny" style="font-weight:600;color:var(--mut)">%s</div>'
            '<div style="font-size:13.5px;font-weight:600;margin-top:2px">%s</div></div>%s</div>'
            % (r[0], r[1], svg('save').replace('<svg', '<svg style="width:17px;height:17px;stroke:var(--mut2);fill:none;stroke-width:1.8"'))
            for r in req)
      + '</div>'
      + '<div class="bottombar"><div class="total"><b>К оплате</b><div class="v">%s<i>сом</i></div></div>'
        '<div class="btn">Оплатить %s сом</div></div>' % (amount, amount))

water = svc_screen('Водоканал', 'water', 'water', 'Холодная вода · сентябрь 2026', '205', 'просрочено · 2 дня', 'bad',
  [('Адрес', 'ул. Курманжан Датка, 212, кв. 14'), ('Лицевой счёт', '31-00562'), ('Оплатить до', '20 сентября')],
  'Как начислено',
  [('Тариф', '41 сом с человека'), ('Проживающих', '5 человек'), ('Начислено', '205 сом')],
  [('Получатель', 'МП «Ошводоканал»'), ('ИНН', '02212199410063'), ('Расчётный счёт', '1091820110330281')])
SCREENS.append(item('4. Услуга «Вода»', 'Кнопка «Оплатить» у строки открывает это: за что, как начислено (жильцы × тариф) и реквизиты. Оплата — только снизу.', water))

power = svc_screen('Электросеть', 'power', 'power', 'Электроэнергия · сентябрь 2026', '564,44', 'просрочено · 2 дня', 'bad',
  [('Адрес', 'ул. Курманжан Датка, 212, кв. 14'), ('Лицевой счёт', '7710-3348'), ('Оплатить до', '25 сентября')],
  'Как начислено',
  [('Показания', '14 208 → 14 332'), ('Расход', '124 кВт·ч'), ('Тариф', '4,55 сом за кВт·ч'), ('Начислено', '564,44 сом')],
  [('Получатель', 'ОАО «Ошэлектро»'), ('ИНН', '02905199510045'), ('Расчётный счёт', '1091820100580127')])
SCREENS.append(item('5. Услуга «Свет»', 'Тот же экран, но расчёт другой: показания счётчика, расход в кВт·ч и тариф.', power))

# ── 6. Способ оплаты ──────────────────────────────────────────
def method_tile(badge, title, sub, on=False):
    return ('<div style="display:flex;align-items:center;gap:12px;padding:12px 14px;border-radius:16px;margin-bottom:8px;'
            'border:1.5px solid %s;background:%s">'
            '<span class="bank"%s>%s</span><div class="grow"><div class="h3">%s</div><div class="sub">%s</div></div>'
            '<span class="radio%s"></span></div>'
            % ('var(--p)' if on else 'var(--line)', 'rgba(235,248,242,.6)' if on else '#fff',
               ' style="background:var(--p7)"' if badge == 'ЭЛПЕЙ' else '', badge, title, sub, ' on' if on else ''))

method = ('<div style="filter:blur(0px)">' + water.split('<div class="bottombar">')[0] + '</div>'
  + '<div class="dim"></div>'
  + '<div class="sheet"><div class="grab"></div>'
    '<div class="h2" style="margin-bottom:4px">Чем оплатить</div>'
    '<div class="sub" style="margin-bottom:16px">По умолчанию — карта из настроек профиля</div>'
  + method_tile('VISA', 'Visa •••• 4417', 'Основная карта из профиля', True)
  + method_tile('ЭЛПЕЙ', 'Кошелёк ЭлPay', 'Баланс 1 240 сом')
  + method_tile('ЭЛКАРТ', 'Элкарт •••• 0921', 'Дополнительная')
  + method_tile('MBANK', 'MBANK', 'Списание со счёта в банке')
  + '<div style="height:6px"></div>'
    '<div class="btn">Оплатить 205 сом</div></div>')
SCREENS.append(item('6. Чем оплатить', 'Способ спрашиваем на последнем шаге. Подставлен тот, что выбран в профиле, — меняется здесь же.', method))

# ── 7. Новая оплата ───────────────────────────────────────────
def big_choice(cat, icon, title, sub):
    return ('<div style="display:flex;align-items:center;gap:14px;padding:16px;border-radius:18px;border:1.5px solid var(--line);margin-bottom:10px">'
            + ic(cat, icon, 48, 14)
            + '<div class="grow"><div class="h3" style="font-size:15.5px">%s</div><div class="sub" style="margin-top:2px">%s</div></div>%s</div>'
            % (title, sub, svg('chev').replace('<svg', '<svg style="width:19px;height:19px;stroke:var(--mut2);fill:none;stroke-width:2"')))

home_body = (HEAD + HOME_STORIES + '<div style="height:14px"></div>'
  + '<div class="heroes">%s</div>' % HERO_HOME
  + '<div class="dots"><i class="on"></i><i></i></div>')

newpay = (home_body + '<div class="dim"></div>'
  + '<div class="sheet"><div class="grab"></div>'
    '<div class="h2" style="margin-bottom:16px">Новая оплата</div>'
  + big_choice('power', 'doc', 'По реквизитам', 'Выберите услугу и введите лицевой счёт')
  + big_choice('market', 'qr', 'По QR с квитанции', 'Наведите камеру — реквизиты подставятся сами')
  + '<div style="height:8px"></div></div>')
SCREENS.append(item('7. «Новая оплата»', 'Два пути: по реквизитам или по QR с бумажной квитанции.', newpay))

# ── 8. Выбор услуги ───────────────────────────────────────────
def svc_grid():
    cells = [('water','water','Вода'),('power','power','Свет'),('trash','trash','Мусор'),
             ('kid','kid','Садик'),('school','school','Школа'),('net','net','Интернет'),
             ('gas','gas','Газ'),('mobile','mobile','Связь'),('tax','tax','Налоги')]
    out = '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:14px 8px;margin-top:4px">'
    for cat, icon, label in cells:
        out += ('<div style="text-align:center"><span class="c" style="width:62px;height:62px;border-radius:50%%;'
                'background:var(--g-%s);display:flex;align-items:center;justify-content:center;margin:0 auto 8px;'
                'box-shadow:0 5px 12px rgba(30,42,50,.13)">%s</span>'
                '<span style="font-size:12.5px;font-weight:600;color:var(--ink3)">%s</span></div>'
                % (cat, svg(icon).replace('<svg', '<svg style="width:27px;height:27px;stroke:#fff;fill:none;stroke-width:1.9"'), label))
    return out + '</div>'

pick = ('<div class="appbar"><span class="b">%s</span><span class="t">Что оплачиваем</span></div>' % svg('back')
  + '<div class="pad">'
    '<div class="sub" style="margin:0 2px 18px">Выберите услугу — реквизиты поставщика подставим сами</div>'
  + svc_grid()
  + '<div style="height:22px"></div>'
    '<div class="card" style="padding:14px 16px;display:flex;align-items:center;gap:12px">'
  + ic_soft('tax', 'doc', 42, 12)
  + '<div class="grow"><div class="h3">Другой получатель</div><div class="sub">Если услуги нет в списке — по реквизитам вручную</div></div>%s</div>'
    % svg('chev').replace('<svg', '<svg style="width:19px;height:19px;stroke:var(--mut2);fill:none;stroke-width:2"')
  + '</div>')
SCREENS.append(item('8. Выбор услуги', 'После «по реквизитам» — те же красивые значки. Дальше обычная форма оплаты.', pick))

# ── 9. Форма реквизитов ───────────────────────────────────────
def field(label, value, hint=False):
    return ('<div style="margin-bottom:14px"><div class="tiny" style="margin:0 0 7px 4px;color:var(--mut)">%s</div>'
            '<div style="height:54px;border-radius:16px;border:1.5px solid var(--line);background:#fff;display:flex;'
            'align-items:center;padding:0 16px;font-size:15px;font-weight:%s;color:%s">%s</div></div>'
            % (label, '500' if hint else '600', 'var(--mut2)' if hint else 'var(--ink)', value))

form = ('<div class="appbar"><span class="b">%s</span><span class="t">Водоканал</span></div>' % svg('back')
  + '<div class="pad">'
  + '<div class="card" style="padding:14px 16px;display:flex;align-items:center;gap:12px;margin-bottom:20px">'
  + ic_soft('water', 'water', 42, 12)
  + '<div class="grow"><div class="h3">МП «Ошводоканал»</div><div class="sub">Холодная вода · Ош</div></div>'
    '<div style="font-size:13px;font-weight:700;color:var(--p7)">Изменить</div></div>'
  + field('Лицевой счёт', '31-00562')
  + field('Сумма, сом', '205')
  + '<div style="display:flex;align-items:center;gap:10px;padding:14px 16px;border-radius:16px;background:var(--l2);margin-top:4px">'
  + svg('info').replace('<svg', '<svg style="width:19px;height:19px;stroke:var(--p7);fill:none;stroke-width:1.8;flex:none"')
  + '<div style="font-size:13px;color:var(--p7);line-height:1.45;font-weight:500">Реквизиты подставятся сами. Сумму возьмите из квитанции.</div></div>'
  + '<div style="height:22px"></div>'
    '<label style="display:flex;align-items:center;gap:12px;padding:14px 16px;border-radius:16px;border:1.5px solid var(--line);background:#fff">'
  + '<span class="check on">%s</span>' % svg('check')
  + '<div class="grow"><div class="h3" style="font-size:14px">Сохранить как мой счёт</div>'
    '<div class="sub">Появится в объекте «Дом» и будет приходить каждый месяц</div></div></label>'
  + '</div>'
  + '<div class="bottombar"><div class="btn">Продолжить</div></div>')
SCREENS.append(item('9. Реквизиты', 'Форма с подставленными реквизитами. Галочка «сохранить» превращает разовый платёж в постоянный счёт.', form))

# ── 10. Тап по значку услуги ──────────────────────────────────
tap = (home_body
  + '<div class="pad" style="margin-top:16px"><div class="btn ghost">%s Новая оплата</div></div>'
    % svg('plus').replace('<svg', '<svg style="width:20px;height:20px;stroke:var(--p7);fill:none;stroke-width:1.9"')
  + '<div style="height:16px"></div>' + SVC_ROW
  + '<div class="dim"></div>'
  + '<div class="sheet"><div class="grab"></div>'
    '<div style="display:flex;align-items:center;gap:13px;margin-bottom:18px">'
  + ic('water', 'water', 48, 14)
  + '<div class="grow"><div class="h2">Вода</div><div class="sub">Ошводоканал · холодная вода</div></div></div>'
  + big_choice('paid' if False else 'mobile', 'save', 'Подключить счёт', 'Сохраним реквизиты — счёт будет приходить сам')
  + big_choice('power', 'bolt2', 'Оплатить разово', 'Без сохранения: ввели счёт и сумму — и готово')
  + '<div style="height:8px"></div></div>')
SCREENS.append(item('10. Тап по значку услуги', 'Два сценария на выбор: подключить счёт к ЭлPay или оплатить разово по реквизитам.', tap))

HTML = ('<!doctype html><html lang="ru"><head><meta charset="utf-8">'
        '<title>ЭлPay — концепт v4</title><link rel="stylesheet" href="style.css"></head><body>'
        '<div class="gallery">%s</div></body></html>' % ''.join(SCREENS))
io.open('index.html', 'w', encoding='utf-8').write(HTML)
print('готово, экранов:', len(SCREENS), 'размер:', len(HTML))
