# -*- coding: utf-8 -*-
"""v3.0 (поверх v2.9): карусель на pointer-событиях, карточки в отчётах,
правка счетов внутри объекта, надпись «Оплатить» в листе оплаты."""
import io,json
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:100]!r}'
    s=s.replace(old,new)

# ================= 1. стили =================
rep(""".heroes{display:flex;gap:12px;overflow-x:auto;scroll-snap-type:x mandatory;scrollbar-width:none;-webkit-overflow-scrolling:touch;margin:0 -20px;padding:2px 20px}
.heroes::-webkit-scrollbar{display:none}
.heroes .hero{flex:0 0 calc(100% - 34px);scroll-snap-align:center;background:radial-gradient(120% 90% at 100% 0%,rgba(255,255,255,.10),transparent 55%),var(--cardbg,var(--gr))}
.heroes .hero:last-child{margin-right:0}""",
""".heroes{position:relative;overflow:hidden;margin:0 -20px;padding:2px 0;cursor:grab}
.heroes:active{cursor:grabbing}
.htrack{display:flex;gap:12px;padding:0 20px;touch-action:pan-y;will-change:transform;transition:transform .34s cubic-bezier(.22,.8,.24,1)}
.htrack.drag{transition:none}
.heroes .hero{flex:0 0 auto;background:radial-gradient(120% 90% at 100% 0%,rgba(255,255,255,.10),transparent 55%),var(--cardbg,var(--gr))}
.hero.mini{min-height:0;padding:16px}
.hero.mini .hero-sum{margin:6px 0 2px}
.hero.mini .hero-sum .num{font-size:32px}
.iconbtn{width:36px;height:36px;flex:none;border-radius:12px;background:var(--soft);color:var(--gr3);display:grid;place-items:center;transition:transform .12s,background-color .2s}
.iconbtn:active{transform:scale(.94)}
.pi.pay{display:grid;grid-template-columns:auto auto minmax(0,1fr) auto;grid-template-areas:"cb tile mid amt" "cb tile pay pay";align-items:center;column-gap:12px;row-gap:9px}
.pi.pay .cb{grid-area:cb}
.pi.pay>.tile{grid-area:tile}
.pi.pay .mid{grid-area:mid}
.pi.pay .amt{grid-area:amt;justify-self:end}
.pi.pay .paybtn{grid-area:pay;justify-self:end;margin-top:0}""")
rep(".dots i{width:6px;height:6px;border-radius:50%;background:var(--line);transition:width .25s,background-color .25s}\n.dots i.on{width:20px;background:var(--primary)}",
    ".dots button{width:6px;height:6px;padding:0;border:0;border-radius:50%;background:var(--line);transition:width .25s,background-color .25s}\n.dots button.on{width:20px;background:var(--primary)}")

# ================= 2. разметка =================
rep('<div class="heroes rv" style="--d:2" id="heroes"></div>',
    '<div class="heroes rv" style="--d:2" id="heroes"><div class="htrack" id="heroes-t"></div></div>')
rep('<div class="rv" style="--d:2" id="rep-body"></div>',
    '<div class="heroes rv" style="--d:1" id="rep-heroes"><div class="htrack" id="rep-heroes-t"></div></div>\n              <div class="dots" id="rep-dots"></div>\n              <div class="rv" style="--d:2" id="rep-body"></div>')

# ================= 3. механика карусели =================
rep("""function renderDots(){
  const el=$('#heroes'),d=$('#h-dots');if(!el||!d)return;
  const n=el.children.length,w=el.children[0]?el.children[0].offsetWidth+12:1;
  const i=Math.min(n-1,Math.round(el.scrollLeft/w));
  d.innerHTML=[...Array(n)].map((_,k)=>`<i class="${k===i?'on':''}"></i>`).join('');
}""",
"""const HI={heroes:0,'rep-heroes':0};
function hDots(id){
  const tr=$('#'+id+'-t'),d=$('#'+(id==='heroes'?'h-dots':'rep-dots'));if(!tr||!d)return;
  const n=tr.children.length,i=HI[id];
  d.innerHTML=[...Array(n)].map((_,k)=>`<button class="${k===i?'on':''}" data-act="hero-dot" data-h="${id}" data-i="${k}" aria-label="${k+1}"></button>`).join('');
  if(id==='rep-heroes'){const o=i===0?null:st.obj[i-1],nid=o?o.id:null;if(nid!==st.repObj){st.repObj=nid;repBody();}}
}
function hSlide(id,i,anim){
  const tr=$('#'+id+'-t');if(!tr||!tr.children.length)return;
  i=Math.max(0,Math.min(tr.children.length-1,i));HI[id]=i;
  const w=tr.children[0].offsetWidth+12;
  if(!anim)tr.classList.add('drag');
  tr.style.transform='translateX('+(-i*w)+'px)';
  if(!anim)requestAnimationFrame(()=>tr.classList.remove('drag'));else tr.classList.remove('drag');
  hDots(id);
}
function hLayout(id){
  const el=$('#'+id),tr=$('#'+id+'-t');if(!el||!tr||!tr.children.length)return;
  const w=Math.max(200,el.clientWidth-40-34);
  [...tr.children].forEach(c=>{c.style.width=w+'px';});
  hSlide(id,Math.min(HI[id],tr.children.length-1),false);
}
function hInit(id){
  const el=$('#'+id),tr=$('#'+id+'-t');if(!el||!tr)return;
  let down=false,sx=0,sy=0,base=0,moved=false,lock=null;
  el.addEventListener('pointerdown',e=>{
    down=true;moved=false;lock=null;sx=e.clientX;sy=e.clientY;
    const w=tr.children[0]?tr.children[0].offsetWidth+12:1;base=-HI[id]*w;
  });
  el.addEventListener('pointermove',e=>{
    if(!down)return;
    const dx=e.clientX-sx,dy=e.clientY-sy;
    if(lock===null){if(Math.abs(dx)<6&&Math.abs(dy)<6)return;lock=Math.abs(dx)>Math.abs(dy)?'x':'y';if(lock==='x')tr.classList.add('drag');}
    if(lock!=='x'){down=false;return;}
    moved=true;HSCR=Date.now();
    tr.style.transform='translateX('+(base+dx)+'px)';
  });
  const up=e=>{
    if(!down)return;down=false;
    const dx=(e&&e.clientX!=null?e.clientX:sx)-sx,w=tr.children[0]?tr.children[0].offsetWidth+12:1;
    let i=HI[id];
    if(moved){i=Math.abs(dx)>w*0.2?i+(dx<0?1:-1):i;HSCR=Date.now();}
    hSlide(id,i,true);
  };
  el.addEventListener('pointerup',up);el.addEventListener('pointercancel',up);el.addEventListener('pointerleave',up);
  el.addEventListener('click',e=>{if(moved){e.stopPropagation();e.preventDefault();moved=false;}},true);
}
function renderDots(){hDots('heroes');}""")
rep("""  const el=$('#heroes'),keep=el?el.scrollLeft:0;
  el.innerHTML=st.obj.map((o,i)=>heroCard(o,i===0)).join('')
   +`<button class="hero add" data-act="obj-new"><span class="okc">${ic('circle-plus',26,2.2)}</span><b>Новый объект</b><span>Квартира, дача или офис — со своими счетами</span></button>`;
  el.scrollLeft=keep;
  renderDots();""",
"""  const tr=$('#heroes-t');
  tr.innerHTML=st.obj.map((o,i)=>heroCard(o,i===0)).join('')
   +`<button class="hero add" data-act="obj-new"><span class="okc">${ic('circle-plus',26,2.2)}</span><b>Новый объект</b><span>Квартира, дача или офис — со своими счетами</span></button>`;
  hLayout('heroes');""")
rep("(()=>{const h=$('#heroes');if(!h)return;let r=0;h.addEventListener('scroll',()=>{HSCR=Date.now();if(r)return;r=requestAnimationFrame(()=>{r=0;renderDots();});},{passive:true});})();",
    "hInit('heroes');hInit('rep-heroes');\naddEventListener('resize',()=>{hLayout('heroes');hLayout('rep-heroes');});")
rep("  'obj-bills':t=>{","  'hero-dot':t=>hSlide(t.dataset.h,+t.dataset.i,true),\n  'obj-bills':t=>{")

# ================= 4. отчёты по объектам =================
rep("bal:1240,qr:null,objId:null,objSel:'o1'","bal:1240,qr:null,objId:null,objSel:'o1',repObj:null")
rep("""function repMonths(){
  const on=catOn(),cur={};
  allBills().forEach(b=>{const c=svcCat(b);cur[c]=(cur[c]||0)+b.amount;});
  return RMONF.map((label0,i)=>{
    const label=tx(label0);
    let by={};
    if(i===11)by=cur;else for(const k in RHIST){if(!on[k])continue;const v=RHIST[k][i];if(v)by[k]=v;}
    return {label,short:RMON[i],by,total:Object.values(by).reduce((a,b)=>a+b,0)};
  });
}""",
"""function repShare(oid,k){
  if(!oid)return 1;
  const all=bills(),tot=all.filter(b=>svcCat(b)===k).reduce((a,b)=>a+b.amount,0);
  if(!tot)return 0;
  return all.filter(b=>svcCat(b)===k&&whoOf(b)===oid).reduce((a,b)=>a+b.amount,0)/tot;
}
function repMonths(oid){
  const on=catOn(),cur={};
  (oid?objBills(oid):allBills()).forEach(b=>{const c=svcCat(b);cur[c]=(cur[c]||0)+b.amount;});
  return RMONF.map((label0,i)=>{
    const label=tx(label0);
    let by={};
    if(i===11)by=cur;else for(const k in RHIST){if(!on[k])continue;const sh=repShare(oid,k);if(!sh)continue;const v=Math.round(RHIST[k][i]*sh);if(v)by[k]=v;}
    return {label,short:RMON[i],by,total:Object.values(by).reduce((a,b)=>a+b,0)};
  });
}""")
rep("""function renderRep(){
  const el=$('#rep-body');if(!el)return;
  const seg=$('#rep-seg');
  seg.dataset.v=st.repMode==='year'?1:0;
  $$('#rep-seg button').forEach(b=>b.setAttribute('aria-selected',String(b.dataset.mode===st.repMode)));
  el.innerHTML=st.repMode==='year'?repYear(repMonths()):repMonth(repMonths());
  if(ky())trTree(el);
}""",
"""function repCard(o){
  const m=repMonths(o?o.id:null),cur=m[11];
  const cats=Object.entries(cur.by).sort((a,b)=>b[1]-a[1]);
  return `<div class="hero mini c-${o?(OBJG[o.icon]||'city'):'tax'}">
   <div class="hero-obj"><span class="oi">${ic(o?o.icon:'chart-column',18)}</span><b>${o?tx(o.name):tx('Все объекты')}</b><span class="cnt">${F.billsN((o?objBills(o.id):bills()).length)}</span></div>
   <div class="hero-top"><span>Расходы в сентябре</span></div>
   <div class="hero-sum"><span class="num">${fmt(cur.total)}</span><small>сом</small></div>
   ${cats.length?`<div class="split">${cats.map(([c,v])=>`<i style="flex:${v} 1 0;background:${COL[c]}"></i>`).join('')}</div>
   <div class="legend">${cats.slice(0,4).map(([c,v])=>`<span><i style="background:${COL[c]}"></i>${CATN[c]} <b>${fmt(v)}</b></span>`).join('')}</div>`:'<div class="hero-meta">Пока нет расходов</div>'}</div>`;
}
function repBody(){
  const el=$('#rep-body');if(!el)return;
  el.innerHTML=st.repMode==='year'?repYear(repMonths(st.repObj)):repMonth(repMonths(st.repObj));
  if(ky())trTree(el);
}
function renderRep(){
  const seg=$('#rep-seg');if(!seg)return;
  seg.dataset.v=st.repMode==='year'?1:0;
  $$('#rep-seg button').forEach(b=>b.setAttribute('aria-selected',String(b.dataset.mode===st.repMode)));
  const tr=$('#rep-heroes-t');
  if(tr){tr.innerHTML=[null,...st.obj].map(repCard).join('');hLayout('rep-heroes');if(ky())trTree(tr);}
  repBody();
}""")

# ================= 5. правка счетов внутри объекта =================
rep("function renderObj(el){",
"""const objEditRow=b=>{
  const act=b.tpl?'edit-tpl':b.cust?'edit-cust':b.tax?'cat-open':'edit-util';
  const eid=b.tpl?b.tpl:b.tax?'tax':b.id;
  return `<div class="row" data-act="bill" data-id="${b.id}">${tile(b)}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.acc?F.acc(b.acc):tx(b.sub)}</span></span><span class="end"><span class="amt num">${fmt(b.amount)} <small>сом</small></span>${st.paid[b.id]?okChip():chipx(tx(b.dueShort),'#EEF1EF','#3C4A55')}</span><button class="iconbtn" data-act="${act}" data-id="${eid}" aria-label="Изменить счёт">${ic('square-pen',18)}</button></div>`;
};
function renderObj(el){""")
rep("""  <div class="group wrap">${list.length?list.map(billRowP).join(''):'<p class="empty">Здесь пока нет счетов</p>'}""",
"""  <div class="group wrap">${list.length?list.map(objEditRow).join(''):'<p class="empty">Здесь пока нет счетов</p>'}""")
rep('  <div class="sec"><h3>Счета объекта</h3></div>',
    '  <div class="sec"><h3>Счета объекта</h3><span class="s">${tx(\'карандаш — изменить\')}</span></div>')

# ================= 6. надпись «Оплатить» в листе оплаты =================
rep("""<div class="row pi pay" data-act="pi" data-id="${b.id}" aria-pressed="true"><span class="cb">${ic('check',14,3)}</span>${tile(b,0,20,'sm')}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.sub}${items.some(x=>whoOf(x)!==whoOf(items[0]))?" · "+objName(whoOf(b)):""}</span></span><span class="end"><span class="amt num">${fmt(b.amount)} <small>сом</small></span>${items.length>1?`<button class="paybtn ico" data-act="paybill" data-id="${b.id}" aria-label="Оплатить только этот счёт">${ic('arrow-right',17)}</button>`:''}</span></div>""",
"""<div class="row pi${items.length>1?' pay':''}" data-act="pi" data-id="${b.id}" aria-pressed="true"><span class="cb">${ic('check',14,3)}</span>${tile(b,0,20,'sm')}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.sub}${items.some(x=>whoOf(x)!==whoOf(items[0]))?" · "+objName(whoOf(b)):""}</span></span><span class="amt num">${fmt(b.amount)} <small>сом</small></span>${items.length>1?`<button class="paybtn" data-act="paybill" data-id="${b.id}">${ic('arrow-right',15)}Оплатить</button>`:''}</div>""")

# ================= 7. словарь =================
i=s.find('const KY='); j=s.find(';\n',i)
KY=json.loads(s[i+len('const KY='):j])
for k,v in {"Все объекты":"Бардык объекттер","карандаш — изменить":"карандаш — өзгөртүү","Изменить счёт":"Эсепти өзгөртүү",
            "Пока нет расходов":"Азырынча чыгаша жок","Расходы в сентябре":"Сентябрдагы чыгаша"}.items():
    KY.setdefault(k,v)
s=s[:i+len('const KY=')]+json.dumps(KY,ensure_ascii=False,separators=(',',':'))+s[j:]
io.open(P,'w',encoding='utf-8').write(s)
print('p13 ok, ky',len(KY))
