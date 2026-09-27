# -*- coding: utf-8 -*-
"""ЭлPay v3.2 — код-пароль, вход по Face ID, экран блокировки."""
import io, json

P = 'index.html'
s = io.open(P, encoding='utf-8').read()


def rep(old, new, cnt=1):
    global s
    n = s.count(old)
    assert n == cnt, 'expected %d, found %d: %r' % (cnt, n, old[:110])
    s = s.replace(old, new)


CSS = """
/* ===== Код-пароль и блокировка ===== */
.app.off .scr:not(.splash):not(.welcome) .body{padding-top:calc(var(--sat) + 54px)}
.lock-top{display:flex;flex-direction:column;align-items:center;gap:6px;margin-top:8px}
.ava.lg{width:66px;height:66px;font-size:23px;margin-bottom:8px}
.lock-top h1{font-size:22px;font-weight:700;letter-spacing:-.02em}
.lock-top p{font-size:14px;color:var(--muted)}
.otp.lk{margin-top:26px}
.otp.lk .c{height:64px}
.lk-alt{display:flex;justify-content:center;margin-top:20px}
.lk-alt button{display:flex;align-items:center;gap:8px;height:40px;padding:0 16px;border-radius:999px;background:var(--light2);color:var(--p700);font-size:13.5px;font-weight:700}
.pinrow{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-top:14px;padding:12px 14px;border-radius:16px;background:var(--soft)}
.pinrow span{font-size:14px;font-weight:600}
"""
rep('</style>', CSS + '</style>')

# ---- экран блокировки ----
rep('''          <!-- 22. Маркет: афиша города -->''',
    '''          <!-- 24. Блокировка: код-пароль -->
          <section class="scr white" id="s-lock">
            <div class="body">
              <div class="otp-wrap">
                <div class="lock-top"><span class="ava lg" id="lk-ava">АТ</span><h1 id="lk-name">Айгерим</h1><p>Введите код-пароль</p></div>
                <div class="otp lk" id="lk-dots"><span class="c"></span><span class="c"></span><span class="c"></span><span class="c"></span></div>
                <p class="otp-state c" id="lk-state"></p>
                <div class="lk-alt" id="lk-alt"></div>
              </div>
            </div>
            <div class="keypad" aria-label="Цифровая клавиатура"><button class="key" data-act="lkey" data-k="1">1</button><button class="key" data-act="lkey" data-k="2">2</button><button class="key" data-act="lkey" data-k="3">3</button><button class="key" data-act="lkey" data-k="4">4</button><button class="key" data-act="lkey" data-k="5">5</button><button class="key" data-act="lkey" data-k="6">6</button><button class="key" data-act="lkey" data-k="7">7</button><button class="key" data-act="lkey" data-k="8">8</button><button class="key" data-act="lkey" data-k="9">9</button><button class="key fn" data-act="lkey" data-k="face" aria-label="Войти по Face ID"><i data-i="scan-face" data-s="22"></i></button><button class="key" data-act="lkey" data-k="0">0</button><button class="key fn" data-act="lkey" data-k="del" aria-label="Стереть цифру"><i data-i="delete" data-s="22"></i></button></div>
          </section>

          <!-- 22. Маркет: афиша города -->''')

# ---- состояние ----
rep("  hist:[],histQ:'',tickets:[],mkF:'all',part:{},queue:[],qd:{},offline:0,failOnce:0});",
    "  hist:[],histQ:'',tickets:[],mkF:'all',part:{},queue:[],qd:{},offline:0,failOnce:0,pinOn:0,bioOn:1,pin:'4815',qh:['22:00','08:00']});")

# ---- чек-лист на главной ----
rep("""   {ok:!!st.pushOk,t:'Включить уведомления об отключениях',act:'toast',id:'',msg:'Уведомления об отключениях включены'}];""",
    """   {ok:!!st.pushOk,t:'Включить уведомления об отключениях',act:'toast',id:'',msg:'Уведомления об отключениях включены'},
   {ok:!!st.pinOn,t:'Поставить код-пароль на вход',act:'pin-setup',id:''}];""")

# ---- профиль: безопасность ----
rep("""   +`<div class="row"><span class="tile">${ic('scan-face')}</span><span class="mid"><span class="t">Face ID</span><span class="s">Вход и подтверждение платежей</span></span><button class="sw" role="switch" aria-checked="true" aria-label="Face ID" data-act="sw"></button></div>`""",
    """   +`<div class="row"><span class="tile">${ic('lock')}</span><span class="mid"><span class="t">Код-пароль</span><span class="s">${st.pinOn?tx('Включён · 4 цифры'):tx('Выключен — вход без кода')}</span></span><button class="sw" role="switch" aria-checked="${!!st.pinOn}" aria-label="Код-пароль" data-act="pin-sw"></button></div>`
   +`<div class="row"><span class="tile">${ic('scan-face')}</span><span class="mid"><span class="t">Face ID</span><span class="s">Вход и подтверждение платежей</span></span><button class="sw" role="switch" aria-checked="${!!st.bioOn}" aria-label="Face ID" data-act="bio-sw"></button></div>`
   +`<button class="row" data-act="lock-now"><span class="tile">${ic('shield-check')}</span><span class="mid"><span class="t">Заблокировать приложение</span><span class="s">Посмотреть, как выглядит вход</span></span>${ic('chevron-right',18)}</button>`""")

# ---- сценарий в панели питча ----
rep("""      <li><button class="scn" data-scn="9"><span class="n">9</span>Нет сети: платёж в очереди<i class="go" data-i="arrow-right" data-s="18"></i></button></li>""",
    """      <li><button class="scn" data-scn="9"><span class="n">9</span>Нет сети: платёж в очереди<i class="go" data-i="arrow-right" data-s="18"></i></button></li>
      <li><button class="scn" data-scn="10"><span class="n">10</span>Вход по коду и Face ID<i class="go" data-i="arrow-right" data-s="18"></i></button></li>""")

rep("""  if(n===8){st.paid={};""",
    """  if(n===10){if(!st.pinOn){st.pinOn=1;st.bioOn=1;renderAll();}lockApp();return;}
  if(n===8){st.paid={};""")

rep("const SCN={auth:1,otp:1,setup:1,services:1,accounts:1,sync:1,home:2,pay:2,cat:2,success:2,tpl:3,alerts:4,reports:5,profile:6,req:6,market:7,tickets:7};",
    "const SCN={auth:1,otp:1,setup:1,services:1,accounts:1,sync:1,home:2,pay:2,cat:2,success:2,tpl:3,alerts:4,reports:5,profile:6,req:6,market:7,tickets:7,lock:10};")

rep("renderObjs();renderChat();renderMarket();renderTickets();renderOff();if(st.cat)renderCat();",
    "renderObjs();renderChat();renderMarket();renderTickets();renderOff();renderLock();if(st.cat)renderCat();")

# офлайн-полоса сдвигает контент
rep("""  el.classList.toggle('on',!!st.offline);""",
    """  el.classList.toggle('on',!!st.offline);app.classList.toggle('off',!!st.offline);""")

JS = r"""/* ===== Код-пароль, Face ID и экран блокировки ===== */
let LK=null;
function renderLock(){
  const el=$('#lk-dots');if(!el)return;
  const v=LK?LK.v:'';
  $('#lk-ava').textContent=initials(st.name);
  $('#lk-name').textContent=firstName(st.name);
  [...el.children].forEach((c,i)=>{c.classList.toggle('fill',!!v[i]);c.textContent=v[i]?'•':'';c.classList.toggle('cur',v.length<4&&i===v.length);});
  const alt=$('#lk-alt');
  if(alt)alt.innerHTML=st.bioOn?`<button data-act="lkey" data-k="face">${ic('scan-face',18)}Войти по Face ID</button>`:'';
  if(ky())trTree($('#s-lock'));
}
async function faceRun(title){
  const f=$('#fid');$('#fid-ic').innerHTML=ic('scan-face',56,1.6);$('#fid-t').textContent=tx(title||'Face ID');
  f.classList.remove('done');f.classList.add('on');
  await wait(1000);
  f.classList.add('done');$('#fid-ic').innerHTML=ic('circle-check',56,1.6);$('#fid-t').textContent=tx('Подтверждено');
  await wait(600);f.classList.remove('on');
}
function lockApp(){
  if(!st.reg){toast('Сначала пройдите регистрацию');return;}
  closeSheet();hidePush();closeGate();
  LK={v:'',back:TABS.includes(cur)?cur:st.tab,tries:0};
  renderLock();$('#lk-state').textContent='';
  go('lock','fade');
  if(st.bioOn)setTimeout(()=>{if(cur==='lock')bioUnlock();},700);
}
async function bioUnlock(){
  if(!LK||LK.busy)return;LK.busy=1;
  await faceRun('Face ID');
  if(cur!=='lock'){LK.busy=0;return;}
  unlock();
}
function unlock(){
  const back=LK&&LK.back?LK.back:'home';LK=null;
  go(back,'fade');toast('Добро пожаловать');
}
function lkKey(k){
  if(!LK||LK.busy)return;
  if(k==='face')return st.bioOn?bioUnlock():toast('Face ID выключен в настройках');
  let v=LK.v;
  if(k==='del')v=v.slice(0,-1);else if(v.length<4)v+=k;
  LK.v=v;renderLock();
  if(v.length<4)return;
  setTimeout(()=>{
    if(!LK)return;
    if(LK.v===st.pin){$('#lk-state').innerHTML=`<span class="okdot">${ic('check',14,3)}</span>${tx('Код верный')}`;setTimeout(unlock,320);}
    else{
      LK.v='';LK.tries++;renderLock();
      const d=$('#lk-dots');d.classList.add('err');setTimeout(()=>d.classList.remove('err'),600);
      $('#lk-state').innerHTML='<span style="color:#B23A3A">'+tx(LK.tries>=2?'Код неверный. В демо это 4815':'Код неверный. Попробуйте ещё раз')+'</span>';
    }
  },180);
}
function pinSetup(){
  openSheet(tx('Код-пароль'),`<p class="sub">Код защищает приложение и подтверждает платежи, если Face ID недоступен.</p>
   <div class="field" style="margin-top:14px"><label for="pin-a">Новый код — 4 цифры</label><div class="inp"><input id="pin-a" inputmode="numeric" maxlength="4" type="password" placeholder="••••"></div></div>
   <div class="field"><label for="pin-b">Повторите код</label><div class="inp"><input id="pin-b" inputmode="numeric" maxlength="4" type="password" placeholder="••••"></div></div>
   <div class="pinrow"><span>Вход по Face ID</span><button class="sw" role="switch" aria-checked="${!!st.bioOn}" aria-label="Вход по Face ID" data-act="bio-sw"></button></div>
   <button class="btn btn-p" style="margin-top:16px" data-act="pin-save">${ic('shield-check',20)}Включить код-пароль</button>
   <p class="legal center">${ic('lock',14)}В демо код можно оставить 4815 — он же приходит в SMS</p>`,'pin');
}
function pinSave(){
  const a=($('#pin-a').value||'').replace(/\D/g,''),b=($('#pin-b').value||'').replace(/\D/g,'');
  $$('#sh-body .field').forEach(f=>f.classList.remove('err'));
  if(a.length!==4)return fErr('#pin-a','Код состоит из 4 цифр');
  if(a!==b)return fErr('#pin-b','Коды не совпадают');
  st.pin=a;st.pinOn=1;closeSheet();renderAll();toast('Код-пароль включён');
}
const PINACT={
  lkey:t=>lkKey(t.dataset.k),
  'lock-now':()=>lockApp(),
  'pin-setup':()=>pinSetup(),
  'pin-save':()=>pinSave(),
  'pin-sw':t=>{
    if(st.pinOn){st.pinOn=0;t.setAttribute('aria-checked','false');renderAll();return toast('Код-пароль выключен');}
    t.setAttribute('aria-checked','false');pinSetup();
  },
  'bio-sw':t=>{st.bioOn=st.bioOn?0:1;t.setAttribute('aria-checked',String(!!st.bioOn));renderAll();toast(st.bioOn?'Face ID включён':'Face ID выключен');}
};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("Object.assign(ACT2,MKACT,OFFACT);", "Object.assign(ACT2,MKACT,OFFACT,PINACT);")
rep("""  clearInterval(otpI);verifying=false;$('#in-search').value='';clearTimeout(NETT);PART=null;FAIL=null;renderOff();""",
    """  clearInterval(otpI);verifying=false;$('#in-search').value='';clearTimeout(NETT);PART=null;FAIL=null;LK=null;renderOff();""")

PAIRS = [
 ('Введите код-пароль', 'Код-сырсөздү киргизиңиз'),
 ('Войти по Face ID', 'Face ID менен кирүү'),
 ('Код верный', 'Код туура'),
 ('Код неверный. Попробуйте ещё раз', 'Код туура эмес. Кайра аракет кылыңыз'),
 ('Код неверный. В демо это 4815', 'Код туура эмес. Демодо бул 4815'),
 ('Добро пожаловать', 'Кош келиңиз'),
 ('Код-пароль', 'Код-сырсөз'),
 ('Включён · 4 цифры', 'Күйгүзүлгөн · 4 сан'),
 ('Выключен — вход без кода', 'Өчүрүлгөн — кодсуз кирүү'),
 ('Заблокировать приложение', 'Тиркемени кулпулоо'),
 ('Посмотреть, как выглядит вход', 'Кирүү кандай көрүнөрүн кароо'),
 ('Поставить код-пароль на вход', 'Кирүүгө код-сырсөз коюу'),
 ('Код защищает приложение и подтверждает платежи, если Face ID недоступен.',
  'Код тиркемени коргойт жана Face ID жеткиликсиз болсо төлөмдөрдү ырастайт.'),
 ('Новый код — 4 цифры', 'Жаңы код — 4 сан'),
 ('Повторите код', 'Кодду кайталаңыз'),
 ('Вход по Face ID', 'Face ID менен кирүү'),
 ('Включить код-пароль', 'Код-сырсөздү күйгүзүү'),
 ('В демо код можно оставить 4815 — он же приходит в SMS', 'Демодо кодду 4815 калтырса болот — ал SMS менен келет'),
 ('Код состоит из 4 цифр', 'Код 4 сандан турат'),
 ('Коды не совпадают', 'Коддор дал келбейт'),
 ('Код-пароль включён', 'Код-сырсөз күйгүзүлдү'),
 ('Код-пароль выключен', 'Код-сырсөз өчүрүлдү'),
 ('Face ID включён', 'Face ID күйгүзүлдү'),
 ('Face ID выключен', 'Face ID өчүрүлдү'),
 ('Face ID выключен в настройках', 'Face ID жөндөөлөрдө өчүрүлгөн'),
 ('Сначала пройдите регистрацию', 'Адегенде катталып өтүңүз'),
 ('Вход по коду и Face ID', 'Код жана Face ID менен кирүү'),
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
