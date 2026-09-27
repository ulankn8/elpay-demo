# -*- coding: utf-8 -*-
"""Аудит блок C: поиск и остаток билетов в маркете, реальная передача билета
и «поделиться», сроки оплаты в ленте, честный чек-лист, остаток при частичной
оплате, платежи по счёту, пустая история."""
import io, json
P='index.html'; s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old); assert n==cnt,'expected %d, found %d: %r'%(cnt,n,old[:110]); s=s.replace(old,new)

CSS = """
/* ===== Сроки, остаток билетов, передача ===== */
.evt .pr em{font-style:normal;font-weight:600;color:var(--muted)}
.evt .pr em.few{color:#B4531A}
.mk-q{margin:12px 0 2px}
.chip.due{background:#FBF0DD;color:#8A5C0F}
.pt-left{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin-top:8px;padding:0 4px;font-size:13px;color:var(--muted)}
.pt-left b{font-size:14px;font-weight:700;color:var(--gr)}
"""
END = '.danger-row{color:#B23A3A}\n</style>'
rep(END, '.danger-row{color:#B23A3A}' + CSS + '</style>')

# ---------- C3: просроченный счёт в демо ----------
rep("{id:'water-2',svc:'water',name:'Вода родителей',acc:'31-01187',amount:150,who:'o2'}",
    "{id:'water-2',svc:'water',name:'Вода родителей',acc:'31-01187',amount:150,who:'o2',dueDay:18}")
rep("""dueDay:s.dueDay||25,due:(s.dueDay||25)+' сентября',dueShort:'до '+(s.dueDay||25)+' сент'};});""",
    """dueDay:c.dueDay||s.dueDay||25,due:(c.dueDay||s.dueDay||25)+' сентября',dueShort:'до '+(c.dueDay||s.dueDay||25)+' сент'};});""")

# ---------- C3: срок вместо сухой даты ----------
rep("""${st.paid[b.id]?okChip():st.qd[b.id]?`<span class="chip info sm">${tx('В очереди')}</span>`:st.auto[b.id]?`<span class="chip info sm">${ic('repeat',12,3)}${tx('Автоплатёж')}</span>`:st.dsp[b.id]?`<span class="chip warn sm">${tx('Спор')}</span>`:b.part?`<span class="chip warn sm">${tx('Частично')}</span>`:`<span class="chip soft sm">${b.dueShort}</span>`}""",
    """${st.paid[b.id]?okChip():st.qd[b.id]?`<span class="chip info sm">${tx('В очереди')}</span>`:st.auto[b.id]?`<span class="chip info sm">${ic('repeat',12,3)}${tx('Автоплатёж')}</span>`:st.dsp[b.id]?`<span class="chip warn sm">${tx('Спор')}</span>`:b.part?`<span class="chip warn sm">${tx('Частично')}</span>`:dueChip(b)}""")
rep("""  const soon=due.length?(due.some(b=>!b.tpl)?'25 сент':Math.min(...due.map(b=>TPL[b.tpl].day))+' окт'):'';
  const byAmt=""","""  const soon=dueSoon(due);
  const byAmt=""")
rep("""  const soon=due.length?(due.some(b=>!b.tpl)?'25 сент':Math.min(...due.map(b=>TPL[b.tpl].day))+' окт'):'';
  el.innerHTML=`<span class="stack">""","""  const soon=dueSoon(due);
  el.innerHTML=`<span class="stack">""")

# ---------- C4: честный чек-лист ----------
rep("""   {ok:!!st.cardOk,t:'Привязать карту',act:'toast',id:'',msg:'В демо привязана карта Visa •••• 4417'},""",
    """   {ok:(st.cards||[]).length>0,t:'Привязать свою карту',act:'pm-add',id:''},""")

# ---------- C5: остаток при частичной оплате ----------
rep("""   <button class="btn btn-p" style="margin-top:16px" data-act="pt-go">${F.pay(fmt(PART.v))}</button>""",
    """   <div class="pt-left"><span>${tx('Останется по счёту')}</span><b class="num">${fmt(Math.max(0,Math.round((b.amount-PART.v)*100)/100))} сом</b></div>
   <button class="btn btn-p" style="margin-top:12px" data-act="pt-go">${F.pay(fmt(PART.v))}</button>""")

# ---------- C6: платежи по счёту ----------
rep("""    ${b.hist?bars(b):''}
    ${ctrlBlock(b)}""",
    """    ${b.hist?bars(b):''}
    ${billHist(b)}
    ${ctrlBlock(b)}""")

# ---------- C2: поделиться квитанциями ----------
rep("""<button class="btn btn-s" data-act="toast" data-msg="Ссылка на квитанции скопирована"><i data-i="share-2" data-s="20"></i>Поделиться квитанциями</button>""",
    """<button class="btn btn-s" data-act="share-rcpt"><i data-i="share-2" data-s="20"></i>Поделиться квитанциями</button>""")
rep("""    <button class="btn btn-s" data-act="toast" data-msg="Билет отправлен — получатель откроет его в ЭлPay">${ic('share-2',20)}Передать билет</button>""",
    """    <button class="btn btn-s" data-act="tk-share" data-id="${t.id}">${ic('share-2',20)}Передать билет</button>""")

# ---------- C1: маркет — поиск, остаток, возврат ----------
rep("sec:[['Партер','1–6 ряд',1500],['Амфитеатр','7–14 ряд',900],['Балкон','свободные места',600]]}",
    "left:42,sec:[['Партер','1–6 ряд',1500],['Амфитеатр','7–14 ряд',900],['Балкон','свободные места',600]]}")
rep("sec:[['Партер','1–8 ряд',700],['Балкон','свободные места',400]]}",
    "left:86,sec:[['Партер','1–8 ряд',700],['Балкон','свободные места',400]]}")
rep("sec:[['VIP-диван','последний ряд',350],['Обычное место','ряды 3–8',250]]}",
    "left:14,sec:[['VIP-диван','последний ряд',350],['Обычное место','ряды 3–8',250]]}")
rep("sec:[['Западная трибуна','центр поля',500],['Восточная трибуна','за воротами',200]]}",
    "left:240,sec:[['Западная трибуна','центр поля',500],['Восточная трибуна','за воротами',200]]}")
rep("sec:[['Танцевальная зона','стоя у сцены',450],['Столик на четверых','с местами',1600]]}",
    "left:64,sec:[['Танцевальная зона','стоя у сцены',450],['Столик на четверых','с местами',1600]]}")
rep("sec:[['Любое место','зал 1',180]]}","left:120,sec:[['Любое место','зал 1',180]]}")

rep("""<span class="mid"><b>${e.t}</b><span class="vn"><em>${e.v}</em> · ${e.time}</span><span class="pr">${F.evtFrom(fmt(evtMin(e)))}</span></span>""",
    """<span class="mid"><b>${e.t}</b><span class="vn"><em>${e.v}</em> · ${e.time}</span><span class="pr">${F.evtFrom(fmt(evtMin(e)))}<em class="${e.left<20?'few':''}"> · ${F.left(e.left)}</em></span></span>""")

rep("""  const f=st.mkF||'all',tk=st.tickets||[],n=tk.reduce((a,t)=>a+t.n,0);
  const list=EVENTS.filter(e=>f==='all'||e.k===f).slice().sort((a,b)=>a.iso.localeCompare(b.iso));""",
    """  const tk=st.tickets||[],n=tk.reduce((a,t)=>a+t.n,0);""")
rep("""  <div class="qr-row">${MKF.map(([k,l])=>`<button class="qa${f===k?' on':''}" data-act="mk-filter" data-k="${k}">${l}</button>`).join('')}</div>
  <div class="mk-list">${list.map(evtCard).join('')||'<p class="empty">В этой категории пока ничего нет</p>'}</div>
  <p class="hint2">Маркет — точка роста ЭлPay: комиссия с продажи билетов и афиша городских событий рядом с коммунальными счетами.</p>`;
  if(ky())trTree(el);""",
    """  <div class="inp mk-q">${ic('search',20)}<input id="mk-q" type="search" placeholder="Событие, площадка или артист" value="${st.mkQ||''}" autocomplete="off"></div>
  <div class="qr-row">${MKF.map(([k,l])=>`<button class="qa${(st.mkF||'all')===k?' on':''}" data-act="mk-filter" data-k="${k}">${l}</button>`).join('')}</div>
  <div class="mk-list" id="mk-list"></div>
  <p class="hint2">Маркет — точка роста ЭлPay: комиссия с продажи билетов и афиша городских событий рядом с коммунальными счетами.</p>`;
  renderMkList();
  const inp=$('#mk-q');if(inp)inp.addEventListener('input',()=>{st.mkQ=inp.value;renderMkList();});
  if(ky())trTree(el);""")

rep("""   <div class="kv"><div><span>Место</span><b>${e.v}</b></div><div><span>Начало</span><b><em>${e.d}</em>, ${e.time}</b></div><div><span>Билет</span><b>Электронный, QR на входе</b></div></div>""",
    """   <div class="kv"><div><span>Место</span><b>${e.v}</b></div><div><span>Начало</span><b><em>${e.d}</em>, ${e.time}</b></div><div><span>Осталось билетов</span><b class="num">${e.left}</b></div><div><span>Возврат</span><b>${tx('До 24 часов до начала')}</b></div><div><span>Билет</span><b>${tx('Электронный, QR на входе')}</b></div></div>""")
rep("""   <div class="qty"><span>${F.tkQty(MK.n)}</span><span class="ctl"><button data-act="mk-qty" data-d="-1" aria-label="Меньше"${MK.n<=1?' disabled':''}>${ic('minus',18)}</button><b class="num">${MK.n}</b><button data-act="mk-qty" data-d="1" aria-label="Больше"${MK.n>=8?' disabled':''}>${ic('plus',18)}</button></span></div>""",
    """   <div class="qty"><span>${F.tkQty(MK.n)}</span><span class="ctl"><button data-act="mk-qty" data-d="-1" aria-label="Меньше"${MK.n<=1?' disabled':''}>${ic('minus',18)}</button><b class="num">${MK.n}</b><button data-act="mk-qty" data-d="1" aria-label="Больше"${MK.n>=Math.min(8,e.left)?' disabled':''}>${ic('plus',18)}</button></span></div>""")
rep("""  'mk-qty':t=>{if(MK){MK.n=Math.min(8,Math.max(1,MK.n+(+t.dataset.d)));setBody(evtHTML());}},""",
    """  'mk-qty':t=>{if(MK){MK.n=Math.min(Math.min(8,evtById(MK.id).left),Math.max(1,MK.n+(+t.dataset.d)));setBody(evtHTML());}},""")
rep("""  st.tickets.unshift(t);MK=null;""",
    """  st.tickets.unshift(t);e.left=Math.max(0,e.left-n);MK=null;""")

# ---------- C7: пустая история ----------
rep("""`<p class="empty">${tx(st.histCat||st.histPer!=='y'?'По этому фильтру платежей нет':'Ничего не нашли. Попробуйте «садик» или «свет»')}</p>`;""",
    """`<p class="empty">${tx(!histAll().length?'Здесь появятся квитанции после первой оплаты':st.histCat||st.histPer!=='y'?'По этому фильтру платежей нет':'Ничего не нашли. Попробуйте «садик» или «свет»')}</p>`;""")

JS = r"""/* ===== Аудит C: сроки, остаток билетов, передача, платежи по счёту ===== */
Object.assign(F,{
 left:n=>ky()?`${n} билет калды`:`осталось ${n}`,
 dueDays:n=>ky()?`${n} күн калды`:`осталось ${n} ${plural(n,'день','дня','дней')}`,
 overdue:n=>ky()?`${n} күнгө кечиктирилди`:`просрочено на ${n} ${plural(n,'день','дня','дней')}`,
 shareTo:n=>ky()?`Билет ${n} үчүн жөнөтүлдү`:`Билет передан: ${n}`});
function dueLeft(b){
  if(b.tpl)return (TPL[b.tpl].day+30)-TODAY.d;
  if(b.tax)return 30;
  return (b.dueDay||25)-TODAY.d;
}
function dueChip(b){
  const d=dueLeft(b);
  if(d<0)return `<span class="chip bad sm">${tx(F.overdue(-d))}</span>`;
  if(d===0)return `<span class="chip due sm">${tx('сегодня последний день')}</span>`;
  if(d<=3)return `<span class="chip due sm">${tx(F.dueDays(d))}</span>`;
  return `<span class="chip soft sm">${tx(b.dueShort)}</span>`;
}
function dueSoon(due){
  if(!due.length)return '';
  const b=due.slice().sort((x,y)=>dueLeft(x)-dueLeft(y))[0],d=dueLeft(b);
  return d<0?tx(F.overdue(-d)):d===0?tx('сегодня'):tx(b.dueShort).replace(/^до /,'');
}
function billHist(b){
  const c=svcCat(b),list=histAll().filter(r=>r.cat===c).slice(0,3);
  if(!list.length)return '';
  return `<div class="sec"><h3>Платежи по этому счёту</h3></div>
   <div class="group wrap">${list.map(histRow).join('')}</div>`;
}
function renderMkList(){
  const el=$('#mk-list');if(!el)return;
  const f=st.mkF||'all',q=(st.mkQ||'').trim().toLowerCase();
  const list=EVENTS.filter(e=>e.iso>=TODAY_ISO)
    .filter(e=>f==='all'||e.k===f)
    .filter(e=>!q||(e.t+' '+e.v+' '+tx(e.t)+' '+tx(e.v)+' '+((MKF.find(x=>x[0]===e.k)||[])[1]||'')).toLowerCase().includes(q))
    .slice().sort((a,b)=>a.iso.localeCompare(b.iso));
  el.innerHTML=list.map(evtCard).join('')||`<p class="empty">${tx(q?'Ничего не нашли — попробуйте «театр» или «кино»':'В этой категории пока ничего нет')}</p>`;
  if(ky())trTree(el);
}
const TODAY_ISO='2026-09-20';
function tkShare(id){
  const t=(st.tickets||[]).find(x=>x.id===id);if(!t)return;
  const e=evtById(t.evt),fam=st.fam.filter(m=>!m.you);
  openSheet(tx('Передать билет'),`<p class="sub">Получателю придёт свой QR, а ваш перестанет работать. Передать можно до начала события.</p>
   <div class="bs-top" style="margin-top:14px"><span class="tile" style="background:${evtGrad(e)};color:#fff">${ic(e.icon,22)}</span><div class="mid"><b>${e.t}</b><span><em>${e.d}</em> · ${e.time}</span></div></div>
   <div class="sec"><h3>Кому</h3></div>
   <div class="group wrap">${fam.map(m=>`<button class="row" data-act="tk-send" data-id="${t.id}" data-to="${m.id}"><span class="ava">${initials(m.n)}</span><span class="mid"><span class="t">${m.n}</span><span class="s">${tx(m.r)}</span></span>${ic('chevron-right',18)}</button>`).join('')||'<p class="empty">В семье пока никого нет</p>'}
   <button class="row" data-act="toast" data-msg="Введите номер получателя — в релизе"><span class="tile dash">${ic('plus')}</span><span class="mid"><span class="t">По номеру телефона</span><span class="s">Получателю придёт ссылка в SMS</span></span>${ic('chevron-right',18)}</button></div>`,'tks');
}
function tkSend(id,to){
  const t=(st.tickets||[]).find(x=>x.id===id),m=st.fam.find(x=>x.id===to);
  if(!t||!m)return;
  st.tickets=st.tickets.filter(x=>x.id!==id);
  closeSheet();renderAll();toast(F.shareTo(m.n.split(/\s+/)[0]));
}
function shareRcpt(){
  const n=(st.lastItems||[]).length;
  openSheet(tx('Поделиться'),`<p class="sub">${F.rcptN(n||1)} — отправим ссылку, по которой квитанции откроются без входа в приложение.</p>
   <div class="group wrap" style="margin-top:14px">
    <button class="row" data-act="toast" data-msg="Ссылка отправлена в WhatsApp">${tl('kid','share-2')}<span class="mid"><span class="t">WhatsApp</span><span class="s">Отправить получателю или в чат дома</span></span>${ic('chevron-right',18)}</button>
    <button class="row" data-act="toast" data-msg="Квитанции отправлены на aigerim@example.com">${tl('net','mail')}<span class="mid"><span class="t">На почту</span><span class="s">aigerim@example.com</span></span>${ic('chevron-right',18)}</button>
    <button class="row" data-act="toast" data-msg="Ссылка скопирована">${tl('city','copy')}<span class="mid"><span class="t">Скопировать ссылку</span><span class="s">Действует 30 дней</span></span>${ic('chevron-right',18)}</button>
   </div>`,'shr');
}
const CACT={
  'tk-share':t=>tkShare(t.dataset.id),
  'tk-send':t=>tkSend(t.dataset.id,t.dataset.to),
  'share-rcpt':()=>shareRcpt()
};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT,CRUDACT,PAYACT);",
    "Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT,CRUDACT,PAYACT,CACT);")

PAIRS=[('Событие, площадка или артист','Окуя, аянтча же артист'),
 ('Ничего не нашли — попробуйте «театр» или «кино»','Эч нерсе табылган жок — «театр» же «кино» деп көрүңүз'),
 ('Осталось билетов','Калган билеттер'),('Возврат','Кайтаруу'),
 ('До 24 часов до начала','Башталышына 24 саат калганга чейин'),
 ('Электронный, QR на входе','Электрондук, кире беришке QR'),
 ('сегодня последний день','бүгүн акыркы күн'),('сегодня','бүгүн'),
 ('Останется по счёту','Эсепте калат'),
 ('Платежи по этому счёту','Бул эсеп боюнча төлөмдөр'),
 ('Здесь появятся квитанции после первой оплаты','Биринчи төлөмдөн кийин бул жерде квитанциялар пайда болот'),
 ('Передать билет','Билетти өткөрүү'),
 ('Получателю придёт свой QR, а ваш перестанет работать. Передать можно до начала события.',
  'Алуучуга өз QR келет, сиздики иштебей калат. Окуя башталганга чейин өткөрүүгө болот.'),
 ('Кому','Кимге'),('В семье пока никого нет','Үй-бүлөдө азырынча эч ким жок'),
 ('По номеру телефона','Телефон номери боюнча'),
 ('Получателю придёт ссылка в SMS','Алуучуга SMS менен шилтеме келет'),
 ('Введите номер получателя — в релизе','Алуучунун номерин киргизүү — релизде'),
 ('Поделиться','Бөлүшүү'),('WhatsApp','WhatsApp'),
 ('Отправить получателю или в чат дома','Алуучуга же үй чатына жөнөтүү'),
 ('На почту','Почтага'),('Скопировать ссылку','Шилтемени көчүрүү'),
 ('Действует 30 дней','30 күн жарактуу'),
 ('Ссылка отправлена в WhatsApp','Шилтеме WhatsApp аркылуу жөнөтүлдү'),
 ('Квитанции отправлены на aigerim@example.com','Квитанциялар aigerim@example.com дарегине жөнөтүлдү'),
 ('Ссылка скопирована','Шилтеме көчүрүлдү'),
 ('Привязать свою карту','Өз картаңызды байлоо')]
i=s.find('const KY='); j=s.find(';\n',i)
KY=json.loads(s[i+len('const KY='):j]); a=0
for ru,ky in PAIRS:
    if ru not in KY: KY[ru]=ky; a+=1
s=s[:i+len('const KY=')]+json.dumps(KY,ensure_ascii=False,separators=(',',':'))+s[j:]
io.open(P,'w',encoding='utf-8').write(s); print('ok, ky added:',a)
