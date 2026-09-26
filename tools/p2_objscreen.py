# -*- coding: utf-8 -*-
"""v2.8 шаг 2: экран объектов, шторка объекта с выбором иконки."""
import io
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:90]!r}'
    s=s.replace(old,new)

# --- иконки объектов ---
rep("'qr':'<rect",
"""'trees':'<path d="M10 10v.2A3 3 0 0 1 8.9 16H5a3 3 0 0 1-1-5.8V10a3 3 0 0 1 6 0Z"/><path d="M7 16v6"/><path d="M13 19v3"/><path d="M12 19h8.3a1 1 0 0 0 .7-1.7L18 14h.3a1 1 0 0 0 .7-1.7L16 9h.2a1 1 0 0 0 .8-1.7L13 3l-1.4 1.5"/>',
'briefcase':'<path d="M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/><rect width="20" height="14" x="2" y="6" rx="2"/>',
'store':'<path d="m2 7 4.41-4.41A2 2 0 0 1 7.83 2h8.34a2 2 0 0 1 1.42.59L22 7"/><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><path d="M15 22v-4a2 2 0 0 0-2-2h-2a2 2 0 0 0-2 2v4"/><path d="M2 7h20"/>',
'car':'<path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/>',
'warehouse':'<path d="M22 8.35V20a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8.35A2 2 0 0 1 3.26 6.5l8-3.2a2 2 0 0 1 1.48 0l8 3.2A2 2 0 0 1 22 8.35Z"/><path d="M6 18h12"/><path d="M6 14h12"/>',
'qr':'<rect""")

# --- стили ---
rep(".group.wrap .t,.group.wrap .s{white-space:normal}",
""".minitiles.ic5{grid-template-columns:repeat(5,1fr);gap:8px}
.minitiles.ic5 .mt{padding:9px 4px}
.minitiles.ic5 .mt .tile{width:40px;height:40px;border-radius:12px}
.obj-hero{display:flex;align-items:center;gap:14px;padding:18px;border-radius:22px;background:var(--bg);box-shadow:var(--sh-sm)}
.obj-hero .tile{width:56px;height:56px;border-radius:18px}
.obj-hero b{display:block;font-size:19px;font-weight:700}
.obj-hero span{display:block;font-size:13px;color:var(--muted);margin-top:2px}
.group.wrap .t,.group.wrap .s{white-space:normal}""")

# --- экран объектов ---
rep('          <!-- 19. Оплата по QR -->',
"""          <!-- 20. Объекты -->
          <section class="scr" id="s-obj"><div class="body" id="obj-body"></div></section>

          <!-- 19. Оплата по QR -->""")

# --- отрисовка ---
rep("function renderPM(){",
"""function objRow(o){
  const list=objBills(o.id),due=list.filter(b=>!st.paid[b.id]);
  return `<button class="row" data-act="obj-open" data-id="${o.id}">${objTile(o.id)}<span class="mid"><span class="t">${tx(o.name)}</span><span class="s">${o.addr||F.billsN(list.length)}</span></span><span class="end"><span class="amt num">${fmt(total(due))} <small>сом</small></span><span class="s">${F.billsN(list.length)}</span></span></button>`;
}
function renderObjs(){
  const el=$('#obj-body');if(!el)return;
  if(st.objId&&st.obj.some(o=>o.id===st.objId))return renderObj(el);
  el.innerHTML=`<div class="nav"><button class="nb" data-act="back" aria-label="Назад">${ic('chevron-left',24)}</button><span class="nt">Мои объекты</span><span class="sp"></span></div>
  <p class="sub">Дом, квартира родителей, дача или офис — у каждого свои счета, и они не смешиваются.</p>
  <div class="group wrap" style="margin-top:14px">${st.obj.map(objRow).join('')}
   <button class="row" data-act="obj-new"><span class="tile dash">${ic('plus')}</span><span class="mid"><span class="t">Новый объект</span><span class="s">Название и иконка на выбор</span></span>${ic('chevron-right',18)}</button></div>`;
  if(ky())trTree(el);
}
function renderObj(el){
  const o=objById(st.objId),list=objBills(o.id),due=list.filter(b=>!st.paid[b.id]);
  el.innerHTML=`<div class="nav"><button class="nb" data-act="obj-back" aria-label="Назад">${ic('chevron-left',24)}</button><span class="nt">${tx(o.name)}</span><button class="nb" data-act="obj-edit" data-id="${o.id}" aria-label="Изменить объект">${ic('square-pen',20)}</button></div>
  <div class="obj-hero">${objTile(o.id,26)}<div class="mid"><b>${tx(o.name)}</b><span>${o.addr||tx('Адрес не указан')}</span></div><span class="end"><span class="amt num">${fmt(total(due))} <small>сом</small></span><span class="s">${F.billsN(list.length)}</span></span></div>
  <div class="sec"><h3>Счета объекта</h3></div>
  <div class="group wrap">${list.length?list.map(billRow).join(''):'<p class="empty">Здесь пока нет счетов</p>'}
   <button class="row" data-act="obj-add" data-id="${o.id}"><span class="tile dash">${ic('plus')}</span><span class="mid"><span class="t">Добавить счёт</span><span class="s">Коммуналка, садик или свой получатель</span></span>${ic('chevron-right',18)}</button></div>`;
  if(ky())trTree(el);
}
function renderPM(){""")
rep("renderHist();renderPM();renderNotif();","renderHist();renderPM();renderNotif();renderObjs();")

# --- шторка объекта ---
rep("let SD=null;",
"""let OBJD=null,OBJCB=null;
function objHTML(){
  return `<div class="field"><label for="ob-name">Название</label><div class="inp"><input id="ob-name" value="${OBJD.name||''}" placeholder="Дом, Квартира, Родители"></div></div>
   <div class="field"><span class="lbl">Иконка</span><div class="minitiles ic5">${OBJICONS.map(i=>`<button class="mt${OBJD.icon===i?' on':''}" data-act="ob-ic" data-i="${i}" aria-label="${i}">${tl(OBJI[i],i,20)}<span class="ck">${ic('check',12,3)}</span></button>`).join('')}</div></div>
   <div class="field"><label for="ob-addr">Адрес <span class="opt">необязательно</span></label><div class="inp">${ic('map-pin',20)}<input id="ob-addr" value="${OBJD.addr||''}" placeholder="Ош, ул. Масалиева, 44"></div><p class="hint">Нужен для уведомлений об отключениях</p></div>
   <button class="btn btn-p" data-act="ob-save">${OBJD.id?'Сохранить':'Создать объект'}</button>
   ${OBJD.id&&st.obj.length>1?`<button class="btn danger-btn" data-act="ob-del">${ic('trash-2',20)}Удалить объект</button>`:''}`;
}
function objSheet(src,cb){
  OBJD=src?{...src}:{name:'',icon:'house',addr:''};OBJCB=cb||null;
  openSheet(src?'Изменить объект':'Новый объект',objHTML(),'ob');
}
let SD=null;""")

# --- действия ---
rep("  'pm-add':()=>toast",
"""  'obj-open':t=>{st.objId=t.dataset.id;st.objSel=t.dataset.id;renderObjs();},
  'obj-back':()=>{if(st.objId){st.objId=null;renderObjs();}else go(st.tab,'back');},
  'obj-list':()=>{st.objId=null;renderObjs();go('obj');},
  'obj-new':()=>objSheet(null),
  'obj-edit':t=>objSheet(objById(t.dataset.id)),
  'obj-add':t=>{st.objSel=t.dataset.id;openCat('util');},
  'ob-ic':t=>{OBJD.name=$('#ob-name').value;OBJD.addr=$('#ob-addr').value;OBJD.icon=t.dataset.i;setBody(objHTML());},
  'ob-save':()=>{
    const name=$('#ob-name').value.trim(),addr=$('#ob-addr').value.trim();
    $$('#sh-body .field').forEach(f=>f.classList.remove('err'));
    if(name.length<2)return fErr('#ob-name','Введите название — например, «Дача»');
    let id=OBJD.id;
    if(id){const o=objById(id);o.name=name;o.addr=addr;o.icon=OBJD.icon;o.c=OBJI[OBJD.icon];}
    else{id=objId();st.obj.push({id,name,icon:OBJD.icon,c:OBJI[OBJD.icon],addr});}
    const cb=OBJCB;OBJCB=null;closeSheet();renderAll();
    if(cb)return setTimeout(()=>cb(id),240);
    toast(OBJD.id?'Объект обновлён':F.objAdded(name));
  },
  'ob-del':()=>{
    const o=objById(OBJD.id),rest=st.obj.find(x=>x.id!==o.id);
    confirmSheet('Удалить объект?',F.objDelQ(tx(o.name),tx(rest.name)),'Удалить',()=>{
      st.conn.forEach(c=>{if(whoOf(c)===o.id)c.who=rest.id;});
      st.custom.forEach(c=>{if(whoOf(c)===o.id)c.who=rest.id;});
      st.obj=st.obj.filter(x=>x.id!==o.id);
      if(st.objId===o.id)st.objId=null;
      closeSheet();renderAll();toast('Объект удалён');
    });
  },
  'pm-add':()=>toast""")
io.open(P,'w',encoding='utf-8').write(s)
print('p2 ok')
