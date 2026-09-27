# -*- coding: utf-8 -*-
"""ЭлPay v3.3 — продакшн-полнота: управление счетами в профиле, личные данные,
адреса, карты, семья, возврат билета, удаление аккаунта."""
import io, json

P = 'index.html'
s = io.open(P, encoding='utf-8').read()


def rep(old, new, cnt=1):
    global s
    n = s.count(old)
    assert n == cnt, 'expected %d, found %d: %r' % (cnt, n, old[:110])
    s = s.replace(old, new)


CSS = """
/* ===== Управление данными профиля ===== */
.pf{position:relative}
.pf-ed{position:absolute;top:12px;right:12px;width:38px;height:38px;border-radius:13px;background:var(--soft);display:grid;place-items:center;color:var(--gr3);transition:background-color .15s}
.pf-ed:active{background:var(--line2)}
.row .iconbtn{margin-left:2px}
.danger-row{color:#B23A3A}
"""
END = '.tar .v{flex:none;font-size:14px;font-weight:700;color:var(--p700);white-space:nowrap}\n</style>'
rep(END, '.tar .v{flex:none;font-size:14px;font-weight:700;color:var(--p700);white-space:nowrap}' + CSS + '</style>')

# ---- карточка профиля: кнопка «изменить» ----
rep('''              <div class="pf rv" style="--d:1">
                <span class="ava">АТ</span>''',
    '''              <div class="pf rv" style="--d:1">
                <button class="pf-ed" data-act="me-edit" aria-label="Изменить личные данные"><i data-i="square-pen" data-s="18"></i></button>
                <span class="ava">АТ</span>''')

# ---- новая секция «Счета и реквизиты» ----
rep('''              <div class="sec rv" style="--d:2"><h3>Объекты</h3></div>''',
    '''              <div class="sec rv" style="--d:2"><h3>Счета и реквизиты</h3></div>
              <div class="group rv wrap" style="--d:2" id="pf-bills"></div>
              <div class="sec rv" style="--d:2"><h3>Объекты</h3></div>''')

# ---- убрать дубль строки «Реквизиты и счета» из раздела «Приложение» ----
rep('''                <button class="row" data-act="req"><span class="tile"><i data-i="square-pen"></i></span><span class="mid"><span class="t">Реквизиты и счета</span><span class="s">Лицевые счета, шаблоны, ИНН</span></span><i data-i="chevron-right" data-s="18"></i></button>
''', '')

# ---- удаление аккаунта ----
rep('''                <button class="row danger" data-act="logout"><span class="tile bad"><i data-i="log-out"></i></span><span class="mid"><span class="t">Выйти</span></span></button>''',
    '''                <button class="row danger" data-act="logout"><span class="tile bad"><i data-i="log-out"></i></span><span class="mid"><span class="t">Выйти</span></span></button>
                <button class="row danger" data-act="acc-del"><span class="tile bad"><i data-i="trash-2"></i></span><span class="mid"><span class="t">Удалить аккаунт</span><span class="s">Профиль, реквизиты и история</span></span></button>''')

# ---- адреса: строка с карандашом, без фантомного «все адреса» ----
rep('''const addrRow=id=>{
  const a=addrById(id);
  return `<button class="row" data-act="addr-pick" data-id="${id}">${addrTile(id)}<span class="mid"><span class="t">${tx(a.name)}</span><span class="s">${a.addr}</span></span>${st.addr===id?`<span class="chip ok sm">${ic('check',12,3)}Выбран</span>`:''}</button>`;
};''',
    '''const addrRow=(id,ed)=>{
  const a=addrById(id);
  return `<div class="row" data-act="addr-pick" data-id="${id}">${addrTile(id)}<span class="mid"><span class="t">${tx(a.name)}</span><span class="s">${a.addr}</span></span>${st.addr===id?`<span class="chip ok sm">${ic('check',12,3)}Выбран</span>`:''}${ed?`<button class="iconbtn" data-act="addr-edit" data-id="${id}" aria-label="Изменить адрес">${ic('square-pen',18)}</button>`:''}</div>`;
};''')

rep("  pf.innerHTML=(ADDRS.length>1?addrRow('all'):'')+ADDRS.map(a=>addrRow(a.id)).join('')+addAddrRow;",
    "  pf.innerHTML=ADDRS.map(a=>addrRow(a.id,1)).join('')+addAddrRow;")

# ---- способы оплаты в профиле: управление картой ----
rep('''  el.innerHTML=[...PMS,...st.cards].map(p=>`<button class="row" data-act="pm-pick" data-pm="${p.id}"><span class="cardart ${p.cls}">${p.art}</span><span class="mid"><span class="t">${tx(p.t)}</span><span class="s">${pmSub(p)}</span></span>${st.pm===p.id?`<span class="chip ok sm">${ic('check',12,3)}Основной</span>`:''}</button>`).join('')''',
    '''  el.innerHTML=[...PMS,...st.cards].map(p=>`<div class="row" data-act="pm-pick" data-pm="${p.id}"><span class="cardart ${p.cls}">${p.art}</span><span class="mid"><span class="t">${tx(p.t)}</span><span class="s">${pmSub(p)}</span></span>${st.pm===p.id?`<span class="chip ok sm">${ic('check',12,3)}Основной</span>`:''}<button class="iconbtn" data-act="pm-card" data-pm="${p.id}" aria-label="Настройки способа оплаты">${ic('square-pen',18)}</button></div>`).join('')''')

# ---- семья: карандаш у участника ----
rep('''${m.you?chipx('Вы','#DEF3EC','#05804F'):m.pay?chipx('Может платить','#EEF1EF','#3C4A55'):chipx('Только просмотр','#EEF1EF','#3C4A55')}</div>`;''',
    '''${m.you?chipx('Вы','#DEF3EC','#05804F'):m.pay?chipx('Может платить','#EEF1EF','#3C4A55'):chipx('Только просмотр','#EEF1EF','#3C4A55')}${m.you?'':`<button class="iconbtn" data-act="fm-edit" data-id="${m.id}" aria-label="Изменить участника">${ic('square-pen',18)}</button>`}</div>`;''')

# ---- билет: возврат ----
rep('''    <button class="btn btn-s" data-act="toast" data-msg="Билет отправлен — получатель откроет его в ЭлPay">${ic('share-2',20)}Передать билет</button></div></div>`;''',
    '''    <button class="btn btn-s" data-act="toast" data-msg="Билет отправлен — получатель откроет его в ЭлPay">${ic('share-2',20)}Передать билет</button>
    ${t.used?'':`<button class="btn btn-g" data-act="tk-refund" data-id="${t.id}">${ic('repeat',20)}Вернуть билет</button>`}</div></div>`;''')

# ---- общая отрисовка ----
rep("renderObjs();renderChat();renderMarket();renderTickets();renderOff();renderLock();if(st.cat)renderCat();",
    "renderObjs();renderChat();renderMarket();renderTickets();renderOff();renderLock();renderPfBills();if(st.cat)renderCat();")

# ---- приветствие по имени ----
rep("""  $('#pf-name').textContent=st.name;""",
    """  $('#pf-name').textContent=st.name;
  const hl=$('.hello');if(hl)hl.textContent='Салам, '+st.name.trim().split(/\\s+/)[0];""")

JS = r"""/* ===== Управление данными: профиль, адреса, карты, семья, билеты ===== */
Object.assign(F,{
 reqSub:(u,k,c)=>ky()?`${u} эсеп · ${k} шаблон · ${c} өз алуучусу`:`${u} ${plural(u,'счёт','счёта','счетов')} · ${k} ${plural(k,'шаблон','шаблона','шаблонов')} · ${c} ${plural(c,'получатель','получателя','получателей')}`,
 refunded:s2=>ky()?`Билет кайтарылды · ${s2} сом 3 күндүн ичинде кайтат`:`Билет возвращён · ${s2} сом вернутся в течение 3 дней`});
function renderPfBills(){
  const el=$('#pf-bills');if(!el)return;
  el.innerHTML=`<button class="row" data-act="req">${tl('water','list-checks')}<span class="mid"><span class="t">Мои счета и реквизиты</span><span class="s">${F.reqSub(st.conn.length,st.kids.length,st.custom.length)}</span></span>${ic('chevron-right',18)}</button>
   <button class="row" data-act="cat-open" data-id="util">${tl('power','circle-plus')}<span class="mid"><span class="t">Добавить коммунальный счёт</span><span class="s">Вода, свет, мусор, газ, интернет, домофон</span></span>${ic('chevron-right',18)}</button>
   <button class="row" data-act="addchild">${tl('kid','school')}<span class="mid"><span class="t">Добавить садик или школу</span><span class="s">Реквизиты подставим из каталога</span></span>${ic('chevron-right',18)}</button>
   <button class="row" data-act="manual">${tl('city','receipt')}<span class="mid"><span class="t">Добавить получателя вручную</span><span class="s">Если поставщика нет в каталоге</span></span>${ic('chevron-right',18)}</button>
   <button class="row" data-act="cat-open" data-id="tax">${tl('tax','landmark')}<span class="mid"><span class="t">Налоги по ИНН</span><span class="s">${st.taxOn?tx('Начисления подключены'):tx('Подключить проверку задолженности')}</span></span>${ic('chevron-right',18)}</button>`;
  if(ky())trTree(el);
}
/* --- личные данные --- */
function meSheet(){
  const ph=(st.phone||'').replace(/\D/g,'').slice(-9);
  openSheet(tx('Личные данные'),`<p class="sub">Имя видно только вам. Телефон — вход в приложение, почта — для квитанций.</p>
   <div class="field" style="margin-top:14px"><label for="me-name">Фамилия и имя</label><div class="inp"><input id="me-name" value="${st.name}"></div></div>
   <div class="field"><label for="me-phone">Телефон</label><div class="inp"><span class="pre">+996</span><input id="me-phone" inputmode="numeric" value="${fmtPhone(ph)}"></div><p class="hint">На этот номер приходит код входа</p></div>
   <div class="field"><label for="me-mail">Почта</label><div class="inp">${ic('mail',20)}<input id="me-mail" type="email" value="${st.email||''}" placeholder="name@example.com"></div><p class="hint">Квитанции и выписки приходят сюда</p></div>
   <button class="btn btn-p" data-act="me-save">${ic('check',20)}Сохранить</button>
   <button class="btn btn-s" data-act="close">Отмена</button>`,'me');
}
function meSave(){
  const n=($('#me-name').value||'').trim(),p=($('#me-phone').value||'').replace(/\D/g,''),e=($('#me-mail').value||'').trim();
  $$('#sh-body .field').forEach(f=>f.classList.remove('err'));
  if(n.length<2)return fErr('#me-name','Введите имя');
  if(p.length!==9)return fErr('#me-phone','Нужно 9 цифр после +996');
  if(e&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e))return fErr('#me-mail','Проверьте адрес — например, name@example.com');
  st.name=n;st.phone='+996 '+fmtPhone(p);st.email=e;
  closeSheet();renderAll();toast('Данные сохранены');
}
/* --- адреса --- */
let ADR=null;
function addrEditHTML(){
  const a=addrById(ADR.id),p=a.addr.split(',');
  return `<p class="sub">По этому адресу приходят предупреждения об отключениях. На счета адрес не влияет.</p>
   <div class="field" style="margin-top:14px"><label for="ae-name">Название</label><div class="inp"><input id="ae-name" value="${tx(a.name)}"></div></div>
   <div class="field"><label for="ae-city">Город</label><div class="inp">${ic('map-pin',20)}<input id="ae-city" value="${(p[0]||'Ош').trim()}"></div></div>
   <div class="field"><label for="ae-addr">Улица, дом, квартира</label><div class="inp"><input id="ae-addr" value="${p.slice(1).join(',').trim()}"></div></div>
   <button class="btn btn-p" data-act="ae-save">${ic('check',20)}Сохранить</button>
   ${ADDRS.length>1?`<button class="btn danger-btn" data-act="ae-del">${ic('trash-2',20)}Удалить адрес</button>`:`<p class="hint2">Это единственный адрес — его нельзя удалить, но можно изменить.</p>`}`;
}
function addrEdit(id){ADR={id:+id};openSheet(tx('Адрес'),addrEditHTML(),'ae');}
function addrEditSave(){
  const a=addrById(ADR.id),n=($('#ae-name').value||'').trim(),c=($('#ae-city').value||'').trim(),st2=($('#ae-addr').value||'').trim();
  $$('#sh-body .field').forEach(f=>f.classList.remove('err'));
  if(n.length<2)return fErr('#ae-name','Введите название — например, «Дача»');
  if(!c)return fErr('#ae-city','Укажите город');
  if(st2.length<5)return fErr('#ae-addr','Укажите улицу и номер дома');
  a.name=n;a.addr=c+', '+st2;closeSheet();renderAll();toast('Адрес сохранён');
}
function addrDel(){
  const a=addrById(ADR.id);
  confirmSheet(tx('Удалить адрес?'),tx('Уведомления об отключениях по этому адресу приходить не будут.'),tx('Удалить'),()=>{
    const i=ADDRS.findIndex(x=>x.id===a.id);
    if(i>=0)ADDRS.splice(i,1);
    if(st.addr===a.id)st.addr=ADDRS[0].id;
    ADR=null;closeSheet();renderAll();toast('Адрес удалён');
  });
}
/* --- способы оплаты --- */
function pmCard(id){
  const p=pmById(id),own=(st.cards||[]).some(c=>c.id===id);
  openSheet(tx(p.t),`<div class="bs-top"><span class="cardart ${p.cls}">${p.art}</span><div class="mid"><b>${tx(p.t)}</b><span>${pmSub(p)}</span></div>${st.pm===p.id?`<span class="chip ok sm">${ic('check',12,3)}Основной</span>`:''}</div>
   <div class="kv" style="margin-top:14px"><div><span>Тип</span><b>${p.w?tx('Кошелёк ЭлPay'):tx('Банковская карта')}</b></div><div><span>Комиссия за платёж</span><b>0 сом</b></div><div><span>Лимит одной операции</span><b class="num">150 000 сом</b></div></div>
   ${p.w?`<button class="btn btn-p" data-act="wallet-top" data-need="0">${ic('circle-plus',20)}Пополнить кошелёк</button>`:''}
   ${st.pm===p.id?'':`<button class="btn btn-p" data-act="pm-main" data-pm="${p.id}">${ic('check',20)}Сделать основным</button>`}
   ${own?`<button class="btn danger-btn" data-act="pm-del" data-pm="${p.id}">${ic('trash-2',20)}Отвязать карту</button>`:`<p class="hint2">${tx('Этот способ подключён в демо и отвязать его нельзя.')}</p>`}`,'pmc');
}
function pmDel(id){
  const c=(st.cards||[]).find(x=>x.id===id);if(!c)return;
  confirmSheet(tx('Отвязать карту?'),tx('Карта исчезнет из способов оплаты. Автоплатежи переключатся на кошелёк ЭлPay.'),tx('Отвязать'),()=>{
    st.cards=st.cards.filter(x=>x.id!==id);
    if(st.pm===id)st.pm='wallet';
    closeSheet();renderAll();toast('Карта отвязана');
  });
}
/* --- семья --- */
function famEdit(id){
  const m=st.fam.find(x=>x.id===id);if(!m)return;
  FAMD=null;
  openSheet(tx('Участник семьи'),`<div class="bs-top"><span class="ava">${initials(m.n)}</span><div class="mid"><b>${m.n}</b><span>${tx(m.r)}</span></div></div>
   <div class="field" style="margin-top:16px"><span class="lbl">Права</span><div class="cities"><button class="city${m.pay?' on':''}" data-act="fm-perm" data-id="${m.id}" data-v="1">${m.pay?ic('check',16):''}Может платить</button><button class="city${m.pay?'':' on'}" data-act="fm-perm" data-id="${m.id}" data-v="0">${m.pay?'':ic('check',16)}Только просмотр</button></div></div>
   <div class="tip">${ic('info',18)}<span>Участник видит счета открытых объектов и историю только своих платежей.</span></div>
   <button class="btn btn-s" data-act="fam-open">${ic('users',20)}К списку семьи</button>
   <button class="btn danger-btn" data-act="fm-del" data-id="${m.id}">${ic('trash-2',20)}Убрать из семьи</button>`,'fme');
}
function famDel(id){
  const m=st.fam.find(x=>x.id===id);if(!m)return;
  confirmSheet(tx('Убрать из семьи?'),tx('Участник потеряет доступ к счетам. Пригласить заново можно в любой момент.'),tx('Убрать'),()=>{
    st.fam=st.fam.filter(x=>x.id!==id);closeSheet();renderAll();toast('Участник убран из семьи');
  });
}
/* --- возврат билета --- */
function tkRefund(id){
  const t=(st.tickets||[]).find(x=>x.id===id);if(!t)return;
  const e=evtById(t.evt);
  confirmSheet(tx('Вернуть билет?'),tx('Билет на «'+e.t+'» будет аннулирован, QR перестанет работать.'),tx('Вернуть'),()=>{
    st.tickets=st.tickets.filter(x=>x.id!==id);
    if(st.pm==='wallet')st.bal+=t.amount;
    closeSheet();renderAll();toast(F.refunded(fmt(t.amount)));
  });
}
/* --- удаление аккаунта --- */
function accDel(){
  confirmSheet(tx('Удалить аккаунт?'),tx('Профиль, реквизиты, история платежей и билеты будут удалены. Задолженность перед поставщиками при этом не исчезает.'),tx('Удалить аккаунт'),()=>{
    closeSheet();resetState();go('welcome','back');toast('Аккаунт удалён');
  });
}
const CRUDACT={
  'me-edit':()=>meSheet(),
  'me-save':()=>meSave(),
  'addr-edit':t=>addrEdit(t.dataset.id),
  'ae-save':()=>addrEditSave(),
  'ae-del':()=>addrDel(),
  'pm-card':t=>pmCard(t.dataset.pm),
  'pm-main':t=>{st.pm=t.dataset.pm;closeSheet();renderAll();toast(F.pmSet(tx(pmById(st.pm).t)));},
  'pm-del':t=>pmDel(t.dataset.pm),
  'fm-edit':t=>famEdit(t.dataset.id),
  'fm-perm':t=>{const m=st.fam.find(x=>x.id===t.dataset.id);if(!m)return;m.pay=t.dataset.v==='1';famEdit(m.id);renderAll();toast(m.pay?'Теперь может платить':'Теперь только просмотр');},
  'fm-del':t=>famDel(t.dataset.id),
  'tk-refund':t=>tkRefund(t.dataset.id),
  'acc-del':()=>accDel()
};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT);",
    "Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT,CRUDACT);")
rep("PART=null;FAIL=null;LK=null;DSP=null;FAMD=null;renderOff();",
    "PART=null;FAIL=null;LK=null;DSP=null;FAMD=null;ADR=null;renderOff();")

PAIRS = [
 ('Счета и реквизиты', 'Эсептер жана реквизиттер'),
 ('Мои счета и реквизиты', 'Менин эсептерим жана реквизиттерим'),
 ('Добавить коммунальный счёт', 'Коммуналдык эсеп кошуу'),
 ('Вода, свет, мусор, газ, интернет, домофон', 'Суу, жарык, таштанды, газ, интернет, домофон'),
 ('Добавить садик или школу', 'Бала бакча же мектеп кошуу'),
 ('Реквизиты подставим из каталога', 'Реквизиттерди каталогдон коёбуз'),
 ('Налоги по ИНН', 'ИНН боюнча салыктар'),
 ('Начисления подключены', 'Эсептөөлөр туташтырылган'),
 ('Подключить проверку задолженности', 'Карызды текшерүүнү туташтыруу'),
 ('Изменить личные данные', 'Жеке маалыматты өзгөртүү'),
 ('Личные данные', 'Жеке маалымат'),
 ('Имя видно только вам. Телефон — вход в приложение, почта — для квитанций.',
  'Атыңыз сизге гана көрүнөт. Телефон — тиркемеге кирүү, почта — квитанциялар үчүн.'),
 ('Фамилия и имя', 'Аты-жөнү'),
 ('Телефон', 'Телефон'),
 ('На этот номер приходит код входа', 'Бул номерге кирүү коду келет'),
 ('Почта', 'Почта'),
 ('Квитанции и выписки приходят сюда', 'Квитанциялар жана көчүрмөлөр бул жерге келет'),
 ('Сохранить', 'Сактоо'),
 ('Отмена', 'Жокко чыгаруу'),
 ('Данные сохранены', 'Маалымат сакталды'),
 ('Изменить адрес', 'Даректи өзгөртүү'),
 ('Адрес', 'Дарек'),
 ('По этому адресу приходят предупреждения об отключениях. На счета адрес не влияет.',
  'Бул дарек боюнча өчүрүүлөр тууралуу эскертүүлөр келет. Эсептерге дарек таасир этпейт.'),
 ('Это единственный адрес — его нельзя удалить, но можно изменить.',
  'Бул жалгыз дарек — аны өчүрүүгө болбойт, бирок өзгөртүүгө болот.'),
 ('Удалить адрес', 'Даректи өчүрүү'),
 ('Удалить адрес?', 'Дарек өчүрүлсүнбү?'),
 ('Уведомления об отключениях по этому адресу приходить не будут.', 'Бул дарек боюнча өчүрүү эскертүүлөрү келбей калат.'),
 ('Адрес сохранён', 'Дарек сакталды'),
 ('Адрес удалён', 'Дарек өчүрүлдү'),
 ('Настройки способа оплаты', 'Төлөм ыкмасынын жөндөөлөрү'),
 ('Тип', 'Түрү'),
 ('Кошелёк ЭлPay', 'ЭлPay капчыгы'),
 ('Банковская карта', 'Банк картасы'),
 ('Комиссия за платёж', 'Төлөм үчүн комиссия'),
 ('Лимит одной операции', 'Бир операциянын чеги'),
 ('Сделать основным', 'Негизги кылуу'),
 ('Отвязать карту', 'Картаны ажыратуу'),
 ('Отвязать карту?', 'Карта ажыратылсынбы?'),
 ('Отвязать', 'Ажыратуу'),
 ('Карта исчезнет из способов оплаты. Автоплатежи переключатся на кошелёк ЭлPay.',
  'Карта төлөм ыкмаларынан жоголот. Автотөлөмдөр ЭлPay капчыгына which өтөт.'),
 ('Этот способ подключён в демо и отвязать его нельзя.', 'Бул ыкма демодо туташтырылган, аны ажыратууга болбойт.'),
 ('Карта отвязана', 'Карта ажыратылды'),
 ('Участник семьи', 'Үй-бүлө мүчөсү'),
 ('Изменить участника', 'Катышуучуну өзгөртүү'),
 ('Участник видит счета открытых объектов и историю только своих платежей.',
  'Катышуучу ачык объекттердин эсептерин жана өз төлөмдөрүнүн тарыхын гана көрөт.'),
 ('К списку семьи', 'Үй-бүлө тизмесине'),
 ('Убрать из семьи', 'Үй-бүлөдөн чыгаруу'),
 ('Убрать из семьи?', 'Үй-бүлөдөн чыгарылсынбы?'),
 ('Убрать', 'Чыгаруу'),
 ('Участник потеряет доступ к счетам. Пригласить заново можно в любой момент.',
  'Катышуучу эсептерге мүмкүнчүлүгүн жоготот. Кайра чакырууга ар дайым болот.'),
 ('Участник убран из семьи', 'Катышуучу үй-бүлөдөн чыгарылды'),
 ('Теперь может платить', 'Эми төлөй алат'),
 ('Теперь только просмотр', 'Эми кароо гана'),
 ('Вернуть билет', 'Билетти кайтаруу'),
 ('Вернуть билет?', 'Билет кайтарылсынбы?'),
 ('Вернуть', 'Кайтаруу'),
 ('Удалить аккаунт', 'Аккаунтту өчүрүү'),
 ('Удалить аккаунт?', 'Аккаунт өчүрүлсүнбү?'),
 ('Профиль, реквизиты и история', 'Профиль, реквизиттер жана тарых'),
 ('Профиль, реквизиты, история платежей и билеты будут удалены. Задолженность перед поставщиками при этом не исчезает.',
  'Профиль, реквизиттер, төлөм тарыхы жана билеттер өчүрүлөт. Камсыздоочулардын алдындагы карыз жоголбойт.'),
 ('Аккаунт удалён', 'Аккаунт өчүрүлдү'),
 ('Введите имя', 'Атын киргизиңиз'),
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
