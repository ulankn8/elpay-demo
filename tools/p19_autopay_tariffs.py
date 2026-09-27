# -*- coding: utf-8 -*-
"""ЭлPay v3.2 — автоплатёж по счёту и экран «Тарифы и комиссии»."""
import io, json

P = 'index.html'
s = io.open(P, encoding='utf-8').read()


def rep(old, new, cnt=1):
    global s
    n = s.count(old)
    assert n == cnt, 'expected %d, found %d: %r' % (cnt, n, old[:110])
    s = s.replace(old, new)


CSS = """
/* ===== Тарифы ===== */
.tar{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;padding:13px 0}
.tar+.tar{border-top:1px solid var(--line2)}
.tar .mid b{display:block;font-size:14px;font-weight:600}
.tar .mid span{display:block;font-size:12.5px;color:var(--muted);line-height:1.4}
.tar .v{flex:none;font-size:14px;font-weight:700;color:var(--p700);white-space:nowrap}
"""
END = '.hfil button .dt{width:8px;height:8px;border-radius:50%}\n</style>'
rep(END, '.hfil button .dt{width:8px;height:8px;border-radius:50%}' + CSS + '</style>')

rep("pinOn:0,bioOn:1,pin:'4815'", "pinOn:0,bioOn:1,auto:{},pin:'4815'")

# автоплатёж в карточке счёта
rep("""    ${dspBlock(b)}""",
    """    ${b.tpl||b.tax?'':`<div class="swrow"><span>${tx('Автоплатёж 25-го числа')}</span><button class="sw" role="switch" aria-checked="${!!st.auto[b.id]}" aria-label="Автоплатёж" data-act="auto-sw" data-id="${b.id}"></button></div>`}
    ${dspBlock(b)}""")

# отметка в списке реквизитов
rep("""<span class="s">${F.acc(c.acc)}${st.obj.length>1?' · '+objName(whoOf(c)):''}</span>""",
    """<span class="s">${F.acc(c.acc)}${st.auto[c.id]?' · '+tx('автоплатёж'):''}${st.obj.length>1?' · '+objName(whoOf(c)):''}</span>""")

# тарифы в профиле
rep("""                <button class="row" data-act="setlang" data-lang="toggle">""",
    """                <button class="row" data-act="tariffs"><span class="tile"><i data-i="banknote"></i></span><span class="mid"><span class="t">Тарифы и комиссии</span><span class="s">Сколько стоит платёж и на чём зарабатывает ЭлPay</span></span><i data-i="chevron-right" data-s="18"></i></button>
                <button class="row" data-act="setlang" data-lang="toggle">""")

JS = r"""/* ===== Автоплатёж и тарифы ===== */
const TARIFFS=[
 ['Коммунальные платежи','Вода, свет, мусор, газ, интернет','0 сом'],
 ['Садик, школа, курсы','Оплата по шаблону с реквизитами','0 сом'],
 ['Налоги и патент','Начисления по ИНН','0 сом'],
 ['Пополнение кошелька','С карты любого банка','0 сом'],
 ['Билеты в маркете','Комиссия площадки уже в цене билета','5%'],
 ['Квитанции и выписки','PDF и CSV, без ограничений','0 сом']];
function tariffsSheet(){
  openSheet(tx('Тарифы и комиссии'),`<p class="sub">Для пользователя переводы бесплатны. ЭлPay зарабатывает на комиссии поставщиков и билетах маркета.</p>
   <div class="rep-card" style="margin-top:14px">${TARIFFS.map(([t,s2,v])=>`<div class="tar"><span class="mid"><b>${t}</b><span>${s2}</span></span><span class="v">${v}</span></div>`).join('')}</div>
   <div class="tip">${ic('info',18)}<span>Поставщик платит 0,8% с принятого платежа — это дешевле, чем содержать кассу и бумажные квитанции.</span></div>
   <button class="btn btn-s" data-act="toast" data-msg="Публичная оферта откроется на сайте elpay.kg">${ic('receipt',20)}Публичная оферта</button>
   <button class="btn btn-g" data-act="close">Понятно</button>`,'tar');
}
const TARACT={
  tariffs:()=>tariffsSheet(),
  'auto-sw':t=>{
    const id=t.dataset.id,on=!st.auto[id];
    if(on)st.auto[id]=25;else delete st.auto[id];
    t.setAttribute('aria-checked',String(on));renderAll();
    toast(on?F.autopayOn(25):'Автоплатёж выключен');
  }
};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT);",
    "Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT);")

PAIRS = [
 ('Автоплатёж 25-го числа', 'Ар айдын 25инде автотөлөм'),
 ('Автоплатёж выключен', 'Автотөлөм өчүрүлдү'),
 ('автоплатёж', 'автотөлөм'),
 ('Тарифы и комиссии', 'Тарифтер жана комиссиялар'),
 ('Сколько стоит платёж и на чём зарабатывает ЭлPay', 'Төлөм канча турат жана ЭлPay эмнеден киреше алат'),
 ('Для пользователя переводы бесплатны. ЭлPay зарабатывает на комиссии поставщиков и билетах маркета.',
  'Колдонуучу үчүн которуулар акысыз. ЭлPay камсыздоочулардын комиссиясынан жана маркет билеттеринен киреше алат.'),
 ('Коммунальные платежи', 'Коммуналдык төлөмдөр'),
 ('Вода, свет, мусор, газ, интернет', 'Суу, жарык, таштанды, газ, интернет'),
 ('Садик, школа, курсы', 'Бала бакча, мектеп, курстар'),
 ('Оплата по шаблону с реквизитами', 'Реквизиттери бар шаблон боюнча төлөм'),
 ('Налоги и патент', 'Салыктар жана патент'),
 ('Начисления по ИНН', 'ИНН боюнча эсептөөлөр'),
 ('Пополнение кошелька', 'Капчыкты толуктоо'),
 ('С карты любого банка', 'Каалаган банктын картасынан'),
 ('Билеты в маркете', 'Маркеттеги билеттер'),
 ('Комиссия площадки уже в цене билета', 'Аянтчанын комиссиясы билеттин баасына кирген'),
 ('Квитанции и выписки', 'Квитанциялар жана көчүрмөлөр'),
 ('PDF и CSV, без ограничений', 'PDF жана CSV, чектөөсүз'),
 ('Поставщик платит 0,8% с принятого платежа — это дешевле, чем содержать кассу и бумажные квитанции.',
  'Камсыздоочу кабыл алынган төлөмдөн 0,8% төлөйт — бул касса менен кагаз квитанцияларды кармагандан арзан.'),
 ('Публичная оферта', 'Ачык оферта'),
 ('Публичная оферта откроется на сайте elpay.kg', 'Ачык оферта elpay.kg сайтында ачылат'),
]
i = s.find('const KY=')
j = s.find(';\n', i)
KY = json.loads(s[i + len('const KY='):j])
added = 0
for ru, kyt in PAIRS:
    if ru not in KY:
        KY[ru] = kyt
        added += 1
s = s[:i + len('const KY=')] + json.dumps(KY, ensure_ascii=False, separators=(',', ':')) + s[j:]

io.open(P, 'w', encoding='utf-8').write(s)
print('ok, ky added:', added, 'size:', len(s))
