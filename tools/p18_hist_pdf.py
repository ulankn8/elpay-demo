# -*- coding: utf-8 -*-
"""ЭлPay v3.2 — фильтры в истории платежей и печать квитанции/выписки (PDF)."""
import io, json

P = 'index.html'
s = io.open(P, encoding='utf-8').read()


def rep(old, new, cnt=1):
    global s
    n = s.count(old)
    assert n == cnt, 'expected %d, found %d: %r' % (cnt, n, old[:110])
    s = s.replace(old, new)


CSS = """
/* ===== Фильтры истории ===== */
.hfil{display:flex;gap:8px;overflow-x:auto;scrollbar-width:none;padding:12px 0 2px}
.hfil::-webkit-scrollbar{display:none}
.hfil button{flex:none;display:flex;align-items:center;gap:6px;height:36px;padding:0 13px;border-radius:999px;border:1.5px solid var(--line);background:var(--bg);font-size:13px;font-weight:600;color:var(--gr)}
.hfil button.on{background:var(--gr);border-color:var(--gr);color:#fff}
.hfil button .dt{width:8px;height:8px;border-radius:50%}
"""
rep('</style>', CSS + '</style>')

# названия категорий — чтобы в квитанциях не было пустых полей
rep("const CATN={water:'Вода',power:'Свет',trash:'Мусор',kid:'Садик',school:'Школа',city:'Город'};",
    "const CATN={water:'Вода',power:'Свет',trash:'Мусор',kid:'Садик',school:'Школа',city:'Город',gas:'Газ',net:'Интернет и ТВ',door:'Домофон',tax:'Налоги',course:'Курсы',market:'Билеты'};")

rep("  hist:[],histQ:'',tickets:[]", "  hist:[],histQ:'',histCat:'',histPer:'y',tickets:[]")

# ---- фильтры в списке истории ----
rep("""  const list=histAll().filter(r=>m(r.name,r.sub,tx(r.name),tx(r.sub)));""",
    """  const months=(PERS.find(p=>p[0]===(st.histPer||'y'))||PERS[2])[2];
  const list=histAll().filter(r=>m(r.name,r.sub,tx(r.name),tx(r.sub))&&(!st.histCat||r.cat===st.histCat)&&months.includes(r.mi));""")

rep("""  el.innerHTML=gs.length?gs.map(g=>`<div class="sec"><h3>${tx(RMONF[g.mi])}</h3><span class="amt num">${fmt(g.sum)} <small>сом</small></span></div><div class="group wrap">${g.list.map(histRow).join('')}</div>`).join(''):'<p class="empty">Ничего не нашли. Попробуйте «садик» или «свет»</p>';""",
    """  el.innerHTML=gs.length?gs.map(g=>`<div class="sec"><h3>${tx(RMONF[g.mi])}</h3><span class="amt num">${fmt(g.sum)} <small>сом</small></span></div><div class="group wrap">${g.list.map(histRow).join('')}</div>`).join(''):`<p class="empty">${tx(st.histCat||st.histPer!=='y'?'По этому фильтру платежей нет':'Ничего не нашли. Попробуйте «садик» или «свет»')}</p>`;""")

rep("""  <div class="inp" style="margin-top:14px">${ic('search',20)}<input id="hist-q" type="search" placeholder="Название или получатель" value="${st.histQ||''}" autocomplete="off"></div>
  <div id="hist-list"></div>`;""",
    """  <div class="inp" style="margin-top:14px">${ic('search',20)}<input id="hist-q" type="search" placeholder="Название или получатель" value="${st.histQ||''}" autocomplete="off"></div>
  <div class="hfil">${histCats().map(c=>`<button class="${st.histCat===c?'on':''}" data-act="h-cat" data-c="${c}">${c?`<span class="dt" style="background:${COL[c]||'#3C4A55'}"></span>`:''}${c?tx(CATN[c]||c):tx('Все платежи')}</button>`).join('')}</div>
  <div class="cities" style="margin-top:8px">${PERS.map(p=>`<button class="city${(st.histPer||'y')===p[0]?' on':''}" data-act="h-per" data-k="${p[0]}">${(st.histPer||'y')===p[0]?ic('check',16):''}${p[1]}</button>`).join('')}</div>
  <div id="hist-list"></div>`;""")

# ---- квитанция: печать ----
rep("""   <button class="btn btn-p" data-act="rcpt-dl" data-id="${r.id}">${ic('download',20)}Скачать квитанцию</button>
   <button class="btn btn-s" data-act="toast" data-msg="Квитанция отправлена">${ic('share-2',20)}Поделиться</button>`,'rcpt');""",
    """   <button class="btn btn-p" data-act="rcpt-pdf" data-id="${r.id}">${ic('receipt',20)}Открыть PDF и печать</button>
   <button class="btn btn-s" data-act="rcpt-dl" data-id="${r.id}">${ic('download',20)}Скачать CSV</button>
   <button class="btn btn-g" data-act="toast" data-msg="Квитанция отправлена">${ic('share-2',20)}Поделиться</button>`,'rcpt');""")

# ---- выписка: PDF вместо заглушки ----
rep("""    if(EXP.fmt==='pdf')return toast('PDF-выписка будет в релизе — в демо доступен CSV');""",
    """    if(EXP.fmt==='pdf'){closeSheet();return printDoc(expDoc(expRows()));}""")

JS = r"""/* ===== Фильтры истории и печатные документы ===== */
function histCats(){
  const seen=[];histAll().forEach(r=>{if(r.cat&&!seen.includes(r.cat))seen.push(r.cat);});
  return ['',...seen];
}
function docWrap(title,body){
  return `<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title>
  <style>*{box-sizing:border-box}body{margin:0;padding:30px 26px;font-family:'Helvetica Neue',Arial,sans-serif;color:#1E2A32;background:#fff}
  .hd{display:flex;align-items:flex-end;justify-content:space-between;border-bottom:2px solid #1FB886;padding-bottom:12px}
  .wm{font-size:23px;font-weight:800;letter-spacing:-.02em}.wm b{color:#06A06E}
  .sub{font-size:11px;color:#6B7772;margin-top:3px}
  h1{font-size:17px;margin:22px 0 3px;letter-spacing:-.01em}
  .no{font-size:11.5px;color:#6B7772}
  .sum{margin-top:16px;font-size:27px;font-weight:800;letter-spacing:-.02em}
  .ok{display:inline-block;margin-top:9px;padding:5px 11px;border-radius:999px;background:#DEF3EC;color:#05804F;font-size:11px;font-weight:700}
  table{width:100%;border-collapse:collapse;margin-top:18px;font-size:12.5px}
  td,th{padding:9px 0;border-bottom:1px solid #E4E8E6;vertical-align:top;text-align:left}
  th{font-size:10.5px;text-transform:uppercase;letter-spacing:.04em;color:#9AA5A0}
  td.k{color:#6B7772;width:46%}
  td.v,th.v,td.r,th.r{text-align:right;font-weight:700}
  .tot{display:flex;justify-content:space-between;margin-top:14px;font-size:15px;font-weight:800}
  .ft{margin-top:26px;font-size:10.5px;color:#9AA5A0;line-height:1.55}
  @media print{body{padding:10px 0}}</style></head><body>${body}</body></html>`;
}
const docHead=right=>`<div class="hd"><div><div class="wm">Эл<b>Pay</b></div><div class="sub">продукт ELBAGAR · г. Ош</div></div><div class="no">${right}</div></div>`;
function rcptDoc(r){
  const rows=[['Номер квитанции',r.no],['Дата и время',dayTxt(r)+', '+r.time],['Плательщик',st.name],
   ['Получатель',tx(r.name)],['Назначение',tx(r.sub||CATN[r.cat]||'Платёж')],['Лицевой счёт',r.acc||'—'],
   ['Способ оплаты',tx(pmById(st.pm).t)],['Комиссия','0 сом'],['Статус','Исполнено']];
  return docWrap('Квитанция '+r.no,`${docHead(dayTxt(r))}
   <h1>Квитанция об оплате</h1><div class="no">№ ${r.no}</div>
   <div class="sum">${fmt(r.amount)} сом</div><span class="ok">Оплачено</span>
   <table>${rows.map(([k,v])=>`<tr><td class="k">${k}</td><td class="v">${v}</td></tr>`).join('')}</table>
   <div class="ft">Документ сформирован в приложении ЭлPay и равнозначен бумажной квитанции поставщика.<br>Прототип: все данные демонстрационные.</div>`);
}
function expDoc(rows){
  const sum=rows.reduce((a,b)=>a+b.amount,0),per=(PERS.find(p=>p[0]===EXP.per)||PERS[0])[1];
  return docWrap('Выписка ЭлPay',`${docHead(tx(per))}
   <h1>Выписка по платежам</h1><div class="no">${st.name} · ${tx(per)} · ${rows.length} ${plural(rows.length,'платёж','платежа','платежей')}</div>
   <table><tr><th>Дата</th><th>Получатель</th><th class="r">Сумма, сом</th></tr>
   ${rows.map(r=>`<tr><td class="k">${r.mi===11?'20.09.2026':r.iso.split('-').reverse().join('.')}</td><td>${tx(r.name)}<div class="no">${tx(r.sub||CATN[r.cat]||'')}</div></td><td class="r">${fmt(r.amount)}</td></tr>`).join('')}</table>
   <div class="tot"><span>Итого</span><span>${fmt(sum)} сом</span></div>
   <div class="ft">Выписка сформирована в приложении ЭлPay. Подходит для бухгалтерии, ТСЖ и личного учёта.<br>Прототип: все данные демонстрационные.</div>`);
}
function printDoc(html){
  let w=null;
  try{w=window.open('','_blank','width=520,height=740');}catch(e){}
  if(!w||!w.document)return toast('Разрешите всплывающие окна или откройте прототип в отдельной вкладке');
  try{
    w.document.open();w.document.write(html);w.document.close();
    setTimeout(()=>{try{w.focus();w.print();}catch(e){}},420);
    toast('Документ открыт — выберите «Сохранить как PDF»');
  }catch(e){toast('Печать недоступна в этом окне — откройте прототип в отдельной вкладке');}
}
const HISTACT={
  'h-cat':t=>{st.histCat=t.dataset.c||'';renderHist();},
  'h-per':t=>{st.histPer=t.dataset.k;renderHist();},
  'rcpt-pdf':t=>{const r=histAll().find(x=>x.id===t.dataset.id);if(r)printDoc(rcptDoc(r));}
};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT);", "Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT);")

PAIRS = [
 ('Все платежи', 'Бардык төлөмдөр'),
 ('По этому фильтру платежей нет', 'Бул чыпка боюнча төлөм жок'),
 ('Открыть PDF и печать', 'PDF ачуу жана басып чыгаруу'),
 ('Скачать CSV', 'CSV жүктөө'),
 ('Документ открыт — выберите «Сохранить как PDF»', 'Документ ачылды — «PDF катары сактоо» тандаңыз'),
 ('Разрешите всплывающие окна или откройте прототип в отдельной вкладке',
  'Калкып чыгуучу терезелерге уруксат бериңиз же прототипти өзүнчө өтмөктө ачыңыз'),
 ('Печать недоступна в этом окне — откройте прототип в отдельной вкладке',
  'Бул терезеде басып чыгаруу жеткиликсиз — прототипти өзүнчө өтмөктө ачыңыз'),
 ('Газ', 'Газ'),
 ('Интернет и ТВ', 'Интернет жана ТВ'),
 ('Домофон', 'Домофон'),
 ('Налоги', 'Салыктар'),
 ('Курсы', 'Курстар'),
 ('Билеты', 'Билеттер'),
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
