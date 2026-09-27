# -*- coding: utf-8 -*-
"""Аудит D6: тёмная тема приложения (системная, светлая, тёмная)."""
import io, json
P='index.html'; s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old); assert n==cnt,'expected %d, found %d: %r'%(cnt,n,old[:110]); s=s.replace(old,new)

CSS = """
/* ===== Тёмная тема приложения ===== */
.app.dark{
  --gr:#F2F5F4; --gr2:#E4EAE8; --gr3:#C2D0CB; --ink:#F2F5F4; --muted:#9FB0AA; --muted2:#7F918B;
  --line:rgba(222,243,236,.16); --line2:rgba(222,243,236,.10); --bg:#1B252B; --soft:#141D22; --soft2:#182228;
  --light:rgba(31,184,134,.20); --light2:rgba(31,184,134,.13); --p600:#2FCB99; --p700:#46DBAB; --onp:#04332B;
  --sh-sm:0 1px 2px rgba(0,0,0,.45); --sh:0 6px 18px rgba(0,0,0,.4); --sh-lg:0 14px 36px rgba(0,0,0,.55);
  background:var(--soft);
}
.app.dark .statusbar{color:var(--ink)}
.app.dark .homebar{background:var(--ink)}
.app.dark .scr.white{--sbg:var(--bg)}
.app.dark .scr{--fade:rgba(20,29,34,.94)}
.app.dark .scr.white{--fade:rgba(27,37,43,.94)}
.app.dark #s-home{--fade:rgba(18,32,29,.94)}
.app.dark #s-home .body{background:linear-gradient(180deg,rgba(31,184,134,.16) 0,rgba(20,29,34,0) 340px) local no-repeat}
.app.dark .hero{background:linear-gradient(155deg,#0E171C,#132229)}
.app.dark .wtotal{background:radial-gradient(120% 90% at 100% 0%,rgba(31,184,134,.3),transparent 55%),#0E171C}
.app.dark .sync-ic,.app.dark .cardart{background:#0E171C}
.app.dark .toast{background:#0B1114;color:#F2F5F4}
.app.dark .qa.on,.app.dark .hfil button.on{background:var(--primary);border-color:var(--primary);color:#04332B}
.app.dark .tabbar{background:rgba(20,29,34,.94)}
.app.dark .push{background:rgba(27,37,43,.9)}
.app.dark .fid-box{background:rgba(27,37,43,.96)}
.app.dark .seg .knob,.app.dark .key,.app.dark .wcard,.app.dark .tl-dot,.app.dark .pc{background:var(--bg)}
.app.dark .keypad{background:var(--soft2);border-top-color:var(--line2)}
.app.dark .bdg,.app.dark .dotb{border-color:var(--soft)}
.app.dark .strip{background:rgba(63,123,224,.16);color:#AFCBF7}
.app.dark .strip .mid span{color:#8FB4F2}
.app.dark .strip .tile{background:linear-gradient(135deg,#4C86D8,#3767BE)}
.app.dark .tip{background:rgba(63,123,224,.16);color:#AFCBF7}
.app.dark .tip.ok{background:rgba(31,184,134,.16);color:#6FE0BB}
.app.dark .tip.warn,.app.dark .dsp-st{background:rgba(224,169,63,.16);color:#F0CE86}
.app.dark .chip.soft{background:rgba(222,243,236,.10);color:var(--gr3)}
.app.dark .chip.ok{background:rgba(31,184,134,.18);color:#6FE0BB}
.app.dark .chip.warn,.app.dark .chip.due{background:rgba(224,169,63,.18);color:#F0CE86}
.app.dark .chip.bad{background:rgba(224,83,63,.20);color:#F3A797}
.app.dark .chip.info{background:rgba(63,123,224,.20);color:#AFCBF7}
.app.dark .failring{background:rgba(224,83,63,.18)}
.app.dark .tile,.app.dark .tile.soft{background:rgba(222,243,236,.10);color:var(--gr3)}
.app.dark .tile.lt{background:rgba(31,184,134,.16);color:#6FE0BB}
.app.dark .tile.soft.c-water{background:rgba(63,123,224,.20);color:#AFCBF7}
.app.dark .tile.soft.c-power{background:rgba(224,169,63,.20);color:#F0CE86}
.app.dark .tile.soft.c-trash{background:rgba(240,100,63,.20);color:#F7B098}
.app.dark .tile.soft.c-kid{background:rgba(224,66,141,.20);color:#F6A7CC}
.app.dark .tile.soft.c-school{background:rgba(107,85,236,.22);color:#BDB1F7}
.app.dark .tile.soft.c-gas{background:rgba(224,122,95,.20);color:#F3B3A0}
.app.dark .tile.soft.c-net{background:rgba(107,126,224,.20);color:#B3BDF4}
.app.dark .tile.soft.c-door{background:rgba(122,138,168,.22);color:#BCC8DC}
.app.dark .tile.soft.c-course{background:rgba(155,81,224,.20);color:#D3B0F4}
.app.dark .tile.soft.c-tax{background:rgba(222,243,236,.10);color:var(--gr3)}
.app.dark .tile.soft.c-market{background:rgba(42,163,199,.22);color:#9BDCEF}
.app.dark .tile.dash{border-color:var(--muted2);color:#6FE0BB}
.app.dark .bc .b{background:rgba(222,243,236,.14)}
.app.dark .map rect[fill="#EEF1EF"],.app.dark .map rect[fill="#FFFFFF"]{opacity:.85}
.app.dark .gate{background:#F7FAF9;color:#1E2A32}
.app.dark .gate h3{color:#1E2A32}
.app.dark .gate p{color:#6B7772}
.app.dark .gate .btn-s{background:#EEF1EF;color:#1E2A32}
.app.dark .okring{background:rgba(31,184,134,.18)}
.app.dark .rq mark{background:rgba(31,184,134,.2);color:#6FE0BB}
.app.dark .cardart.elc{background:#2A3942}
.app.dark .pf-ed,.app.dark .x{background:rgba(222,243,236,.10)}
.app.dark .picker button{background:rgba(222,243,236,.10)}
.app.dark .evt,.app.dark .tkt,.app.dark .group,.app.dark .rep-card,.app.dark .exp,.app.dark .al,.app.dark .al-status,.app.dark .kid,.app.dark .pf,.app.dark .tp-hero,.app.dark .mk-hd{border:1px solid var(--line2)}
.app.dark .tp-hero.c-kid{background:linear-gradient(160deg,rgba(224,66,141,.20) 0,var(--bg) 62%)}
.app.dark .tp-hero.c-school{background:linear-gradient(160deg,rgba(107,85,236,.22) 0,var(--bg) 62%)}
.app.dark .tkt-cut::before,.app.dark .tkt-cut::after{background:var(--soft)}
.app.dark .tkt-qr{background:#fff}
"""
END = '.big-sum small{font-size:18px;font-weight:600;color:var(--muted)}\n</style>'
rep(END, '.big-sum small{font-size:18px;font-weight:600;color:var(--muted)}' + CSS + '</style>')

rep("qh:['22:00','08:00']","qh:['22:00','08:00'],theme:'sys'")

# строка «Тема» в профиле
rep("""                <button class="row" data-act="tariffs">""",
    """                <button class="row" data-act="theme"><span class="tile"><i data-i="moon"></i></span><span class="mid"><span class="t">Тема</span><span class="s">Светлая, тёмная или как в телефоне</span></span><span class="val" id="pf-theme">Системная</span><i data-i="chevron-right" data-s="18"></i></button>
                <button class="row" data-act="tariffs">""")

rep("renderObjs();renderChat();renderMarket();renderTickets();renderOff();renderLock();renderPfBills();",
    "renderObjs();renderChat();renderMarket();renderTickets();renderOff();renderLock();renderPfBills();applyTheme();")

JS = r"""/* ===== Тёмная тема ===== */
const THEMES=[['sys','Системная','Как в настройках телефона'],['light','Светлая','Всегда светлые экраны'],['dark','Тёмная','Всегда тёмные экраны']];
function applyTheme(){
  const t=st.theme||'sys';
  const dark=t==='dark'||(t==='sys'&&matchMedia('(prefers-color-scheme: dark)').matches);
  app.classList.toggle('dark',dark);
  const el=$('#pf-theme');if(el)el.textContent=tx((THEMES.find(x=>x[0]===t)||THEMES[0])[1]);
}
function themeSheet(){
  openSheet(tx('Тема'),`<p class="sub">Тёмная тема бережёт батарею на OLED-экранах и не слепит вечером.</p>
   <div class="group wrap" style="margin-top:14px">${THEMES.map(([k,t2,s2])=>`<button class="row" data-act="theme-set" data-k="${k}">${tl(k==='dark'?'city':k==='light':'power','moon')}<span class="mid"><span class="t">${t2}</span><span class="s">${s2}</span></span>${(st.theme||'sys')===k?`<span class="chip ok sm">${ic('check',12,3)}Выбрано</span>`:''}</button>`).join('')}</div>`,'th');
}
const THACT={
  theme:()=>themeSheet(),
  'theme-set':t=>{st.theme=t.dataset.k;applyTheme();setBody(themeSheet2());renderAll();toast(F.themeSet(tx((THEMES.find(x=>x[0]===st.theme)||THEMES[0])[1])));}
};

"""
rep("/* ===== Новые действия ===== */", JS + "/* ===== Новые действия ===== */")
rep("Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT,CRUDACT,PAYACT,CACT,DACT);",
    "Object.assign(ACT2,MKACT,OFFACT,PINACT,FAMACT,HISTACT,TARACT,CRUDACT,PAYACT,CACT,DACT,THACT);")
rep("addEventListener('resize',()=>{hLayout('heroes');hLayout('rep-heroes');});",
    "addEventListener('resize',()=>{hLayout('heroes');hLayout('rep-heroes');});\nmatchMedia('(prefers-color-scheme: dark)').addEventListener('change',applyTheme);")

PAIRS=[('Тема','Тема'),('Светлая, тёмная или как в телефоне','Жарык, караңгы же телефондогудай'),
 ('Системная','Системалык'),('Как в настройках телефона','Телефондун жөндөөлөрүндөгүдөй'),
 ('Светлая','Жарык'),('Всегда светлые экраны','Ар дайым жарык экрандар'),
 ('Тёмная','Караңгы'),('Всегда тёмные экраны','Ар дайым караңгы экрандар'),
 ('Тёмная тема бережёт батарею на OLED-экранах и не слепит вечером.','Караңгы тема OLED экранда батареяны үнөмдөйт жана кечинде көздү чарчатпайт.'),
 ('Выбрано','Тандалды')]
i=s.find('const KY='); j=s.find(';\n',i)
KY=json.loads(s[i+len('const KY='):j]); a=0
for ru,ky in PAIRS:
    if ru not in KY: KY[ru]=ky; a+=1
s=s[:i+len('const KY=')]+json.dumps(KY,ensure_ascii=False,separators=(',',':'))+s[j:]
io.open(P,'w',encoding='utf-8').write(s); print('ok, ky added:',a)
