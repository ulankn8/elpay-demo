# -*- coding: utf-8 -*-
"""Перед оплатой видно, за что платим: кнопка деталей рядом с «Оплатить»,
реквизиты поставщика и расшифровка начисления в карточке счёта и в шторке оплаты."""
import io, json
P='index.html'; s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old); assert n==cnt,'expected %d, found %d: %r'%(cnt,n,old[:110]); s=s.replace(old,new)

CSS = """
/* ===== Детали начисления ===== */
.paybtn.gh{background:var(--line2);color:var(--gr3)}
.app.dark .paybtn.gh{background:rgba(222,243,236,.12);color:var(--gr3)}
.rowbtns{display:flex;align-items:center;gap:6px;margin-top:6px}
.rowbtns .paybtn{margin-top:0}
.pi.pay .rowbtns{grid-area:pay;justify-self:end}
.co-what{display:flex;align-items:center;gap:10px;padding:12px 14px;border-radius:16px;background:var(--soft);font-size:13px;font-weight:600;color:var(--gr3)}
.co-what .i{flex:none;color:var(--muted)}
"""
END = '.big-sum small{font-size:18px;font-weight:600;color:var(--muted)}\n'
rep(END, '.big-sum small{font-size:18px;font-weight:600;color:var(--muted)}' + CSS)

# ---------- реквизиты и расчёт поставщиков ----------
rep("""kw:'мусор тазалык вывоз таштанды'}""",
    """kw:'мусор тазалык вывоз таштанды',
   rec:'МП «Ош-Тазалык»',inn:'02508199610087',racc:'1091820110280103',
   calc:[['Тариф','45 сом с человека'],['Начислено на','4 проживающих'],['Итого','180 сом']]}""")
rep("""hist:[['апр',396],['май',344],['июн',301],['июл'""",
    """rec:'ОАО «Ошэлектро»',inn:'01709199510045',racc:'1091820110120457',
   calc:[['Тариф','1,37 сом за кВт·ч'],['Расход','412 кВт·ч'],['Итого','564,44 сом']],
   hist:[['апр',396],['май',344],['июн',301],['июл'""")
rep("""hist:[['апр',8],['май',9],['июн',11],['июл',12],['авг',9]],kw:'во""",
    """rec:'МП «Ошводоканал»',inn:'02212199410063',racc:'1091820110330281',
   calc:[['Тариф','22,78 сом за м³'],['Расход','9 м³'],['Итого','205 сом']],
   hist:[['апр',8],['май',9],['июн',11],['июл',12],['авг',9]],kw:'во""")
rep("""kw:'газ gas'}""",
    """kw:'газ gas',
   rec:'ОсОО «Газпром Кыргызстан», Ош',inn:'01502200810112',racc:'1091820110441209',
   calc:[['Тариф','105 сом с человека'],['Начислено на','4 проживающих'],['Итого','420 сом']]}""")
rep("""kw:'интернет тв wifi'}""",
    """kw:'интернет тв wifi',
   rec:'ОсОО «Ош Нет»',inn:'02904201510073',racc:'1091820110552317',
   calc:[['Тариф','Безлимит, 100 Мбит/с'],['Период','месяц'],['Итого','900 сом']]}""")
rep("""kw:'домофон подъезд'}""",
    """kw:'домофон подъезд',
   rec:'ОсОО «Домофон-Сервис»',inn:'03011201710055',racc:'1091820110663428',
   calc:[['Тариф','100 сом с квартиры'],['Квартира','14'],['Итого','100 сом']]}""")

rep("""acc:'20107200400123',meta:['Объект','кв. 14, ул. Курманжан Датка, 212']}""",
    """acc:'20107200400123',meta:['Объект','кв. 14, ул. Курманжан Датка, 212'],code:'11311100',
   calc:[['Объект','Квартира 54 м²'],['Ставка','0,35% от базы'],['Итого','1 240 сом']]}""")
rep("""acc:'20107200400123',meta:['Вид деятельности','Бытовые услуги']}""",
    """acc:'20107200400123',meta:['Вид деятельности','Бытовые услуги'],code:'11211100',
   calc:[['Вид деятельности','Бытовые услуги'],['Срок','октябрь 2026'],['Итого','1 800 сом']]}""")

# ---------- карточка счёта: как начислено и реквизиты ----------
rep("""    ${dspBlock(b)}""",
    """    ${calcBlock(b)}
    ${reqBlock(b)}
    ${dspBlock(b)}""")

# ---------- кнопка деталей рядом с «Оплатить» ----------
rep("""<span class="end"><span class="amt num">${fmt(b.amount)} <small>сом</small></span><button class="paybtn" data-act="paybill" data-id="${b.id}">${ic('arrow-right',15)}Оплатить</button></span></div>`;""",
    """<span class="end"><span class="amt num">${fmt(b.amount)} <small>сом</small></span><span class="rowbtns"><button class="paybtn gh" data-act="bill" data-id="${b.id}" aria-label="${F.whatAria(b.short)}">${ic('info',15)}Детали</button><button class="paybtn" data-act="paybill" data-id="${b.id}">${ic('arrow-right',15)}Оплатить</button></span></span></div>`;""")

rep("""${items.length>1?`<button class="paybtn" data-act="paybill" data-id="${b.id}">${ic('arrow-right',15)}Оплатить</button>`:''}""",
    """${items.length>1?`<span class="rowbtns"><button class="paybtn gh" data-act="bill" data-id="${b.id}" aria-label="${F.whatAria(b.short)}">${ic('info',15)}Детали</button><button class="paybtn" data-act="paybill" data-id="${b.id}">${ic('arrow-right',15)}Оплатить</button></span>`:''}""")

# ---------- в шторке оплаты видно, за что платим ----------
rep("""    <div class="sec"><h3>Способ оплаты</h3></div>
    ${pmList()}
    <div class="sum"><span>Итого</span><b class="num" id="co-sum"></b></div>""",
    """    ${coWhat(items)}
    <div class="sec"><h3>Способ оплаты</h3></div>
    ${pmList()}
    <div class="sum"><span>Итого</span><b class="num" id="co-sum"></b></div>""")

JS = r"""/* ===== За что платим: расчёт и реквизиты ===== */
const TAXREQ={rec:'УГНС по городу Ош',inn:'02707199210036',racc:'4402011101000340'};
Object.assign(F,{
 whatAria:n=>ky()?`Эмне үчүн төлөм: ${tx(n)}`:`За что платёж: ${n}`,
 reqHint:()=>ky()?'басып көчүрүңүз':'нажмите, чтобы скопировать'});
function payReq(b){
  if(b.tpl)return TPL[b.tpl].req;
  if(b.cust)return [['Получатель',b.rec||b.name],['ИНН',b.inn||'—'],...BANK,['Расчётный счёт',b.acc||'—'],['Назначение',b.purp||b.name]];
  if(b.tax)return [['Получатель',TAXREQ.rec],['ИНН',TAXREQ.inn],...BANK,['Расчётный счёт',TAXREQ.racc],['Код платежа',b.code||'11111100'],['Назначение',tx(b.name)+', '+tx(b.period)]];
  const u=UTIL.find(x=>x.id===b.svc);
  if(u)return [['Получатель',u.rec],['ИНН',u.inn],...BANK,['Расчётный счёт',u.racc],['Лицевой счёт',b.acc],['Назначение',tx(u.kind)+', '+tx(b.period)]];
  return [];
}
function payCalc(b){
  if(b.recalc&&CTRL[b.svc]){
    const k=CTRL[b.svc],d=Math.max(0,(st.read[b.svc]||0)-k.prev);
    return [['Тариф',String(k.tar).replace('.',',')+' сом за '+k.unit],['Расход',fmt(d)+' '+k.unit],['Итого',fmt(b.amount)+' сом']];
  }
  const u=UTIL.find(x=>x.id===b.svc);
  if(u&&u.calc)return u.calc;
  if(b.calc)return b.calc;
  if(b.tpl){const t=TPL[b.tpl];return [['Услуга',tx(t.org)],['Период','октябрь 2026'],['Итого',fmt(t.amount)+' сом']];}
  return [['Сумма к оплате',fmt(b.amount)+' сом']];
}
function calcBlock(b){
  const rows=payCalc(b);if(!rows.length)return '';
  return `<div class="sec"><h3>Как начислено</h3></div>
   <div class="kv">${rows.map(([k,v])=>`<div><span>${k}</span><b>${v}</b></div>`).join('')}</div>`;
}
function reqBlock(b){
  const rows=payReq(b);if(!rows.length)return '';
  return `<div class="sec"><h3>Реквизиты платежа</h3><span class="s">${F.reqHint()}</span></div>
   <div class="group">${rows.map(([k,v])=>`<div class="rq"><span class="k">${k}</span><span class="v">${v}</span><button class="cp" data-act="toast" data-msg="${F.copied(k)}" aria-label="${F.copyAria(k)}">${ic('copy',18)}</button></div>`).join('')}</div>
   <p class="hint2">Эти реквизиты ЭлPay подставляет сам — вводить их вручную не нужно.</p>`;
}
function coWhat(items){
  if(items.length!==1){
    return `<div class="co-what">${ic('info',18)}<span>${tx('«Детали» у счёта покажут реквизиты и расчёт')}</span></div>`;
  }
  const b=items[0],req=payReq(b),get=k=>(req.find(r=>r[0]===k)||[])[1];
  const rows=[['Получатель',get('Получатель')||tx(b.short)],[b.tpl?'Ребёнок':'Лицевой счёт',b.tpl?TPL[b.tpl].child:(b.acc||'—')],['Период',tx(b.period||'сентябрь 2026')]];
  return `<div class="sec"><h3>За что платим</h3></div>
   <div class="kv">${rows.map(([k,v])=>`<div><span>${k}</span><b>${v}</b></div>`).join('')}</div>
   <button class="row" data-act="bill" data-id="${b.id}" style="margin-top:10px">${tl('water','list-checks')}<span class="mid"><span class="t">Реквизиты и расчёт</span><span class="s">${tx('Как начислена сумма и кому уходит платёж')}</span></span>${ic('chevron-right',18)}</button>`;
}

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")

PAIRS=[('Как начислено','Кантип эсептелди'),('Реквизиты платежа','Төлөмдүн реквизиттери'),
 ('Эти реквизиты ЭлPay подставляет сам — вводить их вручную не нужно.','Бул реквизиттерди ЭлPay өзү коёт — кол менен киргизүүнүн кереги жок.'),
 ('За что платим','Эмне үчүн төлөйбүз'),('Реквизиты и расчёт','Реквизиттер жана эсептөө'),
 ('Как начислена сумма и кому уходит платёж','Сумма кантип эсептелди жана төлөм кимге барат'),
 ('«Детали» у счёта покажут реквизиты и расчёт','Эсептин «Чоо-жайы» реквизиттерди жана эсептөөнү көрсөтөт'),
 ('Детали','Чоо-жайы'),('Тариф','Тариф'),('Расход','Керектөө'),('Итого','Жыйынтык'),
 ('Начислено на','Эсептелди'),('Ставка','Ставка'),('Объект','Объект'),('Вид деятельности','Иш түрү'),
 ('Код платежа','Төлөм коду'),('Получатель','Алуучу'),('Расчётный счёт','Эсептешүү эсеби'),
 ('Назначение','Багыты'),('Квартира','Батир'),('Срок','Мөөнөтү'),('Услуга','Кызмат'),
 ('Сумма к оплате','Төлөнүүчү сумма'),('45 сом с человека','Бир кишиден 45 сом'),
 ('105 сом с человека','Бир кишиден 105 сом'),('100 сом с квартиры','Бир батирден 100 сом'),
 ('1,37 сом за кВт·ч','кВт·с үчүн 1,37 сом'),('22,78 сом за м³','м³ үчүн 22,78 сом'),
 ('Безлимит, 100 Мбит/с','Чексиз, 100 Мбит/с'),('месяц','ай'),('0,35% от базы','базанын 0,35%'),
 ('Квартира 54 м²','54 м² батир'),('Бытовые услуги','Турмуш-тиричилик кызматтары')]
i=s.find('const KY='); j=s.find(';\n',i)
KY=json.loads(s[i+len('const KY='):j]); a=0
for ru,ky in PAIRS:
    if ru not in KY: KY[ru]=ky; a+=1
s=s[:i+len('const KY=')]+json.dumps(KY,ensure_ascii=False,separators=(',',':'))+s[j:]
io.open(P,'w',encoding='utf-8').write(s); print('ok, ky added:',a)
