# -*- coding: utf-8 -*-
"""ЭлPay v3.1 — Маркет: афиша города Ош, покупка билетов и QR-билет на входе.

Точечные замены в index.html. Перед запуском — копия файла (см. HANDOFF.md).
"""
import io, json

P = 'index.html'
s = io.open(P, encoding='utf-8').read()


def rep(old, new, cnt=1):
    global s
    n = s.count(old)
    assert n == cnt, 'expected %d, found %d: %r' % (cnt, n, old[:110])
    s = s.replace(old, new)


# ===================== 1. CSS =====================
CSS = """
/* ===== Маркет: афиша и билеты ===== */
.mk-hd{display:flex;align-items:center;gap:13px;padding:15px 16px;border-radius:22px;background:linear-gradient(135deg,#46BEDC,#2AA3C7);color:#fff;box-shadow:var(--sh-sm)}
.mk-hd .i{flex:none;opacity:.92}
.mk-hd b{display:block;font-size:16px;font-weight:700;letter-spacing:-.01em}
.mk-hd .mid span{display:block;margin-top:2px;font-size:12.5px;font-weight:500;line-height:1.4;opacity:.92}
.mk-list{margin-top:6px}
.evt{width:100%;display:flex;align-items:center;gap:13px;padding:10px;border-radius:20px;background:var(--bg);box-shadow:var(--sh-sm);text-align:left;transition:transform .12s}
.evt+.evt{margin-top:10px}
.evt:active{transform:scale(.985)}
.evt-art{flex:none;width:60px;height:72px;border-radius:15px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1px;color:#fff}
.evt-art b{font-size:19px;font-weight:800;line-height:1.05}
.evt-art em{font-size:10.5px;font-weight:700;opacity:.9}
.evt-art .i{margin-bottom:3px;opacity:.9}
.evt .mid{min-width:0}
.evt .mid b{display:block;font-size:14.5px;font-weight:700;letter-spacing:-.01em}
.evt .mid .vn{display:block;margin-top:2px;font-size:12.5px;font-weight:500;color:var(--muted);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.evt .mid .pr{display:block;margin-top:5px;font-size:12.5px;font-weight:700;color:var(--p700)}
.evt em,.kv b em,.tkt em,.gate em,.mk-hd em{font-style:normal}
.scts{display:grid;gap:8px}
.sct{display:flex;align-items:center;gap:12px;width:100%;padding:12px 14px;border-radius:16px;border:1.5px solid var(--line);background:var(--bg);text-align:left;transition:border-color .2s,background-color .2s}
.sct.on{border-color:var(--primary);background:var(--light2)}
.sct .mid{min-width:0}
.sct b{display:block;font-size:14px;font-weight:600}
.sct .mid span{display:block;font-size:12.5px;color:var(--muted)}
.sct .radio{width:22px;height:22px;flex:none;border-radius:50%;border:1.5px solid var(--muted2)}
.sct.on .radio{border:7px solid var(--primary)}
.qty{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 14px;border-radius:16px;background:var(--soft)}
.qty>span{font-size:14px;font-weight:600}
.qty .ctl{display:flex;align-items:center;gap:14px}
.qty button{width:38px;height:38px;border-radius:13px;border:1.5px solid var(--line);background:var(--bg);display:grid;place-items:center;color:var(--gr)}
.qty button:disabled{opacity:.35}
.qty .ctl b{min-width:22px;text-align:center;font-size:18px;font-weight:700}
.tkt{border-radius:22px;background:var(--bg);box-shadow:var(--sh);overflow:hidden}
.tkt+.tkt{margin-top:14px}
.tkt-top{display:flex;align-items:center;gap:12px;padding:14px 16px;color:#fff}
.tkt-top .i{flex:none;opacity:.92}
.tkt-top .mid{min-width:0}
.tkt-top b{display:block;font-size:15px;font-weight:700;line-height:1.3}
.tkt-top .mid span{display:block;margin-top:1px;font-size:12.5px;font-weight:500;opacity:.92}
.tkt-cut{position:relative;height:20px}
.tkt-cut::before,.tkt-cut::after{content:'';position:absolute;top:0;width:20px;height:20px;border-radius:50%;background:var(--soft)}
.tkt-cut::before{left:-10px}
.tkt-cut::after{right:-10px}
.tkt-cut i{position:absolute;left:16px;right:16px;top:10px;border-top:1.5px dashed var(--line)}
.tkt-bd{display:flex;align-items:center;gap:14px;padding:0 16px 14px}
.tkt-qr{flex:none;width:98px;height:98px;padding:7px;border-radius:14px;background:#fff;border:1.5px solid var(--line2)}
.tkt-qr svg{display:block;width:100%;height:100%}
.tkt-meta{flex:1;min-width:0;display:grid;gap:7px}
.tkt-meta div{display:flex;align-items:baseline;justify-content:space-between;gap:10px;font-size:12.5px;line-height:1.3}
.tkt-meta span{flex:none;color:var(--muted);font-weight:500}
.tkt-meta b{font-weight:700;text-align:right;overflow:hidden;text-overflow:ellipsis}
.tkt-cta{display:grid;gap:8px;padding:0 16px 16px}
.gate{position:absolute;inset:0;z-index:95;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;padding:calc(var(--sat) + 12px) 26px calc(var(--sab) + 16px);background:#fff;opacity:0;pointer-events:none;transition:opacity .28s}
.gate.on{opacity:1;pointer-events:auto}
.gate-qr{position:relative;width:228px;height:228px;padding:15px;border-radius:26px;background:#fff;box-shadow:var(--sh-lg)}
.gate-qr svg{display:block;width:100%;height:100%}
.gate-ok{position:absolute;inset:0;display:none;place-items:center;border-radius:26px;background:rgba(6,160,110,.96);color:#fff}
.gate-qr.ok .gate-ok{display:grid;animation:popIn .4s var(--ease)}
.gate h3{font-size:19px;font-weight:700;text-align:center;letter-spacing:-.015em;line-height:1.25}
.gate p{font-size:13.5px;font-weight:500;color:var(--muted);text-align:center}
.gate .btn{width:100%;max-width:290px;margin-top:4px}
.qa.on{background:var(--gr);border-color:var(--gr);color:#fff}
"""
rep('</style>', CSS + '</style>')

# ===================== 2. HTML: экраны и оверлей =====================
rep('''          <nav class="tabbar hide" id="tabbar" aria-label="Разделы">''',
    '''          <!-- 22. Маркет: афиша города -->
          <section class="scr" id="s-market"><div class="body" id="mk-body"></div></section>

          <!-- 23. Мои билеты -->
          <section class="scr" id="s-tickets"><div class="body" id="tk-body"></div></section>

          <nav class="tabbar hide" id="tabbar" aria-label="Разделы">''')

rep('''          <button class="push" id="push" data-act="push"''',
    '''          <div class="gate" id="gate" aria-hidden="true"></div>
          <button class="push" id="push" data-act="push"''')

# профиль: раздел «Маркет»
rep('''              <div class="sec rv" style="--d:6"><h3>Приложение</h3></div>''',
    '''              <div class="sec rv" style="--d:5"><h3>Маркет</h3></div>
              <div class="group rv wrap" style="--d:5">
                <button class="row" data-act="mk-open"><span class="tile c-market"><i data-i="ticket"></i></span><span class="mid"><span class="t">Афиша Оша</span><span class="s">Концерты, театр, кино и спорт</span></span><i data-i="chevron-right" data-s="18"></i></button>
                <button class="row" data-act="tk-list"><span class="tile soft c-market"><i data-i="qr"></i></span><span class="mid"><span class="t">Мои билеты</span><span class="s">QR на входе — без бумажных билетов</span></span><i data-i="chevron-right" data-s="18"></i></button>
              </div>
              <div class="sec rv" style="--d:6"><h3>Приложение</h3></div>''')

# панель питча: сценарий 7
rep('''      <li><button class="scn" data-scn="6"><span class="n">6</span>Реквизиты: изменить и добавить<i class="go" data-i="arrow-right" data-s="18"></i></button></li>''',
    '''      <li><button class="scn" data-scn="6"><span class="n">6</span>Реквизиты: изменить и добавить<i class="go" data-i="arrow-right" data-s="18"></i></button></li>
      <li><button class="scn" data-scn="7"><span class="n">7</span>Билет на концерт и QR на входе<i class="go" data-i="arrow-right" data-s="18"></i></button></li>''')

# ===================== 3. Состояние и точки входа =====================
rep("  hist:[],histQ:''});", "  hist:[],histQ:'',tickets:[],mkF:'all'});")

rep("name:'Маркет',sub:'Концерты, театр, кино',soon:1,items:",
    "name:'Маркет',sub:'Концерты, театр, кино',mk:1,items:")

rep("""function pickHTML(c){
  if(c.soon)return `<p class="sub">Билеты появятся в следующем релизе — плитка уже в каталоге.</p>
   <div class="minitiles">${c.items.map(i=>`<div class="mt soon">${tl(SVC[i].c,SVC[i].icon,22)}${SVC[i].name}</div>`).join('')}</div>
   <button class="btn btn-s" data-act="close">Понятно</button>`;""",
    """function pickHTML(c){
  if(c.mk)return `<p class="sub">Билеты на концерты, театр, кино и спорт — в разделе «Маркет». Подключать ничего не нужно.</p>
   <div class="minitiles">${c.items.map(i=>`<div class="mt">${tl(SVC[i].c,SVC[i].icon,22)}${SVC[i].name}</div>`).join('')}</div>
   <button class="btn btn-s" data-act="close">Понятно</button>`;""")

rep("function openCat(id){st.cat=id;renderCat();go('cat');}",
    "function openCat(id){if(id==='market')return openMarket();st.cat=id;renderCat();go('cat');}")

rep("""  if(!by.school)out.push(['school','Школа','addchild','']);""",
    """  if(!by.school)out.push(['school','Школа','addchild','']);
  out.push(['ticket','Билеты','mk-open','']);""")

rep("renderObjs();renderChat();if(st.cat)renderCat();",
    "renderObjs();renderChat();renderMarket();renderTickets();if(st.cat)renderCat();")

# ===================== 4. Успешная оплата: билет вместо реквизитов =====================
rep("""    ${once?`<button class="btn btn-p" data-act="np-keep">${ic('circle-plus',20)}Сохранить реквизиты</button>`:''}<div class="tip ok">${ic('bell',18)}<span>О новых счетах напомним за 3 дня до срока. Квитанции — в разделе «Платежи».</span></div>`;""",
    """    ${once&&once.tkt?`<button class="btn btn-p" data-act="tk-list">${ic('ticket',20)}Открыть билет</button>`:once?`<button class="btn btn-p" data-act="np-keep">${ic('circle-plus',20)}Сохранить реквизиты</button>`:''}<div class="tip ok">${ic(once&&once.tkt?'ticket':'bell',18)}<span>${once&&once.tkt?'Билет уже в разделе «Мои билеты» — на входе покажите QR.':'О новых счетах напомним за 3 дня до срока. Квитанции — в разделе «Платежи».'}</span></div>`;""")

# ===================== 5. Способ оплаты и пополнение внутри шторки события =====================
rep("if(st.sheet==='np'&&NP&&NP.step===3)setBody(npHTML());renderPM();},",
    "if(st.sheet==='np'&&NP&&NP.step===3)setBody(npHTML());if(st.sheet==='evt'&&MK)setBody(evtHTML());renderPM();},")

rep("""    st.bal+=v;closeSheet();renderAll();toast(F.topped(fmt(v),fmt(st.bal)));
    if(st.sel&&st.sel.length)setTimeout(()=>openCheckout(st.sel),260);""",
    """    st.bal+=v;closeSheet();renderAll();toast(F.topped(fmt(v),fmt(st.bal)));
    if(MK&&MK.pending){MK.pending=0;return setTimeout(()=>openSheet(tx(evtById(MK.id).t),evtHTML(),'evt'),260);}
    if(st.sel&&st.sel.length)setTimeout(()=>openCheckout(st.sel),260);""")

# ===================== 6. Жесты и навигация =====================
rep("""  const NO='.cats,.hscroll,.heroes,.minitiles,.cities,.seg,.keypad,.ybars,.chart,.map,input,textarea,select,.pms';""",
    """  const NO='.cats,.hscroll,.heroes,.minitiles,.cities,.seg,.keypad,.ybars,.chart,.map,input,textarea,select,.pms,.qr-row';""")

rep("""{swiped=1;go(cur==='scan'?st.tab:st.tab,'back');}""",
    """{swiped=1;go(cur==='tickets'&&st.tkFrom==='market'?'market':st.tab,'back');}""")

rep("""function go(id,dir='fwd'){
  const next=$('#s-'+id),prev=$('#s-'+cur);if(!next||id===cur)return;
  closeSheet();hidePush();""",
    """function go(id,dir='fwd'){
  const next=$('#s-'+id),prev=$('#s-'+cur);if(!next||id===cur)return;
  closeSheet();hidePush();closeGate();""")

rep("const SCN={auth:1,otp:1,setup:1,services:1,accounts:1,sync:1,home:2,pay:2,cat:2,success:2,tpl:3,alerts:4,reports:5,profile:6,req:6};",
    "const SCN={auth:1,otp:1,setup:1,services:1,accounts:1,sync:1,home:2,pay:2,cat:2,success:2,tpl:3,alerts:4,reports:5,profile:6,req:6,market:7,tickets:7};")

rep("""addEventListener('keydown',e=>{if(e.key==='Escape'){closeSheet();hidePush();}});""",
    """addEventListener('keydown',e=>{if(e.key==='Escape'){closeSheet();hidePush();closeGate();}});""")

rep("""  if(n===6){renderReq();go('req');}""",
    """  if(n===6){renderReq();go('req');}
  if(n===7){st.tab='home';$$('.tab').forEach(t=>t.classList.toggle('on',t.dataset.tab==='home'));openMarket();setTimeout(()=>{if(cur==='market')openEvt('e1');},560);}""")

# ===================== 7. Логика маркета =====================
JS = r"""/* ===== Маркет: афиша города и билеты с QR ===== */
Object.assign(IC,{
 music:'<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
 film:'<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M7 3v18"/><path d="M3 7.5h4"/><path d="M3 12h18"/><path d="M3 16.5h4"/><path d="M17 3v18"/><path d="M17 7.5h4"/><path d="M17 16.5h4"/>',
 trophy:'<path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/>',
 drama:'<path d="M10 11h.01"/><path d="M14 6h.01"/><path d="M18 6h.01"/><path d="M6.5 13.1h.01"/><path d="M22 5c0 9-4 12-6 12s-6-3-6-12c0-2 2-3 6-3s6 1 6 3"/><path d="M17.4 9.9c-.8.8-2 .8-2.8 0"/><path d="M10.1 7.1C9 7.2 7.7 7.7 6 8.6c-3.5 2-4.7 3.9-3.7 5.6 4.5 7.8 9.5 8.4 11.2 7.4.9-.5 1.9-2.1 1.9-4.7"/><path d="M9.1 16.5c.3-1.1 1.4-1.7 2.4-1.4"/>',
 minus:'<path d="M5 12h14"/>'});
Object.assign(CAT,{ticket:'market',music:'market',film:'market',trophy:'market',drama:'market'});
Object.assign(F,{
 evtFrom:s=>ky()?`${s} сомдон баштап`:`от ${s} сом`,
 buy:s=>ky()?`Сатып алуу · ${s} сом`:`Купить · ${s} сом`,
 tkQty:n=>ky()?`${n} билет`:`${n} ${plural(n,'билет','билета','билетов')}`,
 tkMeta:(n,d)=>ky()?`${n} билет · жакынкысы ${tx(d)}`:`${F.tkQty(n)} · ближайший ${d}`,
 tkSeats:(sec,n)=>ky()?`${tx(sec)} · ${n} билет`:`${sec} · ${F.tkQty(n)}`});
const MKF=[['all','Всё'],['concert','Концерты'],['theatre','Театр'],['cinema','Кино'],['sport','Спорт']];
const EVENTS=[
 {id:'e1',k:'concert',icon:'music',t:'Мирбек Атабеков',v:'Ошский драмтеатр им. Бабура',d:'12 октября',dd:'12',dm:'окт',time:'19:00',g:['#6B55EC','#5340D0'],
  about:'Большой сольный концерт с оркестром: новые песни и лучшее за десять лет.',
  sec:[['Партер','1–6 ряд',1500],['Амфитеатр','7–14 ряд',900],['Балкон','свободные места',600]]},
 {id:'e2',k:'theatre',icon:'drama',t:'Курманжан Датка',v:'Ошский драмтеатр им. Бабура',d:'18 октября',dd:'18',dm:'окт',time:'18:00',g:['#E0428D','#C4327A'],
  about:'Историческая драма о правительнице Алая. Спектакль на кыргызском языке.',
  sec:[['Партер','1–8 ряд',700],['Балкон','свободные места',400]]},
 {id:'e3',k:'cinema',icon:'film',t:'Тайна Сулайман-Тоо',v:'Кинотеатр «Ынтымак», зал 2',d:'сегодня',dd:'20',dm:'сен',time:'19:20',g:['#3C4A55','#1E2A32'],
  about:'Семейное приключение о легендах священной горы. Дубляж кыргызский и русский.',
  sec:[['VIP-диван','последний ряд',350],['Обычное место','ряды 3–8',250]]},
 {id:'e4',k:'sport',icon:'trophy',t:'«Алай» — «Дордой»',v:'Стадион им. Ниязбекова',d:'5 октября',dd:'5',dm:'окт',time:'15:00',g:['#3F7BE0','#2B5BB8'],
  about:'Матч Премьер-лиги Кыргызстана. Ворота открываются за час до начала.',
  sec:[['Западная трибуна','центр поля',500],['Восточная трибуна','за воротами',200]]},
 {id:'e5',k:'concert',icon:'music',t:'Ночь этно-музыки',v:'Парк Навои, летняя сцена',d:'27 сентября',dd:'27',dm:'сен',time:'20:00',g:['#46BEDC','#2AA3C7'],
  about:'Комуз, темир-комуз и электроника: пять коллективов из Оша, Бишкека и Нарына.',
  sec:[['Танцевальная зона','стоя у сцены',450],['Столик на четверых','с местами',1600]]},
 {id:'e6',k:'cinema',icon:'film',t:'Мультсеанс для детей',v:'Кинотеатр «Ынтымак», зал 1',d:'28 сентября',dd:'28',dm:'сен',time:'11:00',g:['#E0A93F','#C98F27'],
  about:'Утренний сеанс с кыргызским дубляжом. Детям до трёх лет — бесплатно.',
  sec:[['Любое место','зал 1',180]]}];
const evtById=id=>EVENTS.find(e=>e.id===id)||EVENTS[0];
const evtMin=e=>Math.min(...e.sec.map(x=>x[2]));
const evtGrad=e=>`linear-gradient(145deg,${e.g[0]},${e.g[1]})`;
function qrSVG(seed,label){
  const N=25;let h=2166136261;
  for(let i=0;i<seed.length;i++){h^=seed.charCodeAt(i);h=Math.imul(h,16777619)>>>0;}
  const rnd=()=>{h^=h<<13;h>>>=0;h^=h>>>17;h^=h<<5;h>>>=0;return h/4294967296;};
  const fin=(x,y)=>{
    for(const c of [[3,3],[N-4,3],[3,N-4]]){
      const d=Math.max(Math.abs(x-c[0]),Math.abs(y-c[1]));
      if(d<=3)return d===2?0:1;
    }
    const d2=Math.max(Math.abs(x-(N-5)),Math.abs(y-(N-5)));
    if(d2<=2)return d2===1?0:1;
    return -1;
  };
  let r='';
  for(let y=0;y<N;y++)for(let x=0;x<N;x++){
    const f=fin(x,y),on=f>=0?f===1:rnd()>.52;
    if(on)r+=`<rect x="${x}" y="${y}" width="1" height="1"/>`;
  }
  return `<svg viewBox="-.6 -.6 ${N+1.2} ${N+1.2}" shape-rendering="crispEdges" role="img" aria-label="${label||'QR-код билета'}"><g fill="#1E2A32">${r}</g></svg>`;
}
const evtCard=e=>`<button class="evt" data-act="evt" data-id="${e.id}">
 <span class="evt-art" style="background:${evtGrad(e)}">${ic(e.icon,20)}<b class="num">${e.dd}</b><em>${e.dm}</em></span>
 <span class="mid"><b>${e.t}</b><span class="vn"><em>${e.v}</em> · ${e.time}</span><span class="pr">${F.evtFrom(fmt(evtMin(e)))}</span></span>
 ${ic('chevron-right',18)}</button>`;
function renderMarket(){
  const el=$('#mk-body');if(!el)return;
  const f=st.mkF||'all',tk=st.tickets||[],n=tk.reduce((a,t)=>a+t.n,0);
  const list=EVENTS.filter(e=>f==='all'||e.k===f);
  el.innerHTML=`<div class="nav"><button class="nb" data-act="back" aria-label="Назад">${ic('chevron-left',24)}</button><span class="nt">Маркет</span>${tk.length?`<button class="nb" data-act="tk-list" aria-label="Мои билеты">${ic('ticket',20)}</button>`:'<span class="sp"></span>'}</div>
  <div class="mk-hd">${ic('ticket',26)}<span class="mid"><b>Афиша Оша</b><span>Концерты, театр, кино и спорт. Билет приходит в приложение — на входе покажите QR.</span></span></div>
  ${tk.length?`<button class="exp" style="margin-top:14px" data-act="tk-list"><span class="tile soft c-market">${ic('qr',22)}</span><span class="mid"><b>Мои билеты</b><span>${F.tkMeta(n,evtById(tk[0].evt).d)}</span></span>${ic('chevron-right',20)}</button>`:''}
  <div class="qr-row">${MKF.map(([k,l])=>`<button class="qa${f===k?' on':''}" data-act="mk-filter" data-k="${k}">${l}</button>`).join('')}</div>
  <div class="mk-list">${list.map(evtCard).join('')||'<p class="empty">В этой категории пока ничего нет</p>'}</div>
  <p class="hint2">Маркет — точка роста ЭлPay: комиссия с продажи билетов и афиша городских событий рядом с коммунальными счетами.</p>`;
  if(ky())trTree(el);
}
function openMarket(){closeSheet();renderMarket();go('market');}
let MK=null;
function evtHTML(){
  const e=evtById(MK.id),sec=e.sec[MK.s],sum=sec[2]*MK.n,need=short1(sum);
  return `<div class="bs-top"><span class="tile" style="background:${evtGrad(e)};color:#fff">${ic(e.icon,22)}</span><div class="mid"><b>${e.t}</b><span><em>${e.d}</em> · ${e.time}</span></div></div>
   <p class="sub" style="margin-top:12px">${e.about}</p>
   <div class="kv"><div><span>Место</span><b>${e.v}</b></div><div><span>Начало</span><b><em>${e.d}</em>, ${e.time}</b></div><div><span>Билет</span><b>Электронный, QR на входе</b></div></div>
   <div class="sec"><h3>Сектор</h3></div>
   <div class="scts">${e.sec.map((x,i)=>`<button class="sct${MK.s===i?' on':''}" data-act="mk-sec" data-i="${i}"><span class="mid"><b>${x[0]}</b><span>${x[1]}</span></span><span class="amt num">${fmt(x[2])} <small>сом</small></span><span class="radio"></span></button>`).join('')}</div>
   <div class="sec"><h3>Сколько билетов</h3></div>
   <div class="qty"><span>${F.tkQty(MK.n)}</span><span class="ctl"><button data-act="mk-qty" data-d="-1" aria-label="Меньше"${MK.n<=1?' disabled':''}>${ic('minus',18)}</button><b class="num">${MK.n}</b><button data-act="mk-qty" data-d="1" aria-label="Больше"${MK.n>=8?' disabled':''}>${ic('plus',18)}</button></span></div>
   <div class="sec"><h3>Способ оплаты</h3></div>
   ${pmList()}
   <div class="sum"><span>Итого</span><b class="num">${fmt(sum)} <small>сом</small></b></div>
   ${need?`<button class="btn btn-p" data-act="mk-top" data-need="${need}">${F.topUp(fmt(need))}</button>`:`<button class="btn btn-p" data-act="mk-buy">${F.buy(fmt(sum))}</button>`}
   <p class="legal center">${ic('lock',14)}Билет придёт в приложение сразу после оплаты</p>`;
}
function openEvt(id){MK={id,s:0,n:1};openSheet(tx(evtById(id).t),evtHTML(),'evt');}
function mkBuy(){
  if(!MK)return;
  const e=evtById(MK.id),sec=e.sec[MK.s],n=MK.n,sum=sec[2]*n;
  const t={id:'tk'+Date.now(),evt:e.id,sec:MK.s,n,amount:sum,no:'ЭП-Б-'+(3140+(st.tickets.length*7)+n)};
  st.tickets.unshift(t);MK=null;
  confirmPay({id:t.id,once:1,tkt:1,short:e.t,sub:sec[0],icon:e.icon,amount:sum,acc:t.no});
}
const tktCard=t=>{
  const e=evtById(t.evt),sec=e.sec[t.sec];
  return `<div class="tkt">
   <div class="tkt-top" style="background:${evtGrad(e)}">${ic(e.icon,24)}<span class="mid"><b>${e.t}</b><span><em>${e.d}</em> · ${e.time}</span></span>${t.used?chipx('Проверен','rgba(255,255,255,.22)','#FFFFFF'):''}</div>
   <div class="tkt-cut"><i></i></div>
   <div class="tkt-bd"><div class="tkt-qr">${qrSVG(t.no)}</div>
    <div class="tkt-meta"><div><span>Сектор</span><b>${sec[0]}</b></div><div><span>Билетов</span><b class="num">${t.n}</b></div><div><span>Где</span><b>${e.v}</b></div><div><span>Номер</span><b class="num">${t.no}</b></div></div></div>
   <div class="tkt-cta"><button class="btn btn-p" data-act="tk-gate" data-id="${t.id}">${ic('qr',20)}Показать на входе</button>
    <button class="btn btn-s" data-act="toast" data-msg="Билет отправлен — получатель откроет его в ЭлPay">${ic('share-2',20)}Передать билет</button></div></div>`;
};
function renderTickets(){
  const el=$('#tk-body');if(!el)return;
  const tk=st.tickets||[];
  el.innerHTML=`<div class="nav"><button class="nb" data-act="tk-back" aria-label="Назад">${ic('chevron-left',24)}</button><span class="nt">Мои билеты</span><span class="sp"></span></div>
  <p class="sub">Билет живёт в приложении: на входе контролёр сканирует QR. Бумажный билет и скриншот не нужны.</p>
  <div style="margin-top:16px">${tk.length?tk.map(tktCard).join(''):`<p class="empty">Билетов пока нет — купите на афише города</p><button class="btn btn-s" data-act="mk-open">${ic('ticket',20)}Открыть афишу</button>`}</div>
  ${tk.length?`<p class="hint2">Билеты можно передать родным: получателю придёт свой QR, а старый перестанет работать.</p>`:''}`;
  if(ky())trTree(el);
}
function openTickets(from){st.tkFrom=from||st.tab;closeSheet();renderTickets();go('tickets');}
var gateT;
function openGate(id){
  const t=(st.tickets||[]).find(x=>x.id===id);if(!t)return;
  const e=evtById(t.evt),sec=e.sec[t.sec],g=$('#gate');
  hidePush();closeSheet();
  g.innerHTML=`<div class="gate-qr" id="gate-qr">${qrSVG(t.no)}<span class="gate-ok">${ic('check',72,2.4)}</span></div>
   <h3>${e.t}</h3>
   <p><em>${sec[0]}</em> · ${F.tkQty(t.n)}</p>
   <p><em>${e.d}</em> · ${e.time} · <em>${e.v}</em></p>
   <span class="chip soft" id="gate-st">${ic('qr',14)}Поднесите к сканеру на входе</span>
   <button class="btn btn-s" data-act="gate-close">Закрыть</button>`;
  if(ky())trTree(g);
  g.classList.add('on');g.setAttribute('aria-hidden','false');
  clearTimeout(gateT);
  gateT=setTimeout(()=>{
    if(!g.classList.contains('on'))return;
    const q=$('#gate-qr');if(q)q.classList.add('ok');
    const b=$('#gate-st');if(b){b.className='chip ok';b.innerHTML=ic('check',14,3)+tx('Билет принят — проход открыт');}
    t.used=1;renderTickets();
  },2600);
}
function closeGate(){const g=$('#gate');if(!g||!g.classList.contains('on'))return;clearTimeout(gateT);g.classList.remove('on');g.setAttribute('aria-hidden','true');}
const MKACT={
  'mk-open':()=>openMarket(),
  'mk-filter':t=>{st.mkF=t.dataset.k;renderMarket();},
  evt:t=>openEvt(t.dataset.id),
  'mk-sec':t=>{if(MK){MK.s=+t.dataset.i;setBody(evtHTML());}},
  'mk-qty':t=>{if(MK){MK.n=Math.min(8,Math.max(1,MK.n+(+t.dataset.d)));setBody(evtHTML());}},
  'mk-top':t=>{if(MK)MK.pending=1;openTop(+(t.dataset.need||0));},
  'mk-buy':()=>mkBuy(),
  'tk-list':()=>openTickets(cur==='market'?'market':st.tab),
  'tk-back':()=>{closeGate();go(st.tkFrom==='market'?'market':st.tab,'back');},
  'tk-gate':t=>openGate(t.dataset.id),
  'gate-close':()=>closeGate()
};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("/* ===== Жесты: свайп назад, между вкладками и закрытие шторки ===== */",
    "Object.assign(ACT2,MKACT);\n\n/* ===== Жесты: свайп назад, между вкладками и закрытие шторки ===== */")

# ===================== 8. Кыргызский словарь =====================
PAIRS = [
 ('Маркет', 'Маркет'),
 ('Афиша Оша', 'Ош шаарынын афишасы'),
 ('Концерты, театр, кино и спорт. Билет приходит в приложение — на входе покажите QR.',
  'Концерттер, театр, кино жана спорт. Билет тиркемеге келет — кире беришке QR көрсөтүңүз'),
 ('Концерты, театр, кино и спорт', 'Концерттер, театр, кино жана спорт'),
 ('Мои билеты', 'Менин билеттерим'),
 ('QR на входе — без бумажных билетов', 'Кире беришке QR — кагаз билетсиз'),
 ('Билеты', 'Билеттер'),
 ('Всё', 'Баары'),
 ('Концерты', 'Концерттер'),
 ('Театр', 'Театр'),
 ('Кино', 'Кино'),
 ('Спорт', 'Спорт'),
 ('В этой категории пока ничего нет', 'Бул категорияда азырынча эч нерсе жок'),
 ('Маркет — точка роста ЭлPay: комиссия с продажи билетов и афиша городских событий рядом с коммунальными счетами.',
  'Маркет — ЭлPay өсүү багыты: билет сатуудан комиссия жана шаардык окуялардын афишасы коммуналдык эсептердин жанында.'),
 ('Билеты на концерты, театр, кино и спорт — в разделе «Маркет». Подключать ничего не нужно.',
  'Концерт, театр, кино жана спорт билеттери — «Маркет» бөлүмүндө. Эч нерсе туташтыруу талап кылынбайт.'),
 # события
 ('Тайна Сулайман-Тоо', 'Сулайман-Тоонун сыры'),
 ('Ночь этно-музыки', 'Этно-музыка кечеси'),
 ('Мультсеанс для детей', 'Балдар үчүн мультсеанс'),
 ('Ошский драмтеатр им. Бабура', 'Бабур атындагы Ош драма театры'),
 ('Кинотеатр «Ынтымак», зал 2', '«Ынтымак» кинотеатры, 2-зал'),
 ('Кинотеатр «Ынтымак», зал 1', '«Ынтымак» кинотеатры, 1-зал'),
 ('Стадион им. Ниязбекова', 'Ниязбеков атындагы стадион'),
 ('Парк Навои, летняя сцена', 'Навои паркы, жайкы сахна'),
 ('12 октября', '12-октябрь'),
 ('18 октября', '18-октябрь'),
 ('5 октября', '5-октябрь'),
 ('27 сентября', '27-сентябрь'),
 ('28 сентября', '28-сентябрь'),
 ('сегодня', 'бүгүн'),
 ('Большой сольный концерт с оркестром: новые песни и лучшее за десять лет.',
  'Оркестр менен чоң жеке концерт: жаңы ырлар жана он жылдын мыктысы.'),
 ('Историческая драма о правительнице Алая. Спектакль на кыргызском языке.',
  'Алайдын башкаруучусу тууралуу тарыхый драма. Спектакль кыргыз тилинде.'),
 ('Семейное приключение о легендах священной горы. Дубляж кыргызский и русский.',
  'Ыйык тоонун легендалары тууралуу үй-бүлөлүк тасма. Дубляж кыргызча жана орусча.'),
 ('Матч Премьер-лиги Кыргызстана. Ворота открываются за час до начала.',
  'Кыргызстандын Премьер-лигасынын оюну. Дарбазалар башталаардан бир саат мурун ачылат.'),
 ('Комуз, темир-комуз и электроника: пять коллективов из Оша, Бишкека и Нарына.',
  'Комуз, темир комуз жана электроника: Ош, Бишкек жана Нарындан беш коллектив.'),
 ('Утренний сеанс с кыргызским дубляжом. Детям до трёх лет — бесплатно.',
  'Кыргызча дубляж менен эртең мененки сеанс. Үч жашка чейинки балдарга — бекер.'),
 # секторы
 ('Партер', 'Партер'),
 ('Амфитеатр', 'Амфитеатр'),
 ('Балкон', 'Балкон'),
 ('1–6 ряд', '1–6-катар'),
 ('7–14 ряд', '7–14-катар'),
 ('1–8 ряд', '1–8-катар'),
 ('свободные места', 'эркин орундар'),
 ('VIP-диван', 'VIP-диван'),
 ('последний ряд', 'акыркы катар'),
 ('Обычное место', 'Кадимки орун'),
 ('ряды 3–8', '3–8-катарлар'),
 ('Западная трибуна', 'Батыш трибунасы'),
 ('центр поля', 'аянттын борбору'),
 ('Восточная трибуна', 'Чыгыш трибунасы'),
 ('за воротами', 'дарбазанын артында'),
 ('Танцевальная зона', 'Бий аянты'),
 ('стоя у сцены', 'сахнанын алдында туруп'),
 ('Столик на четверых', 'Төрт кишилик столик'),
 ('с местами', 'орундары менен'),
 ('Любое место', 'Каалаган орун'),
 ('зал 1', '1-зал'),
 # шторка события
 ('Начало', 'Башталышы'),
 ('Билет', 'Билет'),
 ('Электронный, QR на входе', 'Электрондук, кире беришке QR'),
 ('Сектор', 'Сектор'),
 ('Сколько билетов', 'Канча билет'),
 ('Меньше', 'Азыраак'),
 ('Больше', 'Көбүрөөк'),
 ('Билет придёт в приложение сразу после оплаты', 'Төлөгөндөн кийин билет дароо тиркемеге келет'),
 # успех и билеты
 ('Открыть билет', 'Билетти ачуу'),
 ('Билет уже в разделе «Мои билеты» — на входе покажите QR.',
  'Билет «Менин билеттерим» бөлүмүндө — кире беришке QR көрсөтүңүз.'),
 ('Билет живёт в приложении: на входе контролёр сканирует QR. Бумажный билет и скриншот не нужны.',
  'Билет тиркемеде турат: кире беришке контролёр QR сканерлейт. Кагаз билет жана скриншот талап кылынбайт.'),
 ('Билетов пока нет — купите на афише города', 'Азырынча билет жок — шаардын афишасынан сатып алыңыз'),
 ('Открыть афишу', 'Афишаны ачуу'),
 ('Билетов', 'Билет'),
 ('Где', 'Кайда'),
 ('Номер', 'Номери'),
 ('Показать на входе', 'Кире беришке көрсөтүү'),
 ('Передать билет', 'Билетти өткөрүү'),
 ('Билет отправлен — получатель откроет его в ЭлPay',
  'Билет жөнөтүлдү — алуучу аны ЭлPay тиркемесинде ачат'),
 ('Проверен', 'Текшерилди'),
 ('Билеты можно передать родным: получателю придёт свой QR, а старый перестанет работать.',
  'Билеттерди жакындарыңызга өткөрүп берүүгө болот: алуучуга өз QR келет, эскиси иштебей калат.'),
 # экран на входе
 ('Поднесите к сканеру на входе', 'Кире беришке сканерге жакындатыңыз'),
 ('Билет принят — проход открыт', 'Билет кабыл алынды — өтүү ачык'),
 ('QR-код билета', 'Билеттин QR-коду'),
 # панель питча
 ('Билет на концерт и QR на входе', 'Концертке билет жана кире беришке QR'),
]
i = s.find('const KY=')
assert i > 0
j = s.find(';\n', i)
assert j > i
KY = json.loads(s[i + len('const KY='):j])
added = 0
for ru, kyt in PAIRS:
    if ru not in KY:
        KY[ru] = kyt
        added += 1
s = s[:i + len('const KY=')] + json.dumps(KY, ensure_ascii=False, separators=(',', ':')) + s[j:]

io.open(P, 'w', encoding='utf-8').write(s)
print('ok, ky added:', added, 'size:', len(s))
