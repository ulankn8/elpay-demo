# -*- coding: utf-8 -*-
"""Переделка списка к оплате: спокойная премиальная строка, «Детали» текстовой
кнопкой, выбор «все/снять», без конфликта сеток."""
import io, json
P='index.html'; s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old); assert n==cnt,'expected %d, found %d: %r'%(cnt,n,old[:110]); s=s.replace(old,new)

# 1) сетку строки счёта применяем только вне листа оплаты
rep(""".row.pay{display:grid;grid-template-columns:auto minmax(0,1fr) auto;grid-template-areas:"tile mid amt" "tile btns btns";align-items:center;column-gap:12px;row-gap:6px}
.row.pay>.tile{grid-area:tile}
.row.pay>.mid{grid-area:mid}
.row.pay>.end{display:contents}
.row.pay .amt{grid-area:amt;justify-self:end}
.row.pay .rowbtns{grid-area:btns;justify-self:end;margin-top:0}
.row.pay .mid .s{white-space:normal}""",
""".row.pay:not(.pi){display:grid;grid-template-columns:auto minmax(0,1fr) auto;grid-template-areas:"tile mid amt" "tile btns btns";align-items:center;column-gap:14px;row-gap:8px}
.row.pay:not(.pi)>.tile{grid-area:tile;align-self:start;margin-top:2px}
.row.pay:not(.pi)>.mid{grid-area:mid}
.row.pay:not(.pi)>.end{display:contents}
.row.pay:not(.pi) .amt{grid-area:amt;justify-self:end;align-self:start;font-size:16px;font-weight:700}
.row.pay:not(.pi) .rowbtns{grid-area:btns;justify-self:end;margin-top:0}
.row.pay:not(.pi) .mid .s{white-space:normal}
/* текстовая кнопка и шапка выбора */
.linkbtn{display:inline-flex;align-items:center;gap:5px;height:30px;padding:0 4px;background:none;font-size:13px;font-weight:600;color:var(--p700);white-space:nowrap}
.linkbtn:active{opacity:.6}
.linkbtn .i{opacity:.8}
.co-head{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:-2px 2px 0;font-size:13px;font-weight:600;color:var(--muted)}
.pi .end{align-items:flex-end;gap:2px}
.pi .end .amt{font-size:16px;font-weight:700}
.pi[aria-pressed="false"] .end .linkbtn{opacity:1}""")

# 2) строка в листе счетов: «Детали» — текстом, «Оплатить» — пилюлей
rep("""<span class="rowbtns"><button class="paybtn gh" data-act="bill" data-id="${b.id}" aria-label="${F.whatAria(b.short)}">${ic('info',15)}Детали</button><button class="paybtn" data-act="paybill" data-id="${b.id}">${ic('arrow-right',15)}Оплатить</button></span></span></div>`;""",
    """<span class="rowbtns"><button class="linkbtn" data-act="bill" data-id="${b.id}" aria-label="${F.whatAria(b.short)}">${ic('info',15)}Детали</button><button class="paybtn" data-act="paybill" data-id="${b.id}">${ic('arrow-right',15)}Оплатить</button></span></span></div>`;""")

# 3) строка в шторке оплаты: без второй кнопки, «Детали» под суммой
rep("""<div class="row pi${items.length>1?' pay':''}" data-act="pi" data-id="${b.id}" aria-pressed="${st.sel.includes(b.id)}"><span class="cb">${ic('check',14,3)}</span>${tile(b,0,20,'sm')}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.sub}${items.some(x=>whoOf(x)!==whoOf(items[0]))?`<em> · ${objName(whoOf(b))}</em>`:""}</span></span><span class="amt num">${fmt(b.amount)} <small>сом</small></span>${items.length>1?`<span class="rowbtns"><button class="paybtn gh" data-act="bill" data-id="${b.id}" aria-label="${F.whatAria(b.short)}">${ic('info',15)}Детали</button><button class="paybtn" data-act="paybill" data-id="${b.id}">${ic('arrow-right',15)}Оплатить</button></span>`:''}</div>""",
    """<div class="row pi" data-act="pi" data-id="${b.id}" aria-pressed="${st.sel.includes(b.id)}"><span class="cb">${ic('check',14,3)}</span>${tile(b,0,20,'sm')}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.sub}${items.some(x=>whoOf(x)!==whoOf(items[0]))?`<em> · ${objName(whoOf(b))}</em>`:""}</span></span><span class="end"><span class="amt num">${fmt(b.amount)} <small>сом</small></span>${items.length>1?`<button class="linkbtn" data-act="bill" data-id="${b.id}" aria-label="${F.whatAria(b.short)}">${ic('info',14)}Детали</button>`:''}</span></div>""")

# 4) шапка выбора над списком
rep("""  openSheet(ids.length>1?'Оплата счетов':'Оплата',`
    <div class="group wrap">""",
    """  ALLSEL=[...ids];
  openSheet(ids.length>1?'Оплата счетов':'Оплата',`
    ${ids.length>1?`<div class="co-head"><span id="co-cnt"></span><button class="linkbtn" data-act="co-all" id="co-all"></button></div>`:''}
    <div class="group wrap">""")

# 5) подсказка для нескольких счетов больше не нужна
rep("""  if(items.length!==1){
    return `<div class="co-what">${ic('info',18)}<span>${tx('«Детали» у счёта покажут реквизиты и расчёт')}</span></div>`;
  }""",
    """  if(items.length!==1)return '';""")

# 6) счётчик выбранного
rep("""function coSum(){
  const s=total(st.sel.map(billById)),b=$('#co-pay');""",
    """function coSum(){
  const s=total(st.sel.map(billById)),b=$('#co-pay');
  const cnt=$('#co-cnt');
  if(cnt){
    cnt.textContent=F.selOf(st.sel.length,(ALLSEL||[]).length);
    const all=$('#co-all'),full=(ALLSEL||[]).length&&st.sel.length===ALLSEL.length;
    if(all)all.textContent=tx(full?'Снять все':'Выбрать все');
  }""")

JS = r"""/* ===== Лист оплаты: выбор всех ===== */
let ALLSEL=[];
Object.assign(F,{selOf:(n,m)=>ky()?`${m} эсептен ${n} тандалды`:`Выбрано ${n} из ${m}`});
const SELACT={
  'co-all':()=>{
    const full=st.sel.length===ALLSEL.length;
    st.sel=full?[]:[...ALLSEL];
    $$('#sh-body .pi').forEach(el=>el.setAttribute('aria-pressed',String(st.sel.includes(el.dataset.id))));
    coSum();
  }
};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT,CRUDACT,PAYACT,CACT,DACT,THACT);",
    "Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT,CRUDACT,PAYACT,CACT,DACT,THACT,SELACT);")

PAIRS=[('Снять все','Баарын алып салуу'),('Выбрать все','Баарын тандоо'),('Детали','Чоо-жайы')]
i=s.find('const KY='); j=s.find(';\n',i)
KY=json.loads(s[i+len('const KY='):j]); a=0
for ru,ky in PAIRS:
    if ru not in KY: KY[ru]=ky; a+=1
s=s[:i+len('const KY=')]+json.dumps(KY,ensure_ascii=False,separators=(',',':'))+s[j:]
io.open(P,'w',encoding='utf-8').write(s); print('ok, ky added:',a)
