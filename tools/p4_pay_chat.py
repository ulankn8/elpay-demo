# -*- coding: utf-8 -*-
"""v2.8 шаг 4: кнопка «Оплатить» у каждого счёта + чат поддержки."""
import io
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:90]!r}'
    s=s.replace(old,new)

# ---------- стили ----------
rep(".minitiles.ic5{",
""".paybtn{margin-top:6px;height:30px;padding:0 14px;border-radius:999px;background:var(--primary);color:var(--onp);font-size:12.5px;font-weight:700;display:inline-flex;align-items:center;gap:5px;transition:transform .12s,filter .2s}
.paybtn:active{transform:scale(.95)}
.chat{display:flex;flex-direction:column;gap:10px;padding:4px 0 6px}
.msg{max-width:84%;padding:11px 14px;border-radius:18px;font-size:14.5px;line-height:1.45;white-space:normal}
.msg.op{align-self:flex-start;background:var(--bg);box-shadow:var(--sh-sm);border-bottom-left-radius:6px}
.msg.me{align-self:flex-end;background:var(--light2);color:var(--p700);border-bottom-right-radius:6px}
.msg .w{display:block;margin-top:4px;font-size:11px;color:var(--muted)}
.msg.me .w{color:var(--p700);opacity:.7}
.msg.card{width:100%;max-width:100%;padding:12px}
.msg.card .row{padding:8px 0}
.typing{align-self:flex-start;display:flex;gap:4px;padding:14px 16px;border-radius:18px;background:var(--bg);box-shadow:var(--sh-sm)}
.typing i{width:7px;height:7px;border-radius:50%;background:var(--muted);animation:tp 1.1s infinite}
.typing i:nth-child(2){animation-delay:.15s}.typing i:nth-child(3){animation-delay:.3s}
@keyframes tp{0%,60%,100%{opacity:.3;transform:translateY(0)}30%{opacity:1;transform:translateY(-3px)}}
.qr-row{display:flex;gap:8px;overflow-x:auto;scrollbar-width:none;padding:10px 0 4px}
.qr-row::-webkit-scrollbar{display:none}
.qa{flex:none;height:36px;padding:0 14px;border-radius:999px;border:1.5px solid var(--line);background:var(--bg);font-size:13px;font-weight:600;color:var(--gr)}
.chat-in{display:flex;gap:8px;align-items:center}
.chat-in .inp{flex:1}
.chat-send{width:44px;height:44px;flex:none;border-radius:50%;background:var(--primary);color:var(--onp);display:grid;place-items:center}
.minitiles.ic5{""")

# ---------- строка счёта с кнопкой «Оплатить» ----------
rep("function openBills(){",
"""const billRowP=b=>st.paid[b.id]
 ?`<div class="row" data-act="bill" data-id="${b.id}">${tile(b)}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.sub}</span></span><span class="end"><span class="amt num">${fmt(b.amount)} <small>сом</small></span>${okChip()}</span></div>`
 :`<div class="row" data-act="bill" data-id="${b.id}">${tile(b)}<span class="mid"><span class="t">${b.short}</span><span class="s">${b.sub} · ${tx(b.dueShort)}</span></span><span class="end"><span class="amt num">${fmt(b.amount)} <small>сом</small></span><button class="paybtn" data-act="paybill" data-id="${b.id}">${ic('arrow-right',15)}Оплатить</button></span></div>`;
function openBills(){""")
rep("h+=`<div class=\"sec\"><h3>${objName(w)}</h3>${s?`<span class=\"amt num\">${fmt(s)} <small>сом</small></span>`:okChip()}</div><div class=\"group wrap\">${list.map(billRow).join('')}</div>`;",
    "h+=`<div class=\"sec\"><h3>${objName(w)}</h3>${s?`<span class=\"amt num\">${fmt(s)} <small>сом</small></span>`:okChip()}</div><div class=\"group wrap\">${list.map(billRowP).join('')}</div>`;")
rep("if(due.length)h+=`<div class=\"sec\"><h3>К оплате</h3></div><div class=\"group wrap\">${due.map(billRow).join('')}</div>`;",
    "if(due.length)h+=`<div class=\"sec\"><h3>К оплате</h3></div><div class=\"group wrap\">${due.map(billRowP).join('')}</div>`;")
rep("if(paid.length)h+=`<div class=\"sec\"><h3>Оплачено</h3></div><div class=\"group wrap\">${paid.map(billRow).join('')}</div>`;",
    "if(paid.length)h+=`<div class=\"sec\"><h3>Оплачено</h3></div><div class=\"group wrap\">${paid.map(billRowP).join('')}</div>`;")
rep("<div class=\"group wrap\">${list.length?list.map(billRow).join(''):'<p class=\"empty\">Здесь пока нет счетов</p>'}",
    "<div class=\"group wrap\">${list.length?list.map(billRowP).join(''):'<p class=\"empty\">Здесь пока нет счетов</p>'}")

# ---------- экран чата ----------
rep('          <!-- 20. Объекты -->',
"""          <!-- 21. Чат поддержки -->
          <section class="scr" id="s-chat">
            <div class="body" id="chat-body"></div>
            <div class="cta" id="chat-cta"></div>
          </section>

          <!-- 20. Объекты -->""")

rep("function renderPM(){",
"""/* ===== Чат поддержки ===== */
const CHATQ=[['acc','Не знаю свой лицевой счёт'],['err','Ошибка в начислении'],['card','Как привязать карту'],['op','Позвать оператора']];
const FOUND=[{svc:'power',name:'Электросеть',acc:'7710-9931'},{svc:'water',name:'Водоканал',acc:'31-01188'},{svc:'trash',name:'Ош-Тазалык',acc:'04-120714'}];
function msgHTML(m){
  if(m.typing)return '<div class="typing"><i></i><i></i><i></i></div>';
  if(m.found)return `<div class="msg op card"><b>${tx('Нашли счета по адресу')}</b><div class="group wrap" style="margin-top:8px">${FOUND.map(f=>`<div class="row">${tile({icon:SVC[f.svc].icon})}<span class="mid"><span class="t">${tx(f.name)}</span><span class="s">${F.acc(f.acc)}</span></span><button class="paybtn" data-act="chat-add" data-svc="${f.svc}" data-acc="${f.acc}" data-name="${f.name}">${ic('plus',15)}Добавить</button></div>`).join('')}</div><span class="w">${m.w}</span></div>`;
  return `<div class="msg ${m.me?'me':'op'}">${tx(m.t)}<span class="w">${m.w}</span></div>`;
}
function renderChat(){
  const el=$('#chat-body');if(!el)return;
  el.innerHTML=`<div class="nav"><button class="nb" data-act="back" aria-label="Назад">${ic('chevron-left',24)}</button><span class="nt">Помощь</span><span class="sp"></span></div>
   <div class="row" style="margin-bottom:6px">${tl('water','headset',22,1)}<span class="mid"><span class="t">Поддержка ЭлPay</span><span class="s">Отвечаем в среднем за 2 минуты</span></span><span class="chip ok sm">${ic('check',12,3)}Онлайн</span></div>
   <div class="chat" id="chat-list">${st.chat.map(msgHTML).join('')}</div>`;
  const cta=$('#chat-cta');
  cta.innerHTML=`<div class="qr-row">${(st.chatQ||CHATQ).map(([k,t])=>`<button class="qa" data-act="chat-q" data-k="${k}">${tx(t)}</button>`).join('')}</div>
   <div class="chat-in"><div class="inp"><input id="chat-t" placeholder="Сообщение"></div><button class="chat-send" data-act="chat-send" aria-label="Отправить">${ic('arrow-right',20)}</button></div>`;
  const b=el;b.scrollTop=b.scrollHeight;
  if(ky())trTree(el),trTree(cta);
}
function chatPush(m){st.chat.push(m);renderChat();const b=$('#chat-body');if(b)b.scrollTop=b.scrollHeight;}
async function chatBot(kind){
  chatPush({typing:1});await wait(1100);st.chat.pop();
  if(kind==='acc'){
    chatPush({t:'Подскажите адрес: улица, дом и квартира. Найдём ваши лицевые счета в базе поставщиков.',w:TODAY.time});
    st.chatQ=[['addr','Отправить мой адрес'],['op','Позвать оператора']];renderChat();
  }else if(kind==='addr'){
    chatPush({found:1,w:TODAY.time});
    await wait(400);chatPush({t:'Нажмите «Добавить» — реквизиты подставятся сами, вводить ничего не нужно.',w:TODAY.time});
    st.chatQ=null;renderChat();
  }else if(kind==='err'){
    chatPush({t:'Пришлите фото квитанции — проверим начисление у поставщика и вернёмся с ответом в течение дня.',w:TODAY.time});
  }else if(kind==='card'){
    chatPush({t:'Профиль → Способы оплаты → «Добавить карту». Данные вводятся в защищённой форме банка, мы номер карты не храним.',w:TODAY.time});
    await wait(300);chatPush({t:'Открыть инструкцию?',w:TODAY.time});st.chatQ=[['cardgo','Открыть инструкцию'],['op','Позвать оператора']];renderChat();
  }else{
    chatPush({t:'Соединяю с оператором. Айсулуу подключится через минуту — можно писать прямо сюда.',w:TODAY.time});
  }
}
function renderPM(){""")
rep("renderNotif();renderObjs();","renderNotif();renderObjs();renderChat();")
io.open(P,'w',encoding='utf-8').write(s)
print('p4 ok')
