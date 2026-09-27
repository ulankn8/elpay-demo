# -*- coding: utf-8 -*-
"""Аудит A5–A13 и B1–B4: история по дате платежа, ближайший билет, период отчёта,
квитанция билета, автоплатёж, билеты в отчётах, поиск по маркету, дубли и переносы,
демо-данные (садик, «начислено» vs «оплачено», сроки поставщиков, даты спора)."""
import io, json
P='index.html'; s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old); assert n==cnt,'expected %d, found %d: %r'%(cnt,n,old[:110]); s=s.replace(old,new)

# ============ B4: свои сроки у поставщиков ============
rep("{id:'trash',name:'Ош-Тазалык',kind:'Вывоз мусора',icon:'trash-2',acc:'04-118725',amount:180,",
    "{id:'trash',name:'Ош-Тазалык',kind:'Вывоз мусора',icon:'trash-2',acc:'04-118725',amount:180,dueDay:28,")
rep("{id:'power',name:'Электросеть',kind:'Электроэнергия',icon:'zap',acc:'7710-3348',amount:564.44,",
    "{id:'power',name:'Электросеть',kind:'Электроэнергия',icon:'zap',acc:'7710-3348',amount:564.44,dueDay:25,")
rep("{id:'water',name:'Водоканал',kind:'Холодная вода',icon:'droplet',acc:'31-00562',amount:205,",
    "{id:'water',name:'Водоканал',kind:'Холодная вода',icon:'droplet',acc:'31-00562',amount:205,dueDay:25,")
rep("{id:'gas',name:'Газовая служба',kind:'Природный газ',icon:'flame',acc:'55-20841',amount:420,",
    "{id:'gas',name:'Газовая служба',kind:'Природный газ',icon:'flame',acc:'55-20841',amount:420,dueDay:22,")
rep("{id:'net',name:'Интернет и ТВ',kind:'Домашний интернет',icon:'wifi',acc:'IP-77301',amount:900,",
    "{id:'net',name:'Интернет и ТВ',kind:'Домашний интернет',icon:'wifi',acc:'IP-77301',amount:900,dueDay:30,")
rep("{id:'door',name:'Домофон',kind:'Обслуживание подъезда',icon:'door-closed',acc:'DM-2214',amount:100,",
    "{id:'door',name:'Домофон',kind:'Обслуживание подъезда',icon:'door-closed',acc:'DM-2214',amount:100,dueDay:27,")

rep("""name:c.name||s.name,short:c.name||s.name,sub:s.kind,due:'25 сентября',dueShort:'до 25 сент'};});""",
    """name:c.name||s.name,short:c.name||s.name,sub:s.kind,dueDay:s.dueDay||25,due:(s.dueDay||25)+' сентября',dueShort:'до '+(s.dueDay||25)+' сент'};});""")

# ============ B1: садик в исторических данных ============
rep("trash:[180,180,180,180,180,180,180,180,180,180,180],kid:[3500,3500,3500,3500,3500,3500,3500,3500,3500,0,0],",
    "trash:[180,180,180,180,180,180,180,180,180,180,180],kid:[3500,3500,3500,3500,3500,3500,3500,3500,3500,0,3500],")

# ============ A5: история группируется по дате платежа ============
rep("""    out.push({id:'g'+i+k,mi:i,cat:k,""", """    out.push({id:'g'+i+k,mi:i,pm:i+1,cat:k,""")
rep("""  items.forEach((b,i)=>st.hist.unshift({id:'p'+Date.now()+i,mi:11,cat:svcCat(b),""",
    """  items.forEach((b,i)=>st.hist.unshift({id:'p'+Date.now()+i,mi:11,pm:11,cat:svcCat(b),""")
rep("""  const list=histAll().filter(r=>m(r.name,r.sub,tx(r.name),tx(r.sub))&&(!st.histCat||r.cat===st.histCat)&&months.includes(r.mi));
  const gs=[];list.forEach(r=>{let g=gs.find(x=>x.mi===r.mi);if(!g)gs.push(g={mi:r.mi,list:[],sum:0});g.list.push(r);g.sum+=r.amount;});""",
    """  const list=histAll().filter(r=>m(r.name,r.sub,tx(r.name),tx(r.sub))&&(!st.histCat||r.cat===st.histCat)&&months.includes(hm(r)));
  const gs=[];list.forEach(r=>{const k=hm(r);let g=gs.find(x=>x.mi===k);if(!g)gs.push(g={mi:k,list:[],sum:0});g.list.push(r);g.sum+=r.amount;});""")
rep("  const all=histAll(),cur=all.filter(r=>r.mi===11).reduce((a,b)=>a+b.amount,0);",
    "  const all=histAll(),cur=all.filter(r=>hm(r)===11).reduce((a,b)=>a+b.amount,0);")
rep("const expRows=()=>histAll().filter(r=>expMonths().includes(r.mi));",
    "const expRows=()=>histAll().filter(r=>expMonths().includes(hm(r)));")

# ============ A6: билеты по ближайшей дате ============
rep("d:'12 октября',dd:'12',dm:'окт',time:'19:00'","d:'12 октября',dd:'12',dm:'окт',iso:'2026-10-12',time:'19:00'")
rep("d:'18 октября',dd:'18',dm:'окт',time:'18:00'","d:'18 октября',dd:'18',dm:'окт',iso:'2026-10-18',time:'18:00'")
rep("d:'сегодня',dd:'20',dm:'сен',time:'19:20'","d:'сегодня',dd:'20',dm:'сен',iso:'2026-09-20',time:'19:20'")
rep("d:'5 октября',dd:'5',dm:'окт',time:'15:00'","d:'5 октября',dd:'5',dm:'окт',iso:'2026-10-05',time:'15:00'")
rep("d:'27 сентября',dd:'27',dm:'сен',time:'20:00'","d:'27 сентября',dd:'27',dm:'сен',iso:'2026-09-27',time:'20:00'")
rep("d:'28 сентября',dd:'28',dm:'сен',time:'11:00'","d:'28 сентября',dd:'28',dm:'сен',iso:'2026-09-28',time:'11:00'")
rep("""  const list=EVENTS.filter(e=>f==='all'||e.k===f);""",
    """  const list=EVENTS.filter(e=>f==='all'||e.k===f).slice().sort((a,b)=>a.iso.localeCompare(b.iso));""")
rep("""<span>${F.tkMeta(n,evtById(tk[0].evt).d)}</span>""",
    """<span>${F.tkMeta(n,evtById(tkNear().evt).d)}</span>""")

# ============ A7: карточка отчёта следует периоду ============
rep("""function repCard(o){
  const m=repMonths(o?o.id:null),cur=m[11];
  const cats=Object.entries(cur.by).sort((a,b)=>b[1]-a[1]);""",
    """function repCard(o){
  const m=repMonths(o?o.id:null),year=st.repMode==='year';
  const cur=year?{total:m.reduce((a,x)=>a+x.total,0),by:m.reduce((acc,x)=>{for(const k in x.by)acc[k]=(acc[k]||0)+x.by[k];return acc;},{})}:m[st.repM];
  const cats=Object.entries(cur.by).sort((a,b)=>b[1]-a[1]);""")
rep("""   <div class="hero-top"><span>Расходы в сентябре</span></div>""",
    """   <div class="hero-top"><span>${year?tx('Начислено за 12 месяцев'):tx('Начислено')+' · '+m[st.repM].label}</span></div>""")
rep("""   ${cats.length?`<div class="split">""","""   ${cats.length?`<div class="split">""")
rep("""'<div class="hero-meta">Пока нет расходов</div>'}</div>`;
}""","""'<div class="hero-meta">Пока нет начислений</div>'}</div>`;
}""")

# ============ B2: «начислено» вместо «расходов» ============
rep("""<span style="font-size:13px;color:#6B7772">Расходы за месяц</span>""",
    """<span style="font-size:13px;color:#6B7772">Начислено за месяц</span>""")
rep("""<div class="sec"><h3>Куда ушли деньги</h3></div>""",
    """<div class="sec"><h3>На что начислено</h3><span class="s">${F.paidOf(fmt(cur.paid||0),fmt(cur.total))}</span></div>""")
rep("""'<p class="empty">В этом месяце расходов не было</p>'}""",
    """'<p class="empty">В этом месяце начислений не было</p>'}""")
rep("""  el.innerHTML=`<span class="mini">${last.map((x,i)=>`<i class="${i===5?'on':''}" style="height:${Math.max(6,Math.round(x.total/mx*42))}px"></i>`).join('')}</span>
   <span class="mid"><b class="num">${fmt(m[11].total)} сом</b><span>${ADDRS.length>1?'Расходы в сентябре · все адреса':'Расходы в сентябре · смотреть отчёт'}</span></span>${ic('chevron-right',20)}`;""",
    """  el.innerHTML=`<span class="mini">${last.map((x,i)=>`<i class="${i===5?'on':''}" style="height:${Math.max(6,Math.round(x.total/mx*42))}px"></i>`).join('')}</span>
   <span class="mid"><b class="num">${fmt(m[11].total)} сом</b><span>${ADDRS.length>1?'Начислено в сентябре · все адреса':'Начислено в сентябре · смотреть отчёт'}</span></span>${ic('chevron-right',20)}`;""")

# ============ A8: квитанция билета ============
rep("""${r.acc&&r.acc!=='—'?`<div><span>Лицевой счёт</span><b>${r.acc}</b></div>`:''}""",
    """${r.acc&&r.acc!=='—'?`<div><span>${r.cat==='market'?tx('Номер билета'):tx('Лицевой счёт')}</span><b>${r.acc}</b></div>`:''}""")
rep("""   ['Способ оплаты',tx(pmById(st.pm).t)],['Комиссия','0 сом'],['Статус','Исполнено']];""",
    """   ['Способ оплаты',tx(pmById(st.pm).t)],['Комиссия','0 сом'],['Статус','Исполнено']];
  if(r.cat==='market')rows[5]=['Номер билета',r.acc||'—'];""")

# ============ A9: автоплатёж виден и не выбран по умолчанию ============
rep("""${st.paid[b.id]?okChip():st.qd[b.id]?`<span class="chip info sm">${tx('В очереди')}</span>`:st.dsp[b.id]?""",
    """${st.paid[b.id]?okChip():st.qd[b.id]?`<span class="chip info sm">${tx('В очереди')}</span>`:st.auto[b.id]?`<span class="chip info sm">${ic('repeat',12,3)}${tx('Автоплатёж')}</span>`:st.dsp[b.id]?""")
rep("function openCheckout(ids){\n  st.sel=[...ids];const items=ids.map(billById);",
    "function openCheckout(ids){\n  st.sel=ids.filter(id=>!st.auto[id]);if(!st.sel.length)st.sel=[...ids];const items=ids.map(billById);")
rep("""<div class="row pi${items.length>1?' pay':''}" data-act="pi" data-id="${b.id}" aria-pressed="true">""",
    """<div class="row pi${items.length>1?' pay':''}" data-act="pi" data-id="${b.id}" aria-pressed="${st.sel.includes(b.id)}">""")

# ============ A10: билеты в отчётах + цвета категорий ============
rep("const COL={water:'#3F7BE0',power:'#E0A93F',trash:'#F0643F',kid:'#E0428D',school:'#6B55EC',city:'#3C4A55'};",
    "const COL={water:'#3F7BE0',power:'#E0A93F',trash:'#F0643F',kid:'#E0428D',school:'#6B55EC',city:'#3C4A55',gas:'#C0553F',net:'#6B7EE0',door:'#5E6E8C',course:'#9B51E0',tax:'#55636E',market:'#2AA3C7'};")
rep("""  (oid?objBills(oid):allBills()).forEach(b=>{const c=svcCat(b);cur[c]=(cur[c]||0)+b.amount;});""",
    """  (oid?objBills(oid):allBills()).forEach(b=>{const c=svcCat(b);cur[c]=(cur[c]||0)+b.amount;});
  if(!oid)st.hist.filter(r=>r.cat==='market').forEach(r=>{cur.market=(cur.market||0)+r.amount;});""")
rep("""    return {label,short:RMON[i],by,total:Object.values(by).reduce((a,b)=>a+b,0)};""",
    """    const total=Object.values(by).reduce((a,b)=>a+b,0);
    const paid=i===11?(oid?objBills(oid):allBills()).filter(b=>st.paid[b.id]).reduce((a,b)=>a+b.amount,0):total;
    return {label,short:RMON[i],by,total,paid};""")

# ============ A11: поиск по маркету ============
rep("""placeholder="Поставщик, садик или школа\"""","""placeholder="Поставщик, садик, школа или событие\"""")
rep("""  if(q&&hist.length)h+=`<div class="sec"><h3>История</h3></div>""",
    """  const evs=q?EVENTS.filter(e=>(e.t+' '+e.v+' '+tx(e.t)+' '+MKF.map(x=>x[1]).join(' ')+' билет концерт театр кино спорт афиша').toLowerCase().includes(q)):[];
  if(evs.length)h+=`<div class="sec"><h3>Маркет</h3></div><div class="group wrap">${evs.map(e=>`<button class="row" data-act="evt" data-id="${e.id}">${tl('market',e.icon)}<span class="mid"><span class="t">${e.t}</span><span class="s">${tx(e.v)}<em> · ${e.d}</em></span></span>${ic('chevron-right',18)}</button>`).join('')}</div>`;
  if(q&&hist.length)h+=`<div class="sec"><h3>История</h3></div>""")

# ============ A12: без дубля объекта в реквизитах ============
rep("""const connRow=c=>{const s=UTIL.find(x=>x.id===c.svc)||{};return `<button class="row" data-act="edit-util" data-id="${c.id}">${tile(s)}<span class="mid"><span class="t">${c.name||s.name}</span><span class="s">${F.acc(c.acc)}${st.auto[c.id]?' · '+tx('автоплатёж'):''}${st.obj.length>1?' · '+objName(whoOf(c)):''}</span></span>${ic('square-pen',18)}</button>`;};""",
    """const connRow=(c,noObj)=>{const s=UTIL.find(x=>x.id===c.svc)||{};return `<button class="row" data-act="edit-util" data-id="${c.id}">${tile(s)}<span class="mid"><span class="t">${c.name||s.name}</span><span class="s">${F.acc(c.acc)}${st.auto[c.id]?' · '+tx('автоплатёж'):''}${!noObj&&st.obj.length>1?' · '+objName(whoOf(c)):''}</span></span>${ic('square-pen',18)}</button>`;};""")
rep("""<div class="group wrap">${g.list.map(connRow).join('')}</div>`).join('')""",
    """<div class="group wrap">${g.list.map(c=>connRow(c,1)).join('')}</div>`).join('')""")

# ============ A13: длинные подписи переносятся ============
rep("""  if(!q)h+=`<div class="group" style="margin-top:4px"><button class="row" data-act="pay-new">""",
    """  if(!q)h+=`<div class="group wrap" style="margin-top:4px"><button class="row" data-act="pay-new">""")

# ============ B3: дата ответа по спору считается от «сегодня» ============
rep("""${tx(d.done?'решено: перерасчёт поставщиком':'на рассмотрении, ответ до 24 сентября')}""",
    """${d.done?tx('решено: перерасчёт поставщиком'):F.dspWait(dPlus(4))}""")
rep("""  toast('Обращение отправлено — ответ до 24 сентября');""",
    """  toast(F.dspSent(dPlus(4)));""")

JS = r"""/* ===== Аудит A5–B3: вспомогательные ===== */
const hm=r=>r.pm==null?r.mi:r.pm;
const tkNear=()=>[...(st.tickets||[])].sort((a,b)=>evtById(a.evt).iso.localeCompare(evtById(b.evt).iso))[0]||st.tickets[0];
const dPlus=n=>{const d=TODAY.d+n;return d+' '+MONG[TODAY.m];};
Object.assign(F,{
 paidOf:(p,t)=>ky()?`${t} сомдун ${p} төлөндү`:`оплачено ${p} из ${t}`,
 dspWait:d=>ky()?`каралууда, жооп ${d}га чейин`:`на рассмотрении, ответ до ${d}`,
 dspSent:d=>ky()?`Кайрылуу жөнөтүлдү — жооп ${d}га чейин`:`Обращение отправлено — ответ до ${d}`});

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")

PAIRS=[('Начислено','Эсептелди'),('Начислено за 12 месяцев','12 айда эсептелди'),
 ('Начислено за месяц','Айга эсептелди'),('На что начислено','Эмнеге эсептелди'),
 ('Пока нет начислений','Азырынча эсептөө жок'),('В этом месяце начислений не было','Бул айда эсептөө болгон жок'),
 ('Начислено в сентябре · все адреса','Сентябрда эсептелди · бардык даректер'),
 ('Начислено в сентябре · смотреть отчёт','Сентябрда эсептелди · отчётту кароо'),
 ('Номер билета','Билеттин номери'),('Лицевой счёт','Жеке эсеп'),('Автоплатёж','Автотөлөм'),
 ('Маркет','Маркет'),('Поставщик, садик, школа или событие','Камсыздоочу, бала бакча, мектеп же окуя')]
i=s.find('const KY='); j=s.find(';\n',i)
KY=json.loads(s[i+len('const KY='):j]); a=0
for ru,ky in PAIRS:
    if ru not in KY: KY[ru]=ky; a+=1
s=s[:i+len('const KY=')]+json.dumps(KY,ensure_ascii=False,separators=(',',':'))+s[j:]
io.open(P,'w',encoding='utf-8').write(s); print('ok, ky added:',a)
