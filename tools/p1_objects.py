# -*- coding: utf-8 -*-
"""v2.8 шаг 1: объекты вместо текстовой метки «Кому»."""
import io,sys
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:90]!r}'
    s=s.replace(old,new)

# --- 1. демо-данные: объекты и привязка счетов ---
rep("conn:[{id:'trash-1',svc:'trash',name:'Ош-Тазалык',acc:'04-118725',amount:180,who:'Мои'}",
    "obj:[{id:'o1',name:'Дом',icon:'house',c:'water',addr:'Ош, ул. Курманжан Датка, 212'},{id:'o2',name:'Родители',icon:'users',c:'door',addr:'Ош, ул. Масалиева, 44'}],"
    "conn:[{id:'trash-1',svc:'trash',name:'Ош-Тазалык',acc:'04-118725',amount:180,who:'o1'}")
rep("who:'Мои'}","who:'o1'}",2)
rep("who:'Родителям'}","who:'o2'}",2)

# --- 2. хелперы объектов ---
rep("""const WHO0='Мои';
const WHOS=['Мои','Родителям','Детям'];
const whoOf=b=>b.who||WHO0;
const whoAll=()=>[...new Set(bills().map(whoOf))];
const whoOpts=()=>[...new Set([...WHOS,...st.conn.map(whoOf),...st.custom.map(whoOf)])];""",
"""const WHO0='o1';
const OBJI={house:'water','building-2':'net',users:'door',trees:'trash',briefcase:'tax',store:'market',car:'power','graduation-cap':'course',warehouse:'gas','map-pin':'city'};
const OBJICONS=Object.keys(OBJI);
const objById=id=>st.obj.find(o=>o.id===id)||st.obj[0];
const objName=id=>tx(objById(id).name);
const objTile=(id,sz=22,soft)=>{const o=objById(id);return tl(o.c||OBJI[o.icon]||'water',o.icon,sz,soft);};
const objId=()=>{let n=1;while(st.obj.some(o=>o.id==='o'+n))n++;return 'o'+n;};
const whoOf=b=>(b.who&&st.obj.some(o=>o.id===b.who))?b.who:WHO0;
const whoAll=()=>st.obj.map(o=>o.id).filter(id=>bills().some(b=>whoOf(b)===id));
const whoOpts=()=>st.obj.map(o=>o.id);
const objBills=id=>bills().filter(b=>whoOf(b)===id);""")

# --- 3. вывод названия объекта вместо текстовой метки ---
rep('${whoOf(b)!==WHO0?" · "+tx(whoOf(b)):""}','${whoAll().length>1?" · "+objName(whoOf(b)):""}')          # renderPay
rep("${whoOf(c)!==WHO0?' · '+tx(whoOf(c)):''}","${st.obj.length>1?' · '+objName(whoOf(c)):''}")            # connRow
rep("${whoAll().length>1?F.billsWho(all.length,whoAll().map(tx).join(' и ')):",
    "${whoAll().length>1?F.billsWho(all.length,whoAll().map(objName).join(' и ')):")                        # карточка «Счета»
rep("const groups=whoOpts().map(w=>({w,list:st.conn.filter(c=>whoOf(c)===w)})).filter(g=>g.list.length);",
    "const groups=whoOpts().map(w=>({w,list:st.conn.filter(c=>whoOf(c)===w)})).filter(g=>g.list.length);")   # без изменений
rep("<div class=\"sec\"><h3>${tx(g.w)}</h3>","<div class=\"sec\"><h3>${objName(g.w)}</h3>")                  # реквизиты
rep("h+=`<div class=\"sec\"><h3>${tx(w)}</h3>","h+=`<div class=\"sec\"><h3>${objName(w)}</h3>")              # шторка счетов
rep('${items.some(x=>whoOf(x)!==whoOf(items[0]))?" · "+tx(whoOf(b)):""}',
    '${items.some(x=>whoOf(x)!==whoOf(items[0]))?" · "+objName(whoOf(b)):""}')                              # оплата
rep("${whoOf(b)!==WHO0?`<div><span>Кому</span><b>${tx(whoOf(b))}</b></div>`:''}",
    "${st.obj.length>1?`<div><span>Объект</span><b>${objName(whoOf(b))}</b></div>`:''}")                    # карточка счёта
rep("confirmSheet('Удалить счёт?',F.discQ(c.name,tx(whoOf(c))),'Удалить',()=>{",
    "confirmSheet('Удалить счёт?',F.discQ(c.name,objName(whoOf(c))),'Удалить',()=>{")

# --- 4. поле выбора объекта вместо чипов «Кому» ---
old_field=s[s.find("const whoField="):s.find("let SD=null;")]
new_field="""const whoField=(who,act)=>`<div class="field"><span class="lbl">Объект</span><div class="cities">${st.obj.map(o=>`<button class="city${o.id===who?' on':''}" data-act="${act}" data-w="${o.id}">${o.id===who?ic('check',16):''}${tx(o.name)}</button>`).join('')}<button class="city" data-act="${act}" data-w="+">${ic('plus',16)}Новый объект</button></div><p class="hint">Счёт попадёт в этот объект — так они не перемешаются</p></div>
"""
s=s.replace(old_field,new_field)
rep("${whoField(SD.who,'sd-who',SD.whoEdit)}","${whoField(SD.who,'sd-who')}")
rep("${whoField(LASTNP.who||WHO0,'nk-who',LASTNP.whoEdit)}","${whoField(LASTNP.who||WHO0,'nk-who')}")
rep("SD={svc,name:src?(src.name||u.name):u.name,acc:src?src.acc:'',who:src?whoOf(src):WHO0,whoEdit:0,src:src||null};",
    "SD={svc,name:src?(src.name||u.name):u.name,acc:src?src.acc:'',who:src?whoOf(src):(st.objSel||WHO0),src:src||null};")

# --- 5. обработчики выбора объекта ---
rep("""  'sd-who':t=>{
    SD.name=$('#sd-name').value;SD.acc=$('#sd-acc').value;
    if(t.dataset.w==='+')SD.whoEdit=1;else{SD.who=t.dataset.w;SD.whoEdit=0;}
    setBody(svcHTML());if(SD.whoEdit)$('#w-new').focus();
  },""",
"""  'sd-who':t=>{
    SD.name=$('#sd-name').value;SD.acc=$('#sd-acc').value;
    if(t.dataset.w==='+')return objSheet(null,id=>{SD.who=id;openSheet(SD.src?'Изменить счёт':'Добавить счёт',svcHTML(),'sd');});
    SD.who=t.dataset.w;setBody(svcHTML());
  },""")
rep("  'nk-who':t=>{LASTNP.name=$('#nk-name').value;if(t.dataset.w==='+')LASTNP.whoEdit=1;else{LASTNP.who=t.dataset.w;LASTNP.whoEdit=0;}setBody(npKeepHTML());if(LASTNP.whoEdit)$('#w-new').focus();},",
    "  'nk-who':t=>{LASTNP.name=$('#nk-name').value;if(t.dataset.w==='+')return objSheet(null,id=>{LASTNP.who=id;openSheet('Сохранить реквизиты',npKeepHTML(),'nk');});LASTNP.who=t.dataset.w;setBody(npKeepHTML());},")
rep("    const w=SD.whoEdit?($('#w-new').value.trim()||WHO0):SD.who;","    const w=SD.who||WHO0;")
rep("    const name=$('#nk-name').value.trim(),w=LASTNP.whoEdit?($('#w-new').value.trim()||WHO0):(LASTNP.who||WHO0);",
    "    const name=$('#nk-name').value.trim(),w=LASTNP.who||WHO0;")
io.open(P,'w',encoding='utf-8').write(s)
print('p1 ok')
