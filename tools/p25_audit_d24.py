# -*- coding: utf-8 -*-
"""Аудит D2 и D4: устройства и история входов, подтверждение крупного платежа."""
import io, json
P='index.html'; s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old); assert n==cnt,'expected %d, found %d: %r'%(cnt,n,old[:110]); s=s.replace(old,new)

CSS = """
/* ===== Устройства и крупный платёж ===== */
.dev{display:flex;align-items:center;gap:12px;padding:12px 14px;border-radius:16px;background:var(--soft)}
.dev+.dev{margin-top:8px}
.dev .mid b{display:block;font-size:14px;font-weight:700}
.dev .mid span{display:block;font-size:12.5px;color:var(--muted)}
.big-sum{margin:6px 0 2px;text-align:center;font-size:34px;font-weight:700;letter-spacing:-.02em}
.big-sum small{font-size:18px;font-weight:600;color:var(--muted)}
"""
END = '.pt-left b{font-size:14px;font-weight:700;color:var(--gr)}\n</style>'
rep(END, '.pt-left b{font-size:14px;font-weight:700;color:var(--gr)}' + CSS + '</style>')

rep("pinOn:0,bioOn:1,auto:{},pin:'4815'",
    "pinOn:0,bioOn:1,auto:{},pin:'4815',dev:[{id:'d1',n:'iPhone 14',os:'iOS 18 · этот телефон',city:'Ош',last:'сейчас',cur:1},{id:'d2',n:'MacBook Air',os:'Safari · вход по QR',city:'Ош',last:'вчера, 21:14'},{id:'d3',n:'Redmi Note 12',os:'Android 14',city:'Бишкек',last:'12 сентября'}]")

# строка в профиле
rep("""   +`<button class="row" data-act="lock-now"><span class="tile">${ic('shield-check')}</span>""",
    """   +`<button class="row" data-act="dev-list"><span class="tile">${ic('smartphone')}</span><span class="mid"><span class="t">Устройства и входы</span><span class="s">${F.devN((st.dev||[]).length)}</span></span>${ic('chevron-right',18)}</button>`
   +`<button class="row" data-act="lock-now"><span class="tile">${ic('shield-check')}</span>""")

# крупный платёж
rep("""  closeSheet();await wait(260);
  if(st.bioOn){""",
    """  closeSheet();await wait(260);
  if(total(items)>=BIGPAY){
    const ok=await bigConfirm(items);
    if(!ok)return;
    await wait(240);
  }
  if(st.bioOn){""")

JS = r"""/* ===== Аудит D2, D4: устройства, крупный платёж ===== */
const BIGPAY=20000;
Object.assign(F,{
 devN:n=>ky()?`${n} түзмөк`:`${n} ${plural(n,'устройство','устройства','устройств')}`,
 bigWarn:s2=>ky()?`${s2} сом — чоң төлөм`:`${s2} сом — крупный платёж`});
const LOGINS=[['Вход по Face ID','Сегодня, 09:41 · Ош, iPhone 14',1],
 ['Смена номера телефона','Вчера, 18:20 · Ош, iPhone 14',1],
 ['Вход с нового устройства','12 сентября · Бишкек, Redmi Note 12',0]];
function devHTML(){
  return `<p class="sub">Здесь видно, где открыт ваш ЭлPay. Если устройство незнакомое — выйдите везде и смените код-пароль.</p>
   <div style="margin-top:14px">${(st.dev||[]).map(d=>`<div class="dev">${tl(d.cur?'water':'city','smartphone')}<span class="mid"><b>${d.n}</b><span>${tx(d.os)} · ${tx(d.city)}</span></span>${d.cur?chipx('Сейчас','#DEF3EC','#05804F'):chipx(tx(d.last),'#EEF1EF','#3C4A55')}</div>`).join('')}</div>
   <div class="sec"><h3>Последние события</h3></div>
   <ol class="tl">${LOGINS.map(([t,d,ok])=>`<li class="${ok?'done':''}"><span class="tl-dot">${ok?ic('check',12,3):ic('info',12,3)}</span><div><b>${t}</b><span>${d}</span></div></li>`).join('')}</ol>
   <button class="btn danger-btn" data-act="dev-out">${ic('log-out',20)}Выйти на всех устройствах</button>
   <p class="legal center">${ic('lock',14)}На этом телефоне вы останетесь в аккаунте</p>`;
}
function devOut(){
  confirmSheet(tx('Выйти на всех устройствах?'),tx('Сессии на других устройствах закроются. На этом телефоне вы останетесь в аккаунте.'),tx('Выйти везде'),()=>{
    st.dev=(st.dev||[]).filter(d=>d.cur);
    closeSheet();renderAll();toast('Вышли на других устройствах');
  });
}
let BIG=null;
function bigConfirm(items){
  const sum=total(items),p=pmById(st.pm);
  return new Promise(res=>{
    BIG=res;
    openSheet(tx('Крупный платёж'),`<p class="sub">Сумма больше 20 000 сом — подтвердите, что это вы. Банк может запросить подтверждение ещё раз.</p>
     <div class="big-sum num">${fmt(sum)} <small>сом</small></div>
     <div class="kv"><div><span>Платежей</span><b class="num">${items.length}</b></div><div><span>Получатель</span><b>${items.length>1?tx('Несколько получателей'):tx(items[0].short)}</b></div><div><span>Способ оплаты</span><b>${tx(p.t)}</b></div><div><span>Лимит операции</span><b class="num">150 000 сом</b></div></div>
     <button class="btn btn-p" data-act="big-yes">${ic('shield-check',20)}Да, это я</button>
     <button class="btn btn-s" data-act="close">Отмена</button>`,'big');
  });
}
function bigDone(ok){
  const f=BIG;BIG=null;
  if(ok){st.sheet=null;$('#backdrop').classList.remove('on');$('#sheet').classList.remove('on');}
  if(f)f(ok);
}
const DACT={
  'dev-list':()=>openSheet(tx('Устройства и входы'),devHTML(),'dev'),
  'dev-out':()=>devOut(),
  'big-yes':()=>bigDone(true)
};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT,CRUDACT,PAYACT,CACT);",
    "Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT,CRUDACT,PAYACT,CACT,DACT);")
rep("function closeSheet(){if(st.sheet==='pp'&&PP){const f=PP;PP=null;f(false);}",
    "function closeSheet(){if(st.sheet==='pp'&&PP){const f=PP;PP=null;f(false);}if(st.sheet==='big'&&BIG){const f=BIG;BIG=null;f(false);}")
rep("PART=null;FAIL=null;LK=null;DSP=null;FAMD=null;ADR=null;ME=null;PP=null;renderOff();",
    "PART=null;FAIL=null;LK=null;DSP=null;FAMD=null;ADR=null;ME=null;PP=null;BIG=null;renderOff();")

PAIRS=[('Устройства и входы','Түзмөктөр жана кирүүлөр'),
 ('Здесь видно, где открыт ваш ЭлPay. Если устройство незнакомое — выйдите везде и смените код-пароль.',
  'Бул жерде ЭлPay кайда ачык экени көрүнөт. Түзмөк тааныш эмес болсо — баарынан чыгып, код-сырсөздү өзгөртүңүз.'),
 ('Последние события','Акыркы окуялар'),('Сейчас','Азыр'),
 ('Выйти на всех устройствах','Бардык түзмөктөрдөн чыгуу'),
 ('Выйти на всех устройствах?','Бардык түзмөктөрдөн чыгасызбы?'),
 ('Выйти везде','Баарынан чыгуу'),
 ('Сессии на других устройствах закроются. На этом телефоне вы останетесь в аккаунте.',
  'Башка түзмөктөрдөгү сессиялар жабылат. Бул телефондо аккаунтуңузда каласыз.'),
 ('На этом телефоне вы останетесь в аккаунте','Бул телефондо аккаунтуңузда каласыз'),
 ('Вышли на других устройствах','Башка түзмөктөрдөн чыктык'),
 ('Вход по Face ID','Face ID менен кирүү'),
 ('Смена номера телефона','Телефон номерин алмаштыруу'),
 ('Вход с нового устройства','Жаңы түзмөктөн кирүү'),
 ('Крупный платёж','Чоң төлөм'),
 ('Сумма больше 20 000 сом — подтвердите, что это вы. Банк может запросить подтверждение ещё раз.',
  'Сумма 20 000 сомдон ашык — бул сиз экениңизди ырастаңыз. Банк дагы бир жолу ырастоо сурашы мүмкүн.'),
 ('Платежей','Төлөмдөр'),('Несколько получателей','Бир нече алуучу'),
 ('Лимит операции','Операциянын чеги'),('Да, это я','Ооба, бул мен')]
i=s.find('const KY='); j=s.find(';\n',i)
KY=json.loads(s[i+len('const KY='):j]); a=0
for ru,ky in PAIRS:
    if ru not in KY: KY[ru]=ky; a+=1
s=s[:i+len('const KY=')]+json.dumps(KY,ensure_ascii=False,separators=(',',':'))+s[j:]
io.open(P,'w',encoding='utf-8').write(s); print('ok, ky added:',a)
