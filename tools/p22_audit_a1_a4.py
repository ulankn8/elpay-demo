# -*- coding: utf-8 -*-
"""Аудит A1–A4: списание кошелька, подтверждение кодом без Face ID,
показания счётчика пересчитывают счёт, блокировка требует заданный код."""
import io, json
P='index.html'; s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old); assert n==cnt,'expected %d, found %d: %r'%(cnt,n,old[:110]); s=s.replace(old,new)

# --- A3: показания пересчитывают счёт ---
rep("""  return [...u,...k,...x,...c].map(b=>{const p=st.part&&st.part[b.id];""",
    """  u.forEach(c=>{
    const r=st.read[c.svc],k=CTRL[c.svc];
    if(!r||!k||!k.tar||(c.who||WHO0)!==WHO0)return;
    const first=st.conn.find(x=>x.svc===c.svc&&(x.who||WHO0)===WHO0);
    if(!first||first.id!==c.id)return;
    const d=Math.max(0,r-k.prev);
    c.amount=Math.round(d*k.tar*100)/100;
    c.read=fmt(k.prev)+' → '+fmt(r);
    c.meta=['Потребление',fmt(d)+' '+k.unit];
    c.recalc=1;
  });
  return [...u,...k,...x,...c].map(b=>{const p=st.part&&st.part[b.id];""")

rep("""    <div class="bs-sum num">${fmt(b.amount)} <small>сом</small></div>""",
    """    <div class="bs-sum num">${fmt(b.amount)} <small>сом</small></div>
    ${b.recalc?`<div class="tip ok">${ic('gauge',18)}<span>Сумма пересчитана по вашим показаниям от ${TODAY.d} сентября</span></div>`:''}""")

rep("""   <p class="hint2">${tx('Последний обход')} — ${tx(c.last)}${c.read!=='—'?', '+tx('снял')+' '+c.read:''}.</p>""",
    """   <p class="hint2">${tx('Последний обход')} — ${tx(c.last)}${c.read!=='—'?', '+tx('снял')+' '+c.read:''}.</p>
   ${st.read[b.svc]?`<div class="tip ok">${ic('check',18)}<span>${F.readMine(fmt(st.read[b.svc])+' '+c.unit)}</span></div>`:''}""")

# --- A1 + A2: кошелёк и подтверждение платежа ---
rep("""  closeSheet();await wait(260);
  const f=$('#fid');$('#fid-ic').innerHTML=ic('scan-face',56,1.6);$('#fid-t').textContent='Face ID';f.classList.remove('done');f.classList.add('on');
  await wait(1100);
  f.classList.add('done');$('#fid-ic').innerHTML=ic('circle-check',56,1.6);$('#fid-t').textContent=tx('Подтверждено');
  await wait(650);f.classList.remove('on');""",
    """  closeSheet();await wait(260);
  if(st.bioOn){
    const f=$('#fid');$('#fid-ic').innerHTML=ic('scan-face',56,1.6);$('#fid-t').textContent='Face ID';f.classList.remove('done');f.classList.add('on');
    await wait(1100);
    f.classList.add('done');$('#fid-ic').innerHTML=ic('circle-check',56,1.6);$('#fid-t').textContent=tx('Подтверждено');
    await wait(650);f.classList.remove('on');
  }else{
    const ok=await askPin();
    if(!ok)return;
    await wait(240);
  }""")

rep("""  if(!once)items.forEach(b=>st.paid[b.id]=1);
  histPush(items);st.lastItems=items;""",
    """  if(!once)items.forEach(b=>st.paid[b.id]=1);
  walletSpend(total(items));
  histPush(items);st.lastItems=items;""")

rep("""    if(!e.once)e.items.forEach(b=>st.paid[b.id]=1);
    histPush(e.items);""",
    """    if(!e.once)e.items.forEach(b=>st.paid[b.id]=1);
    walletSpend(total(e.items));
    histPush(e.items);""")

rep("function closeSheet(){st.sheet=null;",
    "function closeSheet(){if(st.sheet==='pp'&&PP){const f=PP;PP=null;f(false);}st.sheet=null;")

# --- A4: блокировка только с заданным кодом ---
rep("""function lockApp(){
  if(!st.reg){toast('Сначала пройдите регистрацию');return;}""",
    """function lockApp(){
  if(!st.reg){toast('Сначала пройдите регистрацию');return;}
  if(!st.pinOn){toast('Сначала поставьте код-пароль');return pinSetup();}""")

rep("""  if(n===10){if(!st.pinOn){st.pinOn=1;st.bioOn=1;renderAll();}lockApp();return;}""",
    """  if(n===10){if(!st.pinOn){st.pinOn=1;st.pin='4815';st.bioOn=1;renderAll();}lockApp();return;}""")

# --- новые функции ---
JS = r"""/* ===== Аудит A1–A4: кошелёк, подтверждение платежа, показания ===== */
Object.assign(F,{
 readMine:v=>ky()?`Сиз ${v} көрсөткүчүн бердиңиз — сумма кайра эсептелди`:`Вы передали ${v} — сумма счёта пересчитана`,
 walletLeft:v=>ky()?`Капчыкта ${v} сом калды`:`В кошельке осталось ${v} сом`});
function walletSpend(sum){
  if(st.pm!=='wallet')return;
  st.bal=Math.max(0,Math.round((st.bal-sum)*100)/100);
}
let PP=null;
function askPin(){
  return new Promise(res=>{
    PP=res;
    openSheet(tx('Подтвердите платёж'),`<p class="sub">Face ID выключен в настройках — подтвердите платёж код-паролем.</p>
     <div class="field" style="margin-top:14px"><label for="pp-code">Код-пароль</label><div class="inp">${ic('lock',20)}<input id="pp-code" inputmode="numeric" maxlength="4" type="password" placeholder="••••"></div><p class="hint">В демо это 4815</p></div>
     <button class="btn btn-p" data-act="pp-go">${ic('shield-check',20)}Подтвердить платёж</button>
     <button class="btn btn-s" data-act="close">Отмена</button>`,'pp');
    setTimeout(()=>{const i=$('#pp-code');if(i)i.focus({preventScroll:true});},260);
  });
}
function ppGo(){
  const v=($('#pp-code').value||'').replace(/\D/g,'');
  $$('#sh-body .field').forEach(f=>f.classList.remove('err'));
  if(v!==st.pin)return fErr('#pp-code','Неверный код-пароль');
  const f=PP;PP=null;st.sheet=null;
  $('#backdrop').classList.remove('on');$('#sheet').classList.remove('on');
  if(f)f(true);
}
const PAYACT={'pp-go':()=>ppGo()};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT,CRUDACT);",
    "Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT,CRUDACT,PAYACT);")
rep("PART=null;FAIL=null;LK=null;DSP=null;FAMD=null;ADR=null;ME=null;renderOff();",
    "PART=null;FAIL=null;LK=null;DSP=null;FAMD=null;ADR=null;ME=null;PP=null;renderOff();")

PAIRS=[('Подтвердите платёж','Төлөмдү ырастаңыз'),
 ('Face ID выключен в настройках — подтвердите платёж код-паролем.','Face ID жөндөөлөрдө өчүрүлгөн — төлөмдү код-сырсөз менен ырастаңыз.'),
 ('В демо это 4815','Демодо бул 4815'),
 ('Подтвердить платёж','Төлөмдү ырастоо'),
 ('Неверный код-пароль','Код-сырсөз туура эмес'),
 ('Сначала поставьте код-пароль','Адегенде код-сырсөз коюңуз'),
 ('Потребление','Керектөө')]
i=s.find('const KY='); j=s.find(';\n',i)
KY=json.loads(s[i+len('const KY='):j]); a=0
for ru,ky in PAIRS:
    if ru not in KY: KY[ru]=ky; a+=1
s=s[:i+len('const KY=')]+json.dumps(KY,ensure_ascii=False,separators=(',',':'))+s[j:]
io.open(P,'w',encoding='utf-8').write(s); print('ok, ky added:',a)
