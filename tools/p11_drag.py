# -*- coding: utf-8 -*-
"""v3.0: перетаскивание карусели мышью + кликабельные точки."""
import io
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:90]!r}'
    s=s.replace(old,new)

rep(".dots i{width:6px;height:6px;border-radius:50%;background:var(--line);transition:width .25s,background-color .25s}\n.dots i.on{width:20px;background:var(--primary)}",
    ".dots i,.dots button{width:6px;height:6px;padding:0;border:0;border-radius:50%;background:var(--line);transition:width .25s,background-color .25s}\n.dots i.on,.dots button.on{width:20px;background:var(--primary)}\n.heroes.grab{scroll-snap-type:none;cursor:grab}\n.heroes.grab .hero{cursor:grab}")

# точки — кнопки
rep("d.innerHTML=[...Array(n)].map((_,k)=>`<i class=\"${k===i?'on':''}\"></i>`).join('');\n  const o=i===0?null:st.obj[i-1];",
    "d.innerHTML=[...Array(n)].map((_,k)=>`<button class=\"${k===i?'on':''}\" data-act=\"hero-dot\" data-h=\"rep-heroes\" data-i=\"${k}\" aria-label=\"${k+1}\"></button>`).join('');\n  const o=i===0?null:st.obj[i-1];")
rep("  d.innerHTML=[...Array(n)].map((_,k)=>`<i class=\"${k===i?'on':''}\"></i>`).join('');\n}\nfunction renderHome(from){",
    "  d.innerHTML=[...Array(n)].map((_,k)=>`<button class=\"${k===i?'on':''}\" data-act=\"hero-dot\" data-h=\"heroes\" data-i=\"${k}\" aria-label=\"${k+1}\"></button>`).join('');\n}\nfunction renderHome(from){")
rep("const d=$('#rep-dots');if(d)d.innerHTML=[...Array(n)].map((_,k)=>`<i class=\"${k===i?'on':''}\"></i>`).join('');",
    "const d=$('#rep-dots');if(d)d.innerHTML=[...Array(n)].map((_,k)=>`<button class=\"${k===i?'on':''}\" data-act=\"hero-dot\" data-h=\"rep-heroes\" data-i=\"${k}\" aria-label=\"${k+1}\"></button>`).join('');")

# действие точки
rep("  'obj-bills':t=>{","  'hero-dot':t=>{const h=$('#'+t.dataset.h);if(!h)return;const w=h.children[0].offsetWidth+12;h.scrollTo({left:(+t.dataset.i)*w,behavior:'smooth'});},\n  'obj-bills':t=>{")

# перетаскивание мышью
rep("(()=>{const h=$('#heroes');if(h){",
"""function dragScroll(el){
  if(!el)return;
  let down=false,sx=0,sl=0,moved=false;
  const snap=()=>{const w=el.children[0]?el.children[0].offsetWidth+12:1;const i=Math.max(0,Math.min(el.children.length-1,Math.round(el.scrollLeft/w)));el.classList.remove('grab');el.scrollTo({left:i*w,behavior:'smooth'});};
  el.addEventListener('pointerdown',e=>{
    if(e.pointerType==='touch')return;
    down=true;moved=false;sx=e.clientX;sl=el.scrollLeft;el.classList.add('grab');
  });
  el.addEventListener('pointermove',e=>{
    if(!down)return;const d=e.clientX-sx;
    if(Math.abs(d)>4){moved=true;HSCR=Date.now();}
    el.scrollLeft=sl-d;
  });
  const up=()=>{if(!down)return;down=false;if(moved)HSCR=Date.now();snap();};
  el.addEventListener('pointerup',up);el.addEventListener('pointercancel',up);el.addEventListener('pointerleave',up);
  el.addEventListener('click',e=>{if(moved){e.stopPropagation();e.preventDefault();moved=false;}},true);
}
dragScroll($('#heroes'));dragScroll($('#rep-heroes'));
(()=>{const h=$('#heroes');if(h){""")
io.open(P,'w',encoding='utf-8').write(s)
print('p11 ok')
