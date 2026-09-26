# -*- coding: utf-8 -*-
"""v2.8 шаг 3: входы в «Мои объекты», формулы и состояние."""
import io
P='v2.html'
s=io.open(P,encoding='utf-8').read()
def rep(old,new,cnt=1):
    global s
    n=s.count(old)
    assert n==cnt, f'expected {cnt}, found {n}: {old[:90]!r}'
    s=s.replace(old,new)

rep("bal:1240,qr:null","bal:1240,qr:null,objId:null,objSel:'o1'")
rep("  objAdded:n=>","  objAdded:n=>",0) if False else None
rep("  billsWho:(n,w)=>",
"""  objAdded:n=>ky()?`«${n}» объекти түзүлдү`:`Объект «${n}» создан`,
  objDelQ:(a,b)=>ky()?`«${a}» объекти өчүрүлөт, анын эсептери «${b}» объектине өтөт.`:`Объект «${a}» будет удалён, его счета переедут в «${b}».`,
  billsWho:(n,w)=>""")

# строка в «Платежах»
rep('<button class="row" data-act="req">${tl(\'tax\',\'square-pen\')}<span class="mid"><span class="t">Реквизиты и счета</span>',
    '<button class="row" data-act="obj-list">${tl(\'water\',\'house\')}<span class="mid"><span class="t">Мои объекты</span><span class="s">Дом, родители, дача — счета по объектам</span></span>${ic(\'chevron-right\',18)}</button>'
    '<button class="row" data-act="req">${tl(\'tax\',\'square-pen\')}<span class="mid"><span class="t">Реквизиты и счета</span>')

# строка в профиле
rep('<div class="sec rv" style="--d:2"><h3>Адреса</h3></div>',
    '<div class="sec rv" style="--d:2"><h3>Объекты</h3></div>\n'
    '              <div class="group rv" style="--d:2"><button class="row" data-act="obj-list"><span class="tile lt"><i data-i="house"></i></span><span class="mid"><span class="t">Мои объекты</span><span class="s">Счета по дому, родителям и другим адресам</span></span><i data-i="chevron-right" data-s="18"></i></button></div>\n'
    '              <div class="sec rv" style="--d:2"><h3>Адреса для уведомлений</h3></div>')
io.open(P,'w',encoding='utf-8').write(s)
print('p3 ok')
