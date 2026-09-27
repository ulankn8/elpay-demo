# -*- coding: utf-8 -*-
"""ЭлPay v3.2 — частичная оплата счёта, сбой платежа с повтором, офлайн-очередь."""
import io, json

P = 'index.html'
s = io.open(P, encoding='utf-8').read()


def rep(old, new, cnt=1):
    global s
    n = s.count(old)
    assert n == cnt, 'expected %d, found %d: %r' % (cnt, n, old[:110])
    s = s.replace(old, new)


# ===================== CSS =====================
CSS = """
/* ===== Частичная оплата, сбой платежа, офлайн ===== */
.gate{z-index:60}
.gate .bright{display:flex;align-items:center;gap:7px;font-size:12px;font-weight:600;color:var(--muted2)}
.offbar{position:absolute;top:calc(var(--sat) + 4px);left:12px;right:12px;z-index:30;display:none;align-items:center;gap:10px;padding:10px 12px;border-radius:15px;background:#2A3942;color:#fff;font-size:12.5px;font-weight:600;line-height:1.3;box-shadow:var(--sh-lg)}
.offbar.on{display:flex;animation:popIn .32s var(--ease)}
.offbar .i{flex:none;opacity:.9}
.offbar span{flex:1}
.offbar button{flex:none;height:30px;padding:0 12px;border-radius:999px;border:1.5px solid rgba(255,255,255,.3);background:transparent;color:#fff;font-size:12px;font-weight:700}
.tip.warn{background:#FDF1E3;color:#8A5B12}
.failring{width:84px;height:84px;margin:4px auto 14px;border-radius:50%;display:grid;place-items:center;background:#FBE9E5;color:var(--danger)}
.pt-sum{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin-top:12px;padding:12px 14px;border-radius:16px;background:var(--soft)}
.pt-sum span{font-size:13px;font-weight:600;color:var(--muted)}
.pt-sum b{font-size:16px;font-weight:700}
"""
rep('</style>', CSS + '</style>')

# ===================== HTML =====================
rep('''          <div class="toast" id="toast" role="status" aria-live="polite"></div>''',
    '''          <div class="offbar" id="offbar" role="status"></div>
          <div class="toast" id="toast" role="status" aria-live="polite"></div>''')

rep('''      <li><button class="scn" data-scn="7"><span class="n">7</span>Билет на концерт и QR на входе<i class="go" data-i="arrow-right" data-s="18"></i></button></li>''',
    '''      <li><button class="scn" data-scn="7"><span class="n">7</span>Билет на концерт и QR на входе<i class="go" data-i="arrow-right" data-s="18"></i></button></li>
      <li><button class="scn" data-scn="8"><span class="n">8</span>Сбой оплаты и повтор<i class="go" data-i="arrow-right" data-s="18"></i></button></li>
      <li><button class="scn" data-scn="9"><span class="n">9</span>Нет сети: платёж в очереди<i class="go" data-i="arrow-right" data-s="18"></i></button></li>''')

# ===================== Состояние =====================
rep("  hist:[],histQ:'',tickets:[],mkF:'all'});",
    "  hist:[],histQ:'',tickets:[],mkF:'all',part:{},queue:[],qd:{},offline:0,failOnce:0});")

# частичная оплата уменьшает остаток по счёту
rep("""  const c=st.custom.map(o=>({...o,cust:1,who:o.who||WHO0,sub:o.rec}));
  return [...u,...k,...x,...c];""",
    """  const c=st.custom.map(o=>({...o,cust:1,who:o.who||WHO0,sub:o.rec}));
  return [...u,...k,...x,...c].map(b=>{const p=st.part&&st.part[b.id];
    return p?{...b,full:b.amount,part:p,amount:Math.max(0,Math.round((b.amount-p)*100)/100)}:b;});""")

# ===================== Значки в лентах =====================
rep("""<span class="amt num">${fmt(b.amount)} <small>сом</small></span>${st.paid[b.id]?okChip():`<span class="chip soft sm">${b.dueShort}</span>`}</span></button>`;""",
    """<span class="amt num">${fmt(b.amount)} <small>сом</small></span>${st.paid[b.id]?okChip():st.qd[b.id]?`<span class="chip info sm">${tx('В очереди')}</span>`:b.part?`<span class="chip warn sm">${tx('Частично')}</span>`:`<span class="chip soft sm">${b.dueShort}</span>`}</span></button>`;""")

rep("""<span class="mid"><span class="t">${b.short}</span><span class="s">${tx(b.dueShort)}</span></span>""",
    """<span class="mid"><span class="t">${b.short}</span><span class="s">${st.qd[b.id]?tx('Отправится, когда появится сеть'):b.part?tx('Остаток по счёту'):tx(b.dueShort)}</span></span>""")

# ===================== Карточка счёта: остаток и «оплатить часть» =====================
rep("""    <div class="kv"><div><span>Период</span><b>${b.period}</b></div>""",
    """    <div class="kv"><div><span>Период</span><b>${b.period}</b></div>${b.part?`<div><span>Уже оплачено</span><b class="num">${fmt(b.part)} сом</b></div>`:''}""")

rep("""`<button class="btn btn-p" data-act="paybill" data-id="${b.id}">${F.pay(fmt(b.amount))}</button>`}`,'bill');""",
    """`<button class="btn btn-p" data-act="paybill" data-id="${b.id}">${F.pay(fmt(b.amount))}</button>
    <button class="btn btn-s" data-act="part-open" data-id="${b.id}">${ic('banknote',20)}Оплатить часть</button>`}`,'bill');""")

# ===================== История платежей одной функцией =====================
rep("""  items.forEach((b,i)=>st.hist.unshift({id:'p'+Date.now()+i,mi:11,cat:svcCat(b),icon:b.icon,name:b.short,sub:b.sub||CATN[svcCat(b)],amount:b.amount,today:1,iso:'2026-09-20',time:TODAY.time,acc:b.acc||'',no:'ЭП-'+(205100+st.hist.length+i)}));st.lastItems=items;""",
    """  histPush(items);st.lastItems=items;""")

# офлайн: платёж уходит в очередь
rep("""async function confirmPay(once){
  const items=once?[once]:[...st.sel].map(billById);if(!items.length)return;
  closeSheet();await wait(260);""",
    """async function confirmPay(once){
  const items=once?[once]:[...st.sel].map(billById);if(!items.length)return;
  if(st.offline)return queuePay(items,once);
  closeSheet();await wait(260);""")

# сбой платежа после Face ID
rep("""  await wait(650);f.classList.remove('on');
  if(!once)items.forEach(b=>st.paid[b.id]=1);""",
    """  await wait(650);f.classList.remove('on');
  if(st.failOnce){st.failOnce=0;FAIL={items,once};return openFail();}
  if(!once)items.forEach(b=>st.paid[b.id]=1);""")

# ===================== Логика =====================
JS = r"""/* ===== Частичная оплата, сбой платежа и офлайн-очередь ===== */
function histPush(items){
  items.forEach((b,i)=>st.hist.unshift({id:'p'+Date.now()+i,mi:11,cat:svcCat(b),icon:b.icon,name:b.short,sub:b.sub||CATN[svcCat(b)],amount:b.amount,today:1,iso:'2026-09-20',time:TODAY.time,acc:b.acc||'',no:'ЭП-'+(205100+st.hist.length+i)}));
}
/* --- частичная оплата --- */
let PART=null;
function partHTML(){
  const b=billById(PART.id);if(!b)return '';
  const q=[['25%',Math.max(1,Math.round(b.amount*.25))],['50%',Math.max(1,Math.round(b.amount*.5))],['75%',Math.max(1,Math.round(b.amount*.75))],['Всё',Math.round(b.amount*100)/100]];
  return `<p class="sub">Счёт можно закрыть не целиком: остаток останется в ленте и попадёт в отчёт.</p>
   <div class="bs-top" style="margin-top:14px">${tile(b)}<div class="mid"><b>${b.short}</b><span>${F.accFull(b.acc||'—')}</span></div></div>
   <div class="pt-sum"><span>Остаток по счёту</span><b class="num">${fmt(b.amount)} сом</b></div>
   <div class="field" style="margin-top:14px"><label for="pt-sum">Сколько заплатить сейчас, сом</label><div class="inp"><input id="pt-sum" inputmode="numeric" value="${PART.v}"></div><p class="hint">Остальное можно оплатить позже или частями</p></div>
   <div class="cities">${q.map(([l,v])=>`<button class="city${PART.v===v?' on':''}" data-act="pt-q" data-v="${v}">${l}</button>`).join('')}</div>
   <button class="btn btn-p" style="margin-top:16px" data-act="pt-go">${F.pay(fmt(PART.v))}</button>
   <p class="legal center">${ic('lock',14)}Поставщик увидит платёж как частичное погашение</p>`;
}
function openPart(id){
  const b=billById(id);if(!b)return;
  PART={id,v:Math.max(1,Math.round(b.amount*.5))};
  const open=()=>openSheet(tx('Оплатить часть'),partHTML(),'part');
  if(st.sheet){closeSheet();setTimeout(open,280);}else open();
}
function partPay(){
  const b=billById(PART.id);if(!b)return;
  const v=parseInt(($('#pt-sum').value||'').replace(/\D/g,''),10)||0;
  $$('#sh-body .field').forEach(f=>f.classList.remove('err'));
  if(v<1)return fErr('#pt-sum','Введите сумму');
  if(v>b.amount)return fErr('#pt-sum','Больше остатка по счёту — '+fmt(b.amount)+' сом');
  const full=v>=b.amount,id=PART.id;PART=null;
  if(full){st.paid[id]=1;delete st.part[id];}
  else st.part[id]=Math.round(((st.part[id]||0)+v)*100)/100;
  confirmPay({id:'pt'+Date.now(),once:1,short:b.short,sub:full?b.sub:'Частичная оплата',icon:b.icon,amount:v,acc:b.acc||''});
}
/* --- сбой платежа --- */
let FAIL=null;
function openFail(){
  const items=FAIL.items,sum=total(items),p=pmById(st.pm);
  openSheet(tx('Платёж не прошёл'),`
   <div class="failring">${ic('triangle-alert',40,2)}</div>
   <p class="sub center">Деньги не списаны. Такое бывает при лимите банка или сбое связи с процессингом.</p>
   <div class="bs-sum num">${fmt(sum)} <small>сом</small></div>
   <div class="kv"><div><span>Способ оплаты</span><b>${tx(p.t)}</b></div><div><span>Причина</span><b>Банк отклонил операцию</b></div><div><span>Код</span><b class="num">51 · лимит по карте</b></div></div>
   <div class="tip warn">${ic('info',18)}<span>Счета остались в ленте. Повторите платёж или выберите другой способ — кошелёк ЭлPay проходит без лимитов.</span></div>
   <button class="btn btn-p" data-act="pay-retry">${ic('refresh-cw',20)}Повторить платёж</button>
   <button class="btn btn-s" data-act="pay-other">${ic('wallet',20)}Другой способ оплаты</button>
   <button class="btn btn-g" data-act="chat-open">${ic('headset',20)}Написать в поддержку</button>`,'fail');
}
function payRetry(){
  const f=FAIL;FAIL=null;if(!f)return;
  closeSheet();setTimeout(()=>confirmPay(f.once),260);
}
function payOther(){
  const f=FAIL;FAIL=null;if(!f)return;
  closeSheet();
  if(f.once)return setTimeout(()=>{st.pm='wallet';renderAll();toast(F.pmSet(tx(pmById('wallet').t)));confirmPay(f.once);},280);
  setTimeout(()=>openCheckout(f.items.map(b=>b.id)),280);
}
/* --- офлайн и очередь --- */
function renderOff(){
  const el=$('#offbar');if(!el)return;
  const n=st.queue.reduce((a,q)=>a+q.items.length,0);
  el.classList.toggle('on',!!st.offline);
  el.innerHTML=st.offline?`${ic('refresh-cw',18)}<span>${n?tx('Нет сети — '+F.qN(n)+' в очереди'):tx('Нет сети — показываем сохранённые данные')}</span><button data-act="net-on">${tx('Обновить')}</button>`:'';
}
function goOffline(){
  st.offline=1;renderOff();toast('Сеть пропала — приложение работает офлайн');
}
function goOnline(){
  if(!st.offline)return;
  st.offline=0;
  const q=st.queue;st.queue=[];st.qd={};
  q.forEach(e=>{
    if(!e.once)e.items.forEach(b=>st.paid[b.id]=1);
    histPush(e.items);
  });
  renderOff();renderAll();
  if(q.length){toast('Сеть появилась — платежи отправлены');setTimeout(()=>showPush('paid',5200),700);}
  else toast('Сеть появилась');
}
function queuePay(items,once){
  closeSheet();
  if(!once)items.forEach(b=>{st.qd[b.id]=1;});
  st.queue.push({items,once:once||null});
  renderAll();renderOff();
  toast('Нет сети — платёж отправится автоматически');
  clearTimeout(NETT);NETT=setTimeout(goOnline,6000);
}
var NETT;
const OFFACT={
  'part-open':t=>openPart(t.dataset.id),
  'pt-q':t=>{PART.v=+t.dataset.v;setBody(partHTML());},
  'pt-go':()=>partPay(),
  'pay-retry':()=>payRetry(),
  'pay-other':()=>payOther(),
  'net-on':()=>goOnline(),
  'net-off':()=>goOffline()
};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("Object.assign(ACT2,MKACT);", "Object.assign(ACT2,MKACT,OFFACT);")

# F-строки и вызов renderOff в общей отрисовке
rep(" tkSeats:(sec,n)=>ky()?`${tx(sec)} · ${n} билет`:`${sec} · ${F.tkQty(n)}`});",
    " tkSeats:(sec,n)=>ky()?`${tx(sec)} · ${n} билет`:`${sec} · ${F.tkQty(n)}`,\n qN:n=>ky()?`${n} төлөм`:`${n} ${plural(n,'платёж','платежа','платежей')}`});")

rep("renderObjs();renderChat();renderMarket();renderTickets();if(st.cat)renderCat();",
    "renderObjs();renderChat();renderMarket();renderTickets();renderOff();if(st.cat)renderCat();")

# сброс демо возвращает сеть
rep("""  clearInterval(otpI);verifying=false;$('#in-search').value='';""",
    """  clearInterval(otpI);verifying=false;$('#in-search').value='';clearTimeout(NETT);PART=null;FAIL=null;renderOff();""")

# сценарии 8 и 9
rep("""  if(n===7){st.tab='home';""",
    """  if(n===8){st.paid={};st.part={};renderAll();tab('home');setTimeout(()=>{if(unpaid().length){st.failOnce=1;openCheckout(unpaid().slice(0,3).map(b=>b.id));}},520);}
  if(n===9){st.paid={};renderAll();tab('home');setTimeout(()=>{goOffline();setTimeout(()=>{if(unpaid().length)openCheckout(unpaid().slice(0,2).map(b=>b.id));},900);},420);}
  if(n===7){st.tab='home';""")

# кнопка оплаты в листе оплаты честно говорит про офлайн
rep("""  b.textContent=!st.sel.length?tx('Выберите счета'):(need?F.topUp(fmt(need)):F.pay(fmt(s)));""",
    """  b.textContent=!st.sel.length?tx('Выберите счета'):(need?F.topUp(fmt(need)):st.offline?tx('Оплатить, когда появится сеть'):F.pay(fmt(s)));""")

# ===================== Кыргызский =====================
PAIRS = [
 ('Частично', 'Жарым-жартылай'),
 ('В очереди', 'Кезекте'),
 ('Остаток по счёту', 'Эсептеги калдык'),
 ('Отправится, когда появится сеть', 'Тармак пайда болгондо жөнөтүлөт'),
 ('Уже оплачено', 'Төлөнгөн бөлүгү'),
 ('Оплатить часть', 'Бөлүгүн төлөө'),
 ('Счёт можно закрыть не целиком: остаток останется в ленте и попадёт в отчёт.',
  'Эсепти толук эмес жабууга болот: калдыгы лентада калат жана отчётко кирет.'),
 ('Сколько заплатить сейчас, сом', 'Азыр канча төлөйсүз, сом'),
 ('Остальное можно оплатить позже или частями', 'Калганын кийин же бөлүп төлөсө болот'),
 ('Всё', 'Баары'),
 ('Поставщик увидит платёж как частичное погашение', 'Камсыздоочу муну жарым-жартылай төлөм катары көрөт'),
 ('Частичная оплата', 'Жарым-жартылай төлөм'),
 ('Введите сумму', 'Сумманы киргизиңиз'),
 ('Платёж не прошёл', 'Төлөм өтпөй калды'),
 ('Деньги не списаны. Такое бывает при лимите банка или сбое связи с процессингом.',
  'Акча эсептен чыккан жок. Мындай банктын лимити же процессинг менен байланыш үзүлгөндө болот.'),
 ('Банк отклонил операцию', 'Банк операцияны четке какты'),
 ('Причина', 'Себеби'),
 ('Код', 'Коду'),
 ('Счета остались в ленте. Повторите платёж или выберите другой способ — кошелёк ЭлPay проходит без лимитов.',
  'Эсептер лентада калды. Төлөмдү кайталаңыз же башка ыкманы тандаңыз — ЭлPay капчыгы лимитсиз өтөт.'),
 ('Повторить платёж', 'Төлөмдү кайталоо'),
 ('Другой способ оплаты', 'Башка төлөм ыкмасы'),
 ('Написать в поддержку', 'Колдоого жазуу'),
 ('Нет сети — показываем сохранённые данные', 'Тармак жок — сакталган маалыматты көрсөтүп жатабыз'),
 ('Обновить', 'Жаңыртуу'),
 ('Сеть пропала — приложение работает офлайн', 'Тармак жоголду — тиркеме офлайн иштейт'),
 ('Нет сети — платёж отправится автоматически', 'Тармак жок — төлөм автоматтык түрдө жөнөтүлөт'),
 ('Сеть появилась — платежи отправлены', 'Тармак пайда болду — төлөмдөр жөнөтүлдү'),
 ('Сеть появилась', 'Тармак пайда болду'),
 ('Оплатить, когда появится сеть', 'Тармак пайда болгондо төлөө'),
 ('Сбой оплаты и повтор', 'Төлөм катасы жана кайталоо'),
 ('Нет сети: платёж в очереди', 'Тармак жок: төлөм кезекте'),
]
i = s.find('const KY=')
assert i > 0
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
