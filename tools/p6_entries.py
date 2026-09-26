# -*- coding: utf-8 -*-
"""v2.8 шаг 6: формулы, шторка контролёров, входы в чат."""
import io
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:90]!r}'
    s=s.replace(old,new)

rep("  objAdded:n=>",
"""  spend:(d,sum)=>ky()?`Керектөө ${d} · ${sum} сом`:`Расход ${d} · ${sum} сом`,
  calling:(n,ph)=>ky()?`Чалуу: ${n} · ${ph}`:`Звоним: ${n} · ${ph}`,
  readSent:(v,n)=>ky()?`${v} көрсөткүчү жөнөтүлдү — ${n}`:`Показания ${v} отправлены — ${n}`,
  objAdded:n=>""")

# шторка со списком контролёров
rep("function cardHow(){",
"""function ctrlSheet(){
  const list=Object.keys(CTRL).filter(k=>st.conn.some(c=>c.svc===k));
  openSheet('Контролёры участков',`<p class="sub">Контролёр обходит дома и снимает показания. Можно позвонить или передать показания заранее — и не ждать обхода.</p>
   <div class="group wrap">${list.map(k=>{const c=CTRL[k],u=UTIL.find(x=>x.id===k)||{};
     return `<div class="row">${tl(CAT[u.icon]||'water','user',22,1)}<span class="mid"><span class="t">${c.n}</span><span class="s">${tx(u.name)} · ${tx(c.u)} · ${c.ph}</span></span>${c.unit?`<button class="paybtn" data-act="ctrl-read" data-svc="${k}">${ic('gauge',15)}Показания</button>`:''}</div>`;}).join('')||'<p class="empty">Нет подключённых услуг</p>'}</div>`,'ctrl');
}
function cardHow(){""")
rep("  'chat-open':()=>{renderChat();go('chat');},",
    "  'chat-open':()=>{closeSheet();renderChat();go('chat');},\n  'ctrl-list':()=>ctrlSheet(),")

# входы: «Платежи» и профиль
rep('<button class="row" data-act="obj-list">${tl(\'water\',\'house\')}',
    '<button class="row" data-act="chat-open">${tl(\'net\',\'headset\')}<span class="mid"><span class="t">Не знаю свои реквизиты</span><span class="s">Напишите в чат — найдём по адресу</span></span>${ic(\'chevron-right\',18)}</button>'
    '<button class="row" data-act="obj-list">${tl(\'water\',\'house\')}')
rep('              <div class="sec rv" style="--d:6"><h3>Приложение</h3></div>',
    '              <div class="sec rv" style="--d:5"><h3>Поддержка</h3></div>\n'
    '              <div class="group rv wrap" style="--d:5">\n'
    '                <button class="row" data-act="chat-open"><span class="tile"><i data-i="headset"></i></span><span class="mid"><span class="t">Чат с поддержкой</span><span class="s">Реквизиты, начисления, карта</span></span><i data-i="chevron-right" data-s="18"></i></button>\n'
    '                <button class="row" data-act="ctrl-list"><span class="tile"><i data-i="user"></i></span><span class="mid"><span class="t">Контролёры участков</span><span class="s">Позвонить или передать показания</span></span><i data-i="chevron-right" data-s="18"></i></button>\n'
    '              </div>\n'
    '              <div class="sec rv" style="--d:6"><h3>Приложение</h3></div>')
io.open(P,'w',encoding='utf-8').write(s)
print('p6 ok')
