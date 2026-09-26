# -*- coding: utf-8 -*-
"""v2.8 шаг 5: действия чата, контролёры, инструкция по карте."""
import io
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:90]!r}'
    s=s.replace(old,new)

# ---------- состояние ----------
rep("bal:1240,qr:null,objId:null,objSel:'o1'",
    "bal:1240,qr:null,objId:null,objSel:'o1',cards:[],read:{},chatQ:null,\n  chat:[{t:'Здравствуйте! Это поддержка ЭлPay. Помогу с реквизитами, начислениями и картой.',w:'09:41'}],")

# ---------- иконки ----------
rep("'trees':'<path",
"""'headset':'<path d="M3 11h3a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/><path d="M18 11h3v6a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1z"/><path d="M3 11a9 9 0 0 1 18 0"/><path d="M21 17v1a3 3 0 0 1-3 3h-4"/>',
'gauge':'<path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/>',
'phone':'<path d="M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233 14 14 0 0 0 6.392 6.384"/>',
'shield-check':'<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
'trees':'<path""")

# ---------- контролёры ----------
rep("/* ===== Чат поддержки ===== */",
"""/* ===== Контролёры участка ===== */
const CTRL={
 power:{n:'Асанов Марат',u:'участок 12',ph:'+996 700 44 12 08',last:'8 сентября',read:'15 232 кВт·ч',unit:'кВт·ч',prev:15232,tar:1.37,plan:'обходит 5–10 числа'},
 water:{n:'Жумаева Гүлмира',u:'участок 4',ph:'+996 555 71 09 33',last:'6 сентября',read:'1 213 м³',unit:'м³',prev:1213,tar:22.8,plan:'обходит 1–7 числа'},
 gas:{n:'Токтоев Эрлан',u:'участок 9',ph:'+996 770 31 88 20',last:'4 сентября',read:'842 м³',unit:'м³',prev:842,tar:14.6,plan:'обходит 1–5 числа'},
 trash:{n:'Ошуров Бакыт',u:'участок 7',ph:'+996 770 22 55 41',last:'1 сентября',read:'—',plan:'по графику вывоза'}};
const ctrlOf=b=>b&&b.svc?CTRL[b.svc]:null;
function ctrlBlock(b){
  const c=ctrlOf(b);if(!c)return '';
  return `<div class="sec"><h3>Контролёр участка</h3></div>
   <div class="row">${tl(cat(b),'user',22,1)}<span class="mid"><span class="t">${c.n}</span><span class="s">${tx(c.u)} · ${tx(c.plan)}</span></span></div>
   <p class="hint2">${tx('Последний обход')} — ${tx(c.last)}${c.read!=='—'?', '+tx('снял')+' '+c.read:''}.</p>
   <div class="kv-edit" style="margin-top:12px"><button class="btn btn-s" data-act="ctrl-call" data-svc="${b.svc}">${ic('phone',20)}Позвонить</button>
   ${c.unit?`<button class="btn btn-s" data-act="ctrl-read" data-svc="${b.svc}">${ic('gauge',20)}Передать показания</button>`:''}</div>`;
}
function readSheet(svc){
  const c=CTRL[svc],u=UTIL.find(x=>x.id===svc)||{};
  openSheet('Передать показания',`<div class="bs-top">${tl(CAT[u.icon]||'water',u.icon)}<div class="mid"><b>${tx(u.name)}</b><span>${tx(c.u)} · ${c.n}</span></div></div>
   <div class="kv"><div><span>Предыдущее</span><b class="num">${fmt(c.prev)} ${c.unit}</b></div><div><span>Тариф</span><b class="num">${String(c.tar).replace('.',',')} сом</b></div></div>
   <div class="field" style="margin-top:14px"><label for="rd-v">Новое показание, ${c.unit}</label><div class="inp">${ic('gauge',20)}<input id="rd-v" inputmode="numeric" value="" placeholder="${fmt(c.prev)}"></div><p class="hint" id="rd-h">Расход и сумма посчитаются сами</p></div>
   <button class="btn btn-s" data-act="toast" data-msg="Фото счётчика приложено">${ic('qr',20)}Приложить фото счётчика</button>
   <button class="btn btn-p" data-act="rd-save" data-svc="${svc}">Отправить контролёру</button>`,'rd');
  const inp=$('#rd-v');
  inp.addEventListener('input',()=>{
    const v=parseInt(inp.value.replace(/\\D/g,''),10)||0,d=v-c.prev;
    $('#rd-h').textContent=d>0?F.spend(fmt(d)+' '+c.unit,fmt(Math.round(d*c.tar*100)/100)):tx('Расход и сумма посчитаются сами');
  });
}
/* ===== Чат поддержки ===== */""")
rep("${b.hist?bars(b):''}","${b.hist?bars(b):''}\n    ${ctrlBlock(b)}")

# ---------- действия ----------
rep("  'obj-open':t=>{",
"""  'chat-open':()=>{renderChat();go('chat');},
  'chat-q':t=>{
    const k=t.dataset.k,lbl=(st.chatQ||CHATQ).find(q=>q[0]===k);
    if(k==='cardgo'){st.chatQ=null;return cardHow();}
    chatPush({me:1,t:k==='addr'?'Ош, ул. Курманжан Датка, 212, кв. 14':(lbl?lbl[1]:''),w:TODAY.time});
    chatBot(k);
  },
  'chat-send':()=>{
    const i=$('#chat-t'),v=(i.value||'').trim();if(!v)return;
    i.value='';chatPush({me:1,t:v,w:TODAY.time});
    chatBot(/\\d/.test(v)&&v.length>8?'addr':'op');
  },
  'chat-add':t=>{svcPre(t.dataset.svc,t.dataset.acc,t.dataset.name);},
  'ctrl-call':t=>{const c=CTRL[t.dataset.svc];toast(F.calling(c.n,c.ph));},
  'ctrl-read':t=>{const svc=t.dataset.svc;if(st.sheet){closeSheet();setTimeout(()=>readSheet(svc),300);}else readSheet(svc);},
  'rd-save':t=>{
    const svc=t.dataset.svc,c=CTRL[svc],v=parseInt(($('#rd-v').value||'').replace(/\\D/g,''),10)||0;
    if(v<=c.prev)return fErr('#rd-v','Показание должно быть больше '+fmt(c.prev));
    st.read[svc]=v;closeSheet();renderAll();toast(F.readSent(fmt(v)+' '+c.unit,c.n));
  },
  'obj-open':t=>{""")

# ---------- инструкция по карте ----------
rep("  'pm-add':()=>toast('В демо карты уже привязаны — добавление в релизе'),",
"""  'pm-add':()=>cardHow(),
  'card-form':()=>openSheet('Форма банка',cardFormHTML(),'cf'),
  'card-save':()=>{
    const n=st.cards.length+1;
    st.cards.push({id:'card'+n,art:'MASTER',cls:'mc',t:'Mastercard •••• 4409',s:'Добавлена только что'});
    st.pm='card'+n;closeSheet();renderAll();toast('Карта привязана — 1 сом вернётся в течение суток');
  },""")
rep("function svcSheet(svc,src){",
"""function cardHow(){
  openSheet('Как привязать карту',`<p class="sub">Занимает минуту. Номер карты остаётся у банка — ЭлPay его не видит и не хранит.</p>
   <div class="group wrap">
    <div class="row">${tl('water','circle-plus')}<span class="mid"><span class="t">1. Нажмите «Добавить карту»</span><span class="s">Профиль → Способы оплаты</span></span></div>
    <div class="row">${tl('net','shield-check')}<span class="mid"><span class="t">2. Введите данные в форме банка</span><span class="s">Откроется защищённая страница «Оптима Банка»</span></span></div>
    <div class="row">${tl('power','banknote')}<span class="mid"><span class="t">3. Банк спишет и вернёт 1 сом</span><span class="s">Так проверяется, что карта ваша</span></span></div>
    <div class="row">${tl('kid','circle-check')}<span class="mid"><span class="t">4. Карта появится в списке</span><span class="s">Можно платить и включить автоплатёж</span></span></div>
   </div>
   <button class="btn btn-p" data-act="card-form">${ic('shield-check',20)}Открыть защищённую форму</button>
   <p class="legal center">${ic('lock',14)}Данные карты передаются напрямую банку по протоколу 3-D Secure</p>`,'how');
}
function cardFormHTML(){
  return `<div class="bs-top">${tl('tax','shield-check')}<div class="mid"><b>«Оптима Банк»</b><span>Защищённая форма · демо</span></div></div>
   <p class="sub">В прототипе поля заполнены примером и недоступны для ввода — настоящую карту здесь привязать нельзя.</p>
   <div class="field"><label for="cf-n">Номер карты</label><div class="inp"><input id="cf-n" value="5169 •••• •••• 4409" readonly disabled></div></div>
   <div class="kpi" style="margin-top:10px"><div><span>Срок</span><b>09/29</b></div><div><span>CVV</span><b>•••</b></div></div>
   <div class="field" style="margin-top:12px"><label for="cf-h">Владелец</label><div class="inp"><input id="cf-h" value="AIGERIM TOKTOGULOVA" readonly disabled></div></div>
   <button class="btn btn-p" data-act="card-save">Привязать карту</button>
   <button class="btn btn-s" data-act="close">Отмена</button>`;
}
function svcPre(svc,acc,name){
  svcSheet(svc);SD.acc=acc;if(name)SD.name=name;setBody(svcHTML());
}
function svcSheet(svc,src){""")

# карты из состояния в списке способов оплаты
rep("const pmList=()=>`<div class=\"pms\">${PMS.map(","const pmAll=()=>[...PMS,...st.cards];\nconst pmList=()=>`<div class=\"pms\">${pmAll().map(")
rep("const pmById=id=>PMS.find(p=>p.id===id)||PMS[1];","const pmById=id=>[...PMS,...(st.cards||[])].find(p=>p.id===id)||PMS[1];")
rep("  el.innerHTML=PMS.map(p=>","  el.innerHTML=[...PMS,...st.cards].map(p=>")
io.open(P,'w',encoding='utf-8').write(s)
print('p5 ok')
