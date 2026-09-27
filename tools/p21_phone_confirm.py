# -*- coding: utf-8 -*-
"""ЭлPay v3.3 — смена номера телефона подтверждается кодом из SMS."""
import io, json
P='index.html'; s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old); assert n==cnt,'expected %d, found %d: %r'%(cnt,n,old[:110]); s=s.replace(old,new)

rep("""  st.name=n;st.phone='+996 '+fmtPhone(p);st.email=e;
  closeSheet();renderAll();toast('Данные сохранены');""",
    """  const np='+996 '+fmtPhone(p);
  if(np!==st.phone){ME={n,p:np,e};return openSheet(tx('Подтвердите номер'),phoneCodeHTML(),'mec');}
  st.name=n;st.email=e;
  closeSheet();renderAll();toast('Данные сохранены');""")

rep("""/* --- адреса --- */""",
    """let ME=null;
function phoneCodeHTML(){
  return `<p class="sub">Отправили SMS с кодом на <b>${ME.p}</b>. Пока номер не подтверждён, вход остаётся по старому.</p>
   <div class="field" style="margin-top:14px"><label for="mec-code">Код из SMS</label><div class="inp"><input id="mec-code" inputmode="numeric" maxlength="4" placeholder="4 цифры"></div><p class="hint">В демо код всегда 4815</p></div>
   <button class="btn btn-p" data-act="mec-go">${ic('shield-check',20)}Подтвердить номер</button>
   <button class="btn btn-s" data-act="me-edit">Изменить номер</button>`;
}
function meCode(){
  const v=($('#mec-code').value||'').replace(/\\D/g,'');
  $$('#sh-body .field').forEach(f=>f.classList.remove('err'));
  if(v!=='4815')return fErr('#mec-code','Неверный код. В демо это 4815');
  st.name=ME.n;st.phone=ME.p;st.email=ME.e;ME=null;
  closeSheet();renderAll();toast('Номер подтверждён — данные сохранены');
}
/* --- адреса --- */""")

rep("""  'me-save':()=>meSave(),""",
    """  'me-save':()=>meSave(),
  'mec-go':()=>meCode(),""")
rep("PART=null;FAIL=null;LK=null;DSP=null;FAMD=null;ADR=null;renderOff();",
    "PART=null;FAIL=null;LK=null;DSP=null;FAMD=null;ADR=null;ME=null;renderOff();")

PAIRS=[('Подтвердите номер','Номерди ырастаңыз'),
 ('Код из SMS','SMS'+"'"+'теги код'),
 ('В демо код всегда 4815','Демодо код ар дайым 4815'),
 ('Подтвердить номер','Номерди ырастоо'),
 ('Изменить номер','Номерди өзгөртүү'),
 ('Неверный код. В демо это 4815','Код туура эмес. Демодо бул 4815'),
 ('Номер подтверждён — данные сохранены','Номер ырасталды — маалымат сакталды'),
 ('4 цифры','4 сан')]
i=s.find('const KY='); j=s.find(';\n',i)
KY=json.loads(s[i+len('const KY='):j]); a=0
for ru,ky in PAIRS:
    if ru not in KY: KY[ru]=ky; a+=1
s=s[:i+len('const KY=')]+json.dumps(KY,ensure_ascii=False,separators=(',',':'))+s[j:]
io.open(P,'w',encoding='utf-8').write(s); print('ok, ky added:',a)
