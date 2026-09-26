# -*- coding: utf-8 -*-
"""v3.0: карточки объектов в отчётах, правка счетов внутри объекта, надпись на кнопке оплаты."""
import io
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:90]!r}'
    s=s.replace(old,new)

# ---------- 4. кнопка «Оплатить» с надписью в листе оплаты ----------
rep(".pi .end{gap:6px}",
""".pi.pay{display:grid;grid-template-columns:auto auto minmax(0,1fr) auto;grid-template-areas:"cb tile mid amt" "cb tile pay pay";align-items:center;column-gap:12px;row-gap:9px}
.pi.pay .cb{grid-area:cb}
.pi.pay>.tile{grid-area:tile}
.pi.pay .mid{grid-area:mid}
.pi.pay .amt{grid-area:amt;justify-self:end}
.pi.pay .paybtn{grid-area:pay;justify-self:end;margin-top:0}
.iconbtn{width:36px;height:36px;flex:none;border-radius:12px;background:var(--soft);color:var(--gr3);display:grid;place-items:center;transition:transform .12s,background-color .2s}
.iconbtn:active{transform:scale(.94)}
.hero.mini{min-height:0;padding:16px}
.hero.mini .hero-sum{margin:6px 0 2px}
.hero.mini .hero-sum .num{font-size:32px}""")
rep("""<div class="row pi pay" data-act="pi" data-id="${b.id}" aria-pressed="true"><span class="cb">${ic('check',14,3)}</span>${tile(b,0,20,'sm')}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.sub}${items.some(x=>whoOf(x)!==whoOf(items[0]))?" · "+objName(whoOf(b)):""}</span></span><span class="end"><span class="amt num">${fmt(b.amount)} <small>сом</small></span>${items.length>1?`<button class="paybtn ico" data-act="paybill" data-id="${b.id}" aria-label="Оплатить только этот счёт">${ic('arrow-right',17)}</button>`:''}</span></div>""",
"""<div class="row pi${items.length>1?' pay':''}" data-act="pi" data-id="${b.id}" aria-pressed="true"><span class="cb">${ic('check',14,3)}</span>${tile(b,0,20,'sm')}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.sub}${items.some(x=>whoOf(x)!==whoOf(items[0]))?" · "+objName(whoOf(b)):""}</span></span><span class="amt num">${fmt(b.amount)} <small>сом</small></span>${items.length>1?`<button class="paybtn" data-act="paybill" data-id="${b.id}">${ic('arrow-right',15)}Оплатить</button>`:''}</div>""")

# ---------- 2. правка счетов внутри объекта ----------
rep("""  <div class="group wrap">${list.length?list.map(billRowP).join(''):'<p class="empty">Здесь пока нет счетов</p>'}""",
"""  <div class="group wrap">${list.length?list.map(objEditRow).join(''):'<p class="empty">Здесь пока нет счетов</p>'}""")
rep("function renderObj(el){",
"""const objEditRow=b=>{
  const act=b.tpl?'edit-tpl':b.cust?'edit-cust':b.tax?'cat-open':'edit-util';
  const eid=b.tpl?b.tpl:b.tax?'tax':b.id;
  return `<div class="row" data-act="bill" data-id="${b.id}">${tile(b)}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.acc?F.acc(b.acc):tx(b.sub)}</span></span><span class="end"><span class="amt num">${fmt(b.amount)} <small>сом</small></span>${st.paid[b.id]?okChip():chipx(tx(b.dueShort),'#EEF1EF','#3C4A55')}</span><button class="iconbtn" data-act="${act}" data-id="${eid}" aria-label="Изменить счёт">${ic('square-pen',18)}</button></div>`;
};
function renderObj(el){""")
rep("""  <div class="sec"><h3>Счета объекта</h3></div>""",
    """  <div class="sec"><h3>Счета объекта</h3><span class="s">${tx('Нажмите карандаш, чтобы изменить')}</span></div>""")

# ---------- 1. карточки объектов в отчётах ----------
rep('<div class="rv" style="--d:2" id="rep-body"></div>',
    '<div class="heroes rv" style="--d:1" id="rep-heroes"></div>\n              <div class="dots" id="rep-dots"></div>\n              <div class="rv" style="--d:2" id="rep-body"></div>')
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
function renderRepDots(){
  const el=$('#rep-heroes'),d=$('#rep-dots');if(!el||!d)return;
  const n=el.children.length,w=el.children[0]?el.children[0].offsetWidth+12:1;
  const i=Math.min(n-1,Math.round(el.scrollLeft/w));
  d.innerHTML=[...Array(n)].map((_,k)=>`<i class="${k===i?'on':''}"></i>`).join('');
  const o=i===0?null:st.obj[i-1];
  const nid=o?o.id:null;
  if(nid!==st.repObj){st.repObj=nid;repBody();}
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
  const h=$('#rep-heroes');
  if(h){const keep=h.scrollLeft;h.innerHTML=[null,...st.obj].map(repCard).join('');h.scrollLeft=keep;
    const n=h.children.length,w=h.children[0]?h.children[0].offsetWidth+12:1;
    const i=Math.min(n-1,Math.round(keep/w));st.repObj=i===0?null:(st.obj[i-1]||{}).id||null;
    const d=$('#rep-dots');if(d)d.innerHTML=[...Array(n)].map((_,k)=>`<i class="${k===i?'on':''}"></i>`).join('');
    if(ky())trTree(h);}
  repBody();
}""")
rep("(()=>{const h=$('#heroes');if(!h)return;let r=0;h.addEventListener('scroll',()=>{HSCR=Date.now();if(r)return;r=requestAnimationFrame(()=>{r=0;renderDots();});},{passive:true});})();",
    "(()=>{const h=$('#heroes');if(h){let r=0;h.addEventListener('scroll',()=>{HSCR=Date.now();if(r)return;r=requestAnimationFrame(()=>{r=0;renderDots();});},{passive:true});}\n"
    " const g=$('#rep-heroes');if(g){let r2=0;g.addEventListener('scroll',()=>{HSCR=Date.now();if(r2)return;r2=requestAnimationFrame(()=>{r2=0;renderRepDots();});},{passive:true});}})();")
io.open(P,'w',encoding='utf-8').write(s)
print('p10 ok')
