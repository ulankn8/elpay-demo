# -*- coding: utf-8 -*-
"""ЭлPay v3.2 — тихие часы, спор по начислению, семейный доступ."""
import io, json

P = 'index.html'
s = io.open(P, encoding='utf-8').read()


def rep(old, new, cnt=1):
    global s
    n = s.count(old)
    assert n == cnt, 'expected %d, found %d: %r' % (cnt, n, old[:110])
    s = s.replace(old, new)


CSS = """
/* ===== Тихие часы, спор, семья ===== */
.inp textarea{flex:1;min-width:0;min-height:80px;padding:4px 0;border:0;background:transparent;color:inherit;font:inherit;resize:none;outline:none}
.inp.area{align-items:flex-start;padding-top:12px}
.fm{display:flex;align-items:center;gap:12px;padding:12px 14px;border-radius:16px;background:var(--soft)}
.fm+.fm{margin-top:8px}
.fm .mid b{display:block;font-size:14px;font-weight:700}
.fm .mid span{display:block;font-size:12.5px;color:var(--muted)}
.dsp-st{display:flex;align-items:flex-start;gap:10px;margin-top:12px;padding:12px 14px;border-radius:16px;background:#FDF1E3;color:#8A5B12;font-size:13px;font-weight:600;line-height:1.4}
.dsp-st .i{flex:none}
"""
rep('</style>', CSS + '</style>')

# ---- состояние ----
rep("pinOn:0,bioOn:1,pin:'4815',qh:['22:00','08:00']});",
    "pinOn:0,bioOn:1,pin:'4815',qh:['22:00','08:00'],dsp:{},fam:[{id:'f1',n:'Айгерим Токтогулова',r:'Владелец',you:1,pay:1},{id:'f2',n:'Нурлан Токтогулов',r:'Супруг',pay:1},{id:'f3',n:'Гүлнара Токтогулова',r:'Мама',pay:0}]});")

# ---- профиль: семья ----
rep("""              <div class="sec rv" style="--d:4"><h3>Способы оплаты</h3></div>""",
    """              <div class="sec rv" style="--d:4"><h3>Семья и доступ</h3></div>
              <div class="group rv wrap" style="--d:4">
                <button class="row" data-act="fam-open"><span class="tile soft c-kid"><i data-i="users"></i></span><span class="mid"><span class="t">Семейный доступ</span><span class="s">Кто видит счета и может платить</span></span><i data-i="chevron-right" data-s="18"></i></button>
              </div>
              <div class="sec rv" style="--d:4"><h3>Способы оплаты</h3></div>""")

# ---- чип «Спор» в ленте счетов ----
rep("""${st.paid[b.id]?okChip():st.qd[b.id]?`<span class="chip info sm">${tx('В очереди')}</span>`:b.part?""",
    """${st.paid[b.id]?okChip():st.qd[b.id]?`<span class="chip info sm">${tx('В очереди')}</span>`:st.dsp[b.id]?`<span class="chip warn sm">${tx('Спор')}</span>`:b.part?""")

# ---- карточка счёта: статус спора и кнопка ----
rep("""    ${b.hist?bars(b):''}
    ${ctrlBlock(b)}""",
    """    ${dspBlock(b)}
    ${b.hist?bars(b):''}
    ${ctrlBlock(b)}""")

rep("""    <button class="btn btn-s" data-act="part-open" data-id="${b.id}">${ic('banknote',20)}Оплатить часть</button>`}`,'bill');""",
    """    <button class="btn btn-s" data-act="part-open" data-id="${b.id}">${ic('banknote',20)}Оплатить часть</button>`}
    ${st.dsp[b.id]?'':`<button class="btn btn-g" data-act="dsp-open" data-id="${b.id}">${ic('triangle-alert',20)}Оспорить начисление</button>`}`,'bill');""")

# ---- тихие часы в настройках уведомлений ----
rep("""  el.innerHTML=NOTIF.map(([k,i,t,s2])=>`<div class="row"><span class="tile">${ic(i)}</span><span class="mid"><span class="t">${t}</span><span class="s">${s2}</span></span><button class="sw" role="switch" aria-checked="${!!st.pn[k]}" aria-label="${t}" data-act="pn" data-k="${k}"></button></div>`).join('')""",
    """  el.innerHTML=NOTIF.map(([k,i,t,s2])=>`<div class="row"><span class="tile">${ic(i)}</span><span class="mid"><span class="t">${t}</span><span class="s">${k==='quiet'?F.quiet(st.qh[0],st.qh[1]):s2}</span></span><button class="sw" role="switch" aria-checked="${!!st.pn[k]}" aria-label="${t}" data-act="pn" data-k="${k}"></button></div>`).join('')
   +(st.pn.quiet?`<button class="row" data-act="quiet-edit"><span class="tile">${ic('clock')}</span><span class="mid"><span class="t">Изменить тихие часы</span><span class="s">${F.quiet(st.qh[0],st.qh[1])}</span></span>${ic('chevron-right',18)}</button>`:'')""")

JS = r"""/* ===== Тихие часы, спор по начислению, семейный доступ ===== */
Object.assign(F,{
 quiet:(a,b)=>ky()?`${a} — ${b} үнсүз`:`С ${a} до ${b} без звука`,
 dspNo:n=>ky()?`Кайрылуу ${n}`:`Обращение ${n}`,
 famN:n=>ky()?`${n} адам`:`${n} ${plural(n,'человек','человека','человек')}`});
/* --- тихие часы --- */
const QH=['20:00','21:00','22:00','23:00'],QH2=['06:00','07:00','08:00','09:00'];
function quietHTML(){
  return `<p class="sub">В тихие часы пуши приходят без звука. Аварийные отключения воды и света приходят всегда.</p>
   <div class="field" style="margin-top:14px"><span class="lbl">Начало</span><div class="cities">${QH.map(v=>`<button class="city${st.qh[0]===v?' on':''}" data-act="qh-a" data-v="${v}">${st.qh[0]===v?ic('check',16):''}${v}</button>`).join('')}</div></div>
   <div class="field"><span class="lbl">Конец</span><div class="cities">${QH2.map(v=>`<button class="city${st.qh[1]===v?' on':''}" data-act="qh-b" data-v="${v}">${st.qh[1]===v?ic('check',16):''}${v}</button>`).join('')}</div></div>
   <div class="tip">${ic('info',18)}<span>Счета и напоминания об оплате придут утром — сразу после тихих часов.</span></div>
   <button class="btn btn-p" data-act="close">Готово</button>`;
}
/* --- спор по начислению --- */
const DSPR=[['big','Сумма завышена'],['paid','Уже оплачено'],['meter','Не сходятся показания'],['no','Не проживаю по адресу']];
let DSP=null;
function dspBlock(b){
  const d=st.dsp[b.id];if(!d)return '';
  return `<div class="dsp-st">${ic('clock',18)}<span>${tx(F.dspNo(d.no))} · ${tx(d.done?'решено: перерасчёт поставщиком':'на рассмотрении, ответ до 24 сентября')}</span></div>`;
}
function dspHTML(){
  const b=billById(DSP.id);if(!b)return '';
  return `<p class="sub">Опишите, что не так с начислением. Обращение уйдёт поставщику, а копия — в поддержку ЭлPay.</p>
   <div class="bs-top" style="margin-top:14px">${tile(b)}<div class="mid"><b>${b.short}</b><span>${F.accFull(b.acc||'—')} · ${fmt(b.amount)} сом</span></div></div>
   <div class="field" style="margin-top:16px"><span class="lbl">Причина</span><div class="cities">${DSPR.map(([k,l])=>`<button class="city${DSP.r===k?' on':''}" data-act="dsp-r" data-k="${k}">${DSP.r===k?ic('check',16):''}${l}</button>`).join('')}</div></div>
   <div class="field"><label for="dsp-t">Комментарий</label><div class="inp area"><textarea id="dsp-t" placeholder="Например: в квитанции 564 сома, а по счётчику выходит 320">${DSP.t||''}</textarea></div><p class="hint">Можно приложить фото квитанции или счётчика</p></div>
   <button class="btn btn-s" data-act="toast" data-msg="Фото квитанции приложено">${ic('receipt',20)}Приложить фото</button>
   <button class="btn btn-p" data-act="dsp-send">${ic('arrow-right',20)}Отправить обращение</button>
   <p class="legal center">${ic('lock',14)}Пока идёт разбор, пени по счёту не начисляются</p>`;
}
function dspOpen(id){
  DSP={id,r:'big',t:''};
  const open=()=>openSheet(tx('Оспорить начисление'),dspHTML(),'dsp');
  if(st.sheet){closeSheet();setTimeout(open,280);}else open();
}
function dspSend(){
  const b=billById(DSP.id);if(!b)return;
  const t=($('#dsp-t').value||'').trim();
  if(t.length<5)return fErr('#dsp-t','Опишите проблему — хотя бы пару слов');
  const no='ЭП-О-'+(1180+Object.keys(st.dsp).length*3);
  st.dsp[b.id]={no,r:DSP.r,t,done:0};
  const name=b.short;DSP=null;closeSheet();renderAll();
  toast('Обращение отправлено — ответ до 24 сентября');
  chatPush({t:'Приняли обращение по счёту «'+name+'». Номер '+no+'. Поставщик отвечает до 3 рабочих дней, пени не начисляются.',w:TODAY.time});
  setTimeout(()=>{if(!st.sheet&&cur!=='chat')showPush('dsp',5600);},1400);
}
PUSHES.dsp={t:'Обращение принято',b:'Поставщик проверит начисление. Ответ придёт в чат поддержки.',act:'chat-open',k:'new'};
/* --- семейный доступ --- */
let FAMD=null;
function famRow(m){
  return `<div class="fm"><span class="ava">${initials(m.n)}</span><span class="mid"><b>${m.n}</b><span>${tx(m.r)}${m.inv?' · '+tx('приглашение отправлено'):''}</span></span>${m.you?chipx('Вы','#DEF3EC','#05804F'):m.pay?chipx('Может платить','#EEF1EF','#3C4A55'):chipx('Только просмотр','#EEF1EF','#3C4A55')}</div>`;
}
function famHTML(){
  if(FAMD)return `<p class="sub">Участник увидит счета выбранных объектов. Реквизиты карт остаются только у владельца.</p>
   <div class="field" style="margin-top:14px"><label for="fm-n">Имя</label><div class="inp"><input id="fm-n" value="${FAMD.n||''}" placeholder="Например, Нурлан"></div></div>
   <div class="field"><label for="fm-p">Телефон</label><div class="inp"><span class="pre">+996</span><input id="fm-p" inputmode="numeric" value="${FAMD.p||''}" placeholder="555 12 34 56"></div></div>
   <div class="field"><span class="lbl">Права</span><div class="cities"><button class="city${FAMD.pay?' on':''}" data-act="fm-right" data-v="1">${FAMD.pay?ic('check',16):''}Может платить</button><button class="city${FAMD.pay?'':' on'}" data-act="fm-right" data-v="0">${FAMD.pay?'':ic('check',16)}Только просмотр</button></div></div>
   <button class="btn btn-p" data-act="fm-save">${ic('share-2',20)}Отправить приглашение</button>
   <button class="btn btn-s" data-act="fam-open">Назад</button>`;
  return `<p class="sub">Общие счета, но свои карты: близкие видят начисления и платят, а история и способы оплаты у каждого свои.</p>
   <div style="margin-top:14px">${st.fam.map(famRow).join('')}</div>
   <div class="sec"><h3>Что видит участник</h3></div>
   <div class="group wrap">${st.obj.map(o=>`<div class="row">${objTile(o.id,22,1)}<span class="mid"><span class="t">${tx(o.name)}</span><span class="s">${F.billsN(objBills(o.id).length)}</span></span><button class="sw" role="switch" aria-checked="true" aria-label="${tx(o.name)}" data-act="sw" data-on="Объект открыт семье" data-off="Объект скрыт от семьи"></button></div>`).join('')}</div>
   <button class="btn btn-p" style="margin-top:16px" data-act="fm-add">${ic('plus',20)}Пригласить в семью</button>
   <p class="legal center">${ic('lock',14)}Доступ можно отозвать в любой момент</p>`;
}
function famSave(){
  const n=($('#fm-n').value||'').trim(),p=($('#fm-p').value||'').replace(/\D/g,'');
  $$('#sh-body .field').forEach(f=>f.classList.remove('err'));
  if(n.length<2)return fErr('#fm-n','Введите имя');
  if(p.length!==9)return fErr('#fm-p','Нужно 9 цифр после +996');
  st.fam.push({id:'f'+Date.now(),n,r:'Приглашён по номеру +996 '+fmtPhone(p),pay:!!FAMD.pay,inv:1});
  FAMD=null;setBody(famHTML());renderAll();
  toast('Приглашение отправлено в SMS');
}
const FAMACT={
  'quiet-edit':()=>openSheet(tx('Тихие часы'),quietHTML(),'qh'),
  'qh-a':t=>{st.qh[0]=t.dataset.v;setBody(quietHTML());renderNotif();},
  'qh-b':t=>{st.qh[1]=t.dataset.v;setBody(quietHTML());renderNotif();},
  'dsp-open':t=>dspOpen(t.dataset.id),
  'dsp-r':t=>{DSP.t=($('#dsp-t')||{}).value||DSP.t;DSP.r=t.dataset.k;setBody(dspHTML());},
  'dsp-send':()=>dspSend(),
  'fam-open':()=>{FAMD=null;openSheet(tx('Семейный доступ'),famHTML(),'fam');},
  'fm-add':()=>{FAMD={n:'',p:'',pay:1};setBody(famHTML());},
  'fm-right':t=>{FAMD.n=$('#fm-n').value;FAMD.p=$('#fm-p').value;FAMD.pay=t.dataset.v==='1';setBody(famHTML());},
  'fm-save':()=>famSave()
};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("Object.assign(ACT2,MKACT,OFFACT,PINACT);", "Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT);")
rep("""PART=null;FAIL=null;LK=null;renderOff();""",
    """PART=null;FAIL=null;LK=null;DSP=null;FAMD=null;renderOff();""")

PAIRS = [
 ('Изменить тихие часы', 'Үнсүз сааттарды өзгөртүү'),
 ('Тихие часы', 'Үнсүз сааттар'),
 ('В тихие часы пуши приходят без звука. Аварийные отключения воды и света приходят всегда.',
  'Үнсүз сааттарда push үнсүз келет. Суу менен жарыктын авариялык өчүрүлүшү ар дайым келет.'),
 ('Начало', 'Башталышы'),
 ('Конец', 'Аякташы'),
 ('Счета и напоминания об оплате придут утром — сразу после тихих часов.',
  'Эсептер жана төлөм эскертүүлөрү эртең менен — үнсүз сааттардан кийин келет.'),
 ('Спор', 'Талаш'),
 ('Оспорить начисление', 'Эсептөөгө даттануу'),
 ('Опишите, что не так с начислением. Обращение уйдёт поставщику, а копия — в поддержку ЭлPay.',
  'Эсептөөдө эмне туура эмес экенин жазыңыз. Кайрылуу камсыздоочуга, көчүрмөсү ЭлPay колдоосуна жөнөйт.'),
 ('Причина', 'Себеби'),
 ('Сумма завышена', 'Сумма ашыкча'),
 ('Уже оплачено', 'Мурун төлөнгөн'),
 ('Не сходятся показания', 'Көрсөткүчтөр дал келбейт'),
 ('Не проживаю по адресу', 'Бул дарек боюнча жашабайм'),
 ('Комментарий', 'Комментарий'),
 ('Например: в квитанции 564 сома, а по счётчику выходит 320', 'Мисалы: квитанцияда 564 сом, эсептегичте 320'),
 ('Можно приложить фото квитанции или счётчика', 'Квитанциянын же эсептегичтин сүрөтүн тиркесе болот'),
 ('Приложить фото', 'Сүрөт тиркөө'),
 ('Фото квитанции приложено', 'Квитанциянын сүрөтү тиркелди'),
 ('Отправить обращение', 'Кайрылууну жөнөтүү'),
 ('Пока идёт разбор, пени по счёту не начисляются', 'Каралып жатканда эсепке айып пул кошулбайт'),
 ('Опишите проблему — хотя бы пару слов', 'Көйгөйдү жазыңыз — эң аз дегенде бир нече сөз'),
 ('Обращение отправлено — ответ до 24 сентября', 'Кайрылуу жөнөтүлдү — жооп 24-сентябрга чейин'),
 ('на рассмотрении, ответ до 24 сентября', 'каралууда, жооп 24-сентябрга чейин'),
 ('решено: перерасчёт поставщиком', 'чечилди: камсыздоочу кайра эсептеди'),
 ('Обращение принято', 'Кайрылуу кабыл алынды'),
 ('Поставщик проверит начисление. Ответ придёт в чат поддержки.', 'Камсыздоочу эсептөөнү текшерет. Жооп колдоо чатына келет.'),
 ('Семейный доступ', 'Үй-бүлөлүк мүмкүнчүлүк'),
 ('Кто видит счета и может платить', 'Ким эсептерди көрөт жана төлөй алат'),
 ('Семья и доступ', 'Үй-бүлө жана мүмкүнчүлүк'),
 ('Общие счета, но свои карты: близкие видят начисления и платят, а история и способы оплаты у каждого свои.',
  'Жалпы эсептер, бирок карталар өзүнчө: жакындар эсептерди көрүп төлөй алат, тарых менен төлөм ыкмалары ар кимдин өзүндө.'),
 ('Что видит участник', 'Катышуучу эмнени көрөт'),
 ('Пригласить в семью', 'Үй-бүлөгө чакыруу'),
 ('Доступ можно отозвать в любой момент', 'Мүмкүнчүлүктү каалаган убакта кайтарып алса болот'),
 ('Участник увидит счета выбранных объектов. Реквизиты карт остаются только у владельца.',
  'Катышуучу тандалган объекттердин эсептерин көрөт. Карта реквизиттери ээсинде гана калат.'),
 ('Права', 'Укуктар'),
 ('Может платить', 'Төлөй алат'),
 ('Только просмотр', 'Кароо гана'),
 ('Отправить приглашение', 'Чакырууну жөнөтүү'),
 ('Приглашение отправлено в SMS', 'Чакыруу SMS менен жөнөтүлдү'),
 ('приглашение отправлено', 'чакыруу жөнөтүлдү'),
 ('Введите имя', 'Атын киргизиңиз'),
 ('Нужно 9 цифр после +996', '+996 дан кийин 9 сан керек'),
 ('Владелец', 'Ээси'),
 ('Супруг', 'Жубайы'),
 ('Мама', 'Апасы'),
 ('Вы', 'Сиз'),
 ('Объект открыт семье', 'Объект үй-бүлөгө ачык'),
 ('Объект скрыт от семьи', 'Объект үй-бүлөдөн жашырылган'),
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
