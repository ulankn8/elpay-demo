# -*- coding: utf-8 -*-
"""v3.0: карусель на pointer-событиях вместо нативной прокрутки — работает и пальцем, и мышью."""
import io
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:90]!r}'
    s=s.replace(old,new)

# ---------- стили ----------
rep(""".heroes{display:flex;gap:12px;overflow-x:auto;scroll-snap-type:x mandatory;scrollbar-width:none;-webkit-overflow-scrolling:touch;margin:0 -20px;padding:2px 20px}
.heroes::-webkit-scrollbar{display:none}
.heroes .hero{flex:0 0 calc(100% - 34px);scroll-snap-align:center;background:radial-gradient(120% 90% at 100% 0%,rgba(255,255,255,.10),transparent 55%),var(--cardbg,var(--gr))}
.heroes .hero:last-child{margin-right:0}""",
""".heroes{position:relative;overflow:hidden;margin:0 -20px;padding:2px 0;cursor:grab}
.heroes:active{cursor:grabbing}
.htrack{display:flex;gap:12px;padding:0 20px;touch-action:pan-y;will-change:transform;transition:transform .34s cubic-bezier(.22,.8,.24,1)}
.htrack.drag{transition:none}
.heroes .hero{flex:0 0 auto;background:radial-gradient(120% 90% at 100% 0%,rgba(255,255,255,.10),transparent 55%),var(--cardbg,var(--gr))}""")

# ---------- разметка ----------
rep('<div class="heroes rv" style="--d:2" id="heroes"></div>',
    '<div class="heroes rv" style="--d:2" id="heroes"><div class="htrack" id="heroes-t"></div></div>')
rep('<div class="heroes rv" style="--d:1" id="rep-heroes"></div>',
    '<div class="heroes rv" style="--d:1" id="rep-heroes"><div class="htrack" id="rep-heroes-t"></div></div>')

# ---------- механика ----------
rep("function renderDots(){",
"""const HI={heroes:0,'rep-heroes':0};
function hSlide(id,i,anim){
  const el=$('#'+id),tr=$('#'+id+'-t');if(!el||!tr)return;
  const n=tr.children.length;if(!n)return;
  i=Math.max(0,Math.min(n-1,i));HI[id]=i;
  const w=tr.children[0].offsetWidth+12;
  tr.classList.toggle('drag',!anim);
  tr.style.transform='translateX('+(-i*w)+'px)';
  if(!anim)requestAnimationFrame(()=>tr.classList.remove('drag'));
  hDots(id);
}
function hLayout(id){
  const el=$('#'+id),tr=$('#'+id+'-t');if(!el||!tr||!tr.children.length)return;
  const w=Math.max(200,el.clientWidth-40-34);
  [...tr.children].forEach(c=>c.style.width=w+'px');
  hSlide(id,HI[id],false);
}
function hDots(id){
  const tr=$('#'+id+'-t'),d=$('#'+(id==='heroes'?'h-dots':'rep-dots'));if(!tr||!d)return;
  const n=tr.children.length,i=HI[id];
  d.innerHTML=[...Array(n)].map((_,k)=>`<button class="${k===i?'on':''}" data-act="hero-dot" data-h="${id}" data-i="${k}" aria-label="${k+1}"></button>`).join('');
  if(id==='rep-heroes'){const o=i===0?null:st.obj[i-1],nid=o?o.id:null;if(nid!==st.repObj){st.repObj=nid;repBody();}}
}
function hInit(id){
  const el=$('#'+id),tr=$('#'+id+'-t');if(!el||!tr)return;
  let down=false,sx=0,sy=0,base=0,moved=false,lock=null;
  el.addEventListener('pointerdown',e=>{
    if(e.target.closest('button:not(.hero)'))return;
    down=true;moved=false;lock=null;sx=e.clientX;sy=e.clientY;
    const w=tr.children[0]?tr.children[0].offsetWidth+12:1;base=-HI[id]*w;
    tr.classList.add('drag');
  });
  el.addEventListener('pointermove',e=>{
    if(!down)return;
    const dx=e.clientX-sx,dy=e.clientY-sy;
    if(lock===null){if(Math.abs(dx)<6&&Math.abs(dy)<6)return;lock=Math.abs(dx)>Math.abs(dy)?'x':'y';}
    if(lock!=='x'){down=false;tr.classList.remove('drag');return;}
    moved=true;HSCR=Date.now();
    tr.style.transform='translateX('+(base+dx)+'px)';
  });
  const up=e=>{
    if(!down)return;down=false;
    const dx=(e&&e.clientX!=null?e.clientX:sx)-sx,w=tr.children[0]?tr.children[0].offsetWidth+12:1;
    let i=HI[id];
    if(moved)i=Math.abs(dx)>w*0.22?i+(dx<0?1:-1):i;
    hSlide(id,i,true);
    if(moved)HSCR=Date.now();
  };
  el.addEventListener('pointerup',up);el.addEventListener('pointercancel',up);el.addEventListener('pointerleave',up);
  el.addEventListener('click',e=>{if(moved){e.stopPropagation();e.preventDefault();moved=false;}},true);
}
function renderDots(){""")
rep("""function renderDots(){
  const el=$('#heroes'),d=$('#h-dots');if(!el||!d)return;
  const n=el.children.length,w=el.children[0]?el.children[0].offsetWidth+12:1;
  const i=Math.min(n-1,Math.round(el.scrollLeft/w));
  d.innerHTML=[...Array(n)].map((_,k)=>`<button class="${k===i?'on':''}" data-act="hero-dot" data-h="heroes" data-i="${k}" aria-label="${k+1}"></button>`).join('');
}""","function renderDots(){hDots('heroes');}")
rep("""  const el=$('#heroes'),keep=el?el.scrollLeft:0;
  el.innerHTML=st.obj.map((o,i)=>heroCard(o,i===0)).join('')
   +`<button class="hero add" data-act="obj-new"><span class="okc">${ic('circle-plus',26,2.2)}</span><b>Новый объект</b><span>Квартира, дача или офис — со своими счетами</span></button>`;
  el.scrollLeft=keep;
  renderDots();""",
"""  const tr=$('#heroes-t');
  tr.innerHTML=st.obj.map((o,i)=>heroCard(o,i===0)).join('')
   +`<button class="hero add" data-act="obj-new"><span class="okc">${ic('circle-plus',26,2.2)}</span><b>Новый объект</b><span>Квартира, дача или офис — со своими счетами</span></button>`;
  hLayout('heroes');""")
rep("""  const h=$('#rep-heroes');
  if(h){const keep=h.scrollLeft;h.innerHTML=[null,...st.obj].map(repCard).join('');h.scrollLeft=keep;
    const n=h.children.length,w=h.children[0]?h.children[0].offsetWidth+12:1;
    const i=Math.min(n-1,Math.round(keep/w));st.repObj=i===0?null:(st.obj[i-1]||{}).id||null;
    const d=$('#rep-dots');if(d)d.innerHTML=[...Array(n)].map((_,k)=>`<button class="${k===i?'on':''}" data-act="hero-dot" data-h="rep-heroes" data-i="${k}" aria-label="${k+1}"></button>`).join('');
    if(ky())trTree(h);}
  repBody();""",
"""  const tr=$('#rep-heroes-t');
  if(tr){tr.innerHTML=[null,...st.obj].map(repCard).join('');hLayout('rep-heroes');if(ky())trTree(tr);}
  repBody();""")
rep("""function renderRepDots(){
  const el=$('#rep-heroes'),d=$('#rep-dots');if(!el||!d)return;
  const n=el.children.length,w=el.children[0]?el.children[0].offsetWidth+12:1;
  const i=Math.min(n-1,Math.round(el.scrollLeft/w));
  d.innerHTML=[...Array(n)].map((_,k)=>`<button class="${k===i?'on':''}" data-act="hero-dot" data-h="rep-heroes" data-i="${k}" aria-label="${k+1}"></button>`).join('');
  const o=i===0?null:st.obj[i-1];
  const nid=o?o.id:null;
  if(nid!==st.repObj){st.repObj=nid;repBody();}
}
""","")
rep("  'hero-dot':t=>{const h=$('#'+t.dataset.h);if(!h)return;const w=h.children[0].offsetWidth+12;h.scrollTo({left:(+t.dataset.i)*w,behavior:'smooth'});},",
    "  'hero-dot':t=>hSlide(t.dataset.h,+t.dataset.i,true),")

# инициализация вместо старых слушателей прокрутки
old_init=s[s.find("function dragScroll(el){"):s.find("$('#in-otp').addEventListener('input',paintOtp);")]
s=s.replace(old_init,"hInit('heroes');hInit('rep-heroes');\naddEventListener('resize',()=>{hLayout('heroes');hLayout('rep-heroes');});\n")
io.open(P,'w',encoding='utf-8').write(s)
print('p12 ok')
