# -*- coding: utf-8 -*-
"""v2.9: карусель объектов на главной (как Apple Wallet) + оплата по одному в листе оплаты."""
import io
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:90]!r}'
    s=s.replace(old,new)

# ---------- 1. стили карусели ----------
rep("#h-payall{position:relative;overflow:hidden",".h-payall{position:relative;overflow:hidden")
rep("#h-payall::after{content:\"\"",".h-payall::after{content:\"\"")
rep("#h-payall::after{animation:none!important",".h-payall::after{animation:none!important")
rep(".row.pay .end{align-items:flex-end}",
""".heroes{display:flex;gap:12px;overflow-x:auto;scroll-snap-type:x mandatory;scrollbar-width:none;-webkit-overflow-scrolling:touch;margin:0 -20px;padding:2px 20px}
.heroes::-webkit-scrollbar{display:none}
.heroes .hero{flex:0 0 calc(100% - 34px);scroll-snap-align:center;background:radial-gradient(120% 90% at 100% 0%,rgba(255,255,255,.10),transparent 55%),var(--cardbg,var(--gr))}
.heroes .hero:last-child{margin-right:0}
.hero.c-water{--cardbg:linear-gradient(155deg,#15233A,#1B3057 55%,#22406E)}
.hero.c-door{--cardbg:linear-gradient(155deg,#1A2230,#232E42 55%,#2B3950)}
.hero.c-trash{--cardbg:linear-gradient(155deg,#2B1D18,#3A2820 55%,#4A3226)}
.hero.c-net{--cardbg:linear-gradient(155deg,#1B1B38,#262456 55%,#312D70)}
.hero.c-tax{--cardbg:linear-gradient(155deg,#1A2126,#242E34 55%,#2E3A42)}
.hero.c-market{--cardbg:linear-gradient(155deg,#0F2A30,#123A42 55%,#164A55)}
.hero.c-power{--cardbg:linear-gradient(155deg,#2A2313,#3A311A 55%,#4A3F20)}
.hero.c-course{--cardbg:linear-gradient(155deg,#241A32,#332444 55%,#412C57)}
.hero.c-gas{--cardbg:linear-gradient(155deg,#2B1A18,#3C2320 55%,#4C2C26)}
.hero.c-city{--cardbg:var(--gr)}
.hero-obj{display:flex;align-items:center;gap:10px;margin-bottom:14px}
.hero-obj .oi{width:34px;height:34px;flex:none;border-radius:11px;background:rgba(255,255,255,.16);color:#fff;display:grid;place-items:center}
.hero-obj b{font-size:16px;font-weight:700;letter-spacing:-.01em}
.hero-obj .cnt{margin-left:auto;font-size:12.5px;font-weight:600;color:#A9BBB3}
.hero.add{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;min-height:236px;color:var(--gr3);background:var(--soft);border:1.5px dashed var(--line);box-shadow:none}
.hero.add b{font-size:15px;font-weight:700;color:var(--gr)}
.hero.add span{font-size:12.5px;color:var(--muted);text-align:center;max-width:80%}
.hero.add .okc{width:52px;height:52px;border-radius:50%;background:var(--light2);color:var(--p700);display:grid;place-items:center}
.dots{display:flex;justify-content:center;align-items:center;gap:6px;margin-top:10px;height:8px}
.dots i{width:6px;height:6px;border-radius:50%;background:var(--line);transition:width .25s,background-color .25s}
.dots i.on{width:20px;background:var(--primary)}
.row.pay .end{align-items:flex-end}""")

# ---------- 2. разметка ----------
rep('<div class="hero rv" style="--d:2" id="hero"></div>',
    '<div class="heroes rv" style="--d:2" id="heroes"></div>\n              <div class="dots" id="h-dots"></div>')

# ---------- 3. карточки объектов ----------
old_home=s[s.find("function renderHome(from){"):s.find("function renderPay(){")]
new_home='''function heroCard(o,first){
  const all=objBills(o.id),due=all.filter(b=>!st.paid[b.id]),sum=total(due),paidN=all.length-due.length;
  const soon=due.length?(due.some(b=>!b.tpl)?'25 сент':Math.min(...due.map(b=>TPL[b.tpl].day))+' окт'):'';
  const byAmt=Object.values(due.reduce((m,b)=>{const c=svcCat(b);(m[c]=m[c]||{c,amount:0}).amount+=b.amount;return m;},{})).sort((x,y)=>y.amount-x.amount);
  const head=`<div class="hero-obj"><span class="oi">${ic(o.icon,18)}</span><b>${tx(o.name)}</b><span class="cnt">${F.billsN(all.length)}</span></div>`;
  const body=!all.length?`
    <div class="hero-ok"><span class="okc">${ic('circle-plus',26,2.2)}</span><div><b>Пока нет счетов</b><span>Подключите услуги — счета появятся здесь сами</span></div></div>
    <button class="btn btn-p" data-act="obj-add" data-id="${o.id}">${ic('circle-plus',20)}Добавить услуги</button>`:due.length?`
    <div class="hero-top"><span>К оплате в сентябре</span><span class="chip dk">${ic('calendar',14)}срок ${soon}</span></div>
    <div class="hero-sum"><span class="num"${first?' id="h-total"':''}>${fmt(sum)}</span><small>сом</small></div>
    <div class="hero-meta">${F.meta(due.length,paidN,all.length)}</div>
    <div class="split">${byAmt.map(b=>`<i style="flex:${b.amount} 1 0;background:${COL[b.c]}"></i>`).join('')}</div>
    <div class="legend">${byAmt.map(b=>`<span><i style="background:${COL[b.c]}"></i>${CATN[b.c]} <b>${fmt(b.amount)}</b></span>`).join('')}</div>
    <button class="btn btn-p h-payall"${first?' id="h-payall"':''} data-act="payall" data-obj="${o.id}">Оплатить всё${ic('arrow-right',20)}</button>`:`
    <div class="hero-ok"><span class="okc">${ic('check',26,2.6)}</span><div><b>Всё оплачено</b><span>Новые счета придут в октябре — напомним за 3 дня</span></div></div>
    <button class="btn btn-dk" data-act="obj-bills" data-id="${o.id}">${ic('receipt',20)}Счета объекта</button>`;
  return `<div class="hero c-${o.c||'city'}" data-act="obj-bills" data-id="${o.id}"><span class="blob b1"></span><span class="blob b2"></span>${head}${body}</div>`;
}
function renderDots(){
  const el=$('#heroes'),d=$('#h-dots');if(!el||!d)return;
  const n=el.children.length,w=el.children[0]?el.children[0].offsetWidth+12:1;
  const i=Math.min(n-1,Math.round(el.scrollLeft/w));
  d.innerHTML=[...Array(n)].map((_,k)=>`<i class="${k===i?'on':''}"></i>`).join('');
}
function renderHome(from){
  const due=unpaid(),sum=total(due);
  $('.hello').textContent='Салам, '+st.name.split(/\\s+/)[0];
  const el=$('#heroes'),keep=el?el.scrollLeft:0;
  el.innerHTML=st.obj.map((o,i)=>heroCard(o,i===0)).join('')
   +`<button class="hero add" data-act="obj-new"><span class="okc">${ic('circle-plus',26,2.2)}</span><b>Новый объект</b><span>Квартира, дача или офис — со своими счетами</span></button>`;
  el.scrollLeft=keep;
  renderDots();
  if(from!=null&&due.length)countUp($('#h-total'),from,total(objBills(st.obj[0].id).filter(b=>!st.paid[b.id])));
  renderBillCard();
  $('#h-cats').innerHTML=homeCats();
}

'''
s=s.replace(old_home,new_home)

# ---------- 4. действия ----------
rep("payall:()=>openCheckout(unpaid().map(b=>b.id)),",
    "payall:t=>{const o=t&&t.dataset?t.dataset.obj:'';openCheckout(unpaid().filter(b=>!o||whoOf(b)===o).map(b=>b.id));},")
rep("  'obj-open':t=>{","  'obj-bills':t=>openBills(t.dataset.id),\n  'obj-open':t=>{")

# ---------- 5. шторка счетов с фильтром по объекту ----------
rep("function openBills(){\n  const all=bills(),due=unpaid(),paid=all.filter(b=>st.paid[b.id]),sum=total(due);",
    "function openBills(oid){\n  const all=oid?objBills(oid):bills(),due=all.filter(b=>!st.paid[b.id]),paid=all.filter(b=>st.paid[b.id]),sum=total(due);")
rep("  const ws=whoAll();\n  if(ws.length>1){","  const ws=oid?[]:whoAll();\n  if(ws.length>1){")
rep("h+=due.length?`<button class=\"btn btn-p\" data-act=\"payall\">${F.payAllSum(fmt(sum))}</button>`",
    "h+=due.length?`<button class=\"btn btn-p\" data-act=\"payall\" data-obj=\"${oid||''}\">${F.payAllSum(fmt(sum))}</button>`")
rep("  openSheet('Счета',h,'bills');","  openSheet(oid?tx('Счета')+' · '+objName(oid):'Счета',h,'bills');")

# ---------- 6. кнопка «Оплатить» в листе оплаты ----------
rep('${items.map(b=>`<button class="row pi" data-act="pi" data-id="${b.id}" aria-pressed="true"><span class="cb">${ic(\'check\',14,3)}</span>${tile(b,0,20,\'sm\')}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.sub}${items.some(x=>whoOf(x)!==whoOf(items[0]))?" · "+objName(whoOf(b)):""}</span></span><span class="amt num">${fmt(b.amount)} <small>сом</small></span></button>`).join(\'\')}',
    '${items.map(b=>`<div class="row pi pay" data-act="pi" data-id="${b.id}" aria-pressed="true"><span class="cb">${ic(\'check\',14,3)}</span>${tile(b,0,20,\'sm\')}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.sub}${items.some(x=>whoOf(x)!==whoOf(items[0]))?" · "+objName(whoOf(b)):""}</span></span><span class="end"><span class="amt num">${fmt(b.amount)} <small>сом</small></span>${items.length>1?`<button class="paybtn" data-act="paybill" data-id="${b.id}">${ic(\'arrow-right\',15)}Оплатить</button>`:\'\'}</span></div>`).join(\'\')}')
io.open(P,'w',encoding='utf-8').write(s)
print('p8 ok')
