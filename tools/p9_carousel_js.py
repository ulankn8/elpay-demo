# -*- coding: utf-8 -*-
"""v2.9: слушатель прокрутки карусели, точки, защита от ложного тапа."""
import io
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:90]!r}'
    s=s.replace(old,new)

# карусель не должна перехватываться жестом смены вкладок
rep("const NO='.cats,.hscroll,.minitiles,.cities,.seg,.keypad,.ybars,.chart,.map,input,textarea,select,.pms';",
    "const NO='.cats,.hscroll,.heroes,.minitiles,.cities,.seg,.keypad,.ybars,.chart,.map,input,textarea,select,.pms';")

# тап по карточке не срабатывает сразу после прокрутки
rep("  'obj-bills':t=>openBills(t.dataset.id),",
    "  'obj-bills':t=>{if(Date.now()-HSCR<320)return;openBills(t.dataset.id);},")
rep("let OBJD=null,OBJCB=null;","let OBJD=null,OBJCB=null,HSCR=0;")

# слушатель прокрутки
rep("$('#in-search').addEventListener('input',renderPay);",
    "$('#in-search').addEventListener('input',renderPay);\n"
    "(()=>{const h=$('#heroes');if(!h)return;let r=0;h.addEventListener('scroll',()=>{HSCR=Date.now();if(r)return;r=requestAnimationFrame(()=>{r=0;renderDots();});},{passive:true});})();")
io.open(P,'w',encoding='utf-8').write(s)
print('p9 ok')
