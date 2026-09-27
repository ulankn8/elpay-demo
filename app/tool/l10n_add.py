# -*- coding: utf-8 -*-
"""Добавляет строки сразу в три места: abstract S, SRu, SKy.

Вызов: python3 tool/l10n_add.py <файл-с-данными.py>
Данные — список кортежей (сигнатура, ru, ky):
    ('String get payTitle', 'Платежи', 'Төлөмдөр')
    ('String billsCount(int n)', "'$n счёт'", "'$n эсеп'")   # тело как выражение
Если ru/ky начинается с кавычки — вставляется как есть (выражение),
иначе оборачивается в одинарные кавычки.
"""
import io, re, sys

P = 'lib/core/l10n/s.dart'


def lit(v):
    v = v.strip()
    return v if v.startswith(("'", '"', '(', 'switch')) else "'" + v.replace("\\", "\\\\").replace("'", r"\'") + "'"


def add(items, section=''):
    s = io.open(P, encoding='utf-8').read()

    def close_of(cls):
        i = s.index(cls)
        j = s.index('\n}\n', i)
        return j + 1

    absent = [(sig, ru, ky) for sig, ru, ky in items
              if not re.search(r'\b' + re.escape(sig.split()[-1].split('(')[0]) + r'\b', s)]
    if not absent:
        print('нечего добавлять')
        return

    head = ('\n  // ' + section + '\n') if section else '\n'
    blocks = {
        'abstract class S {': head + ''.join('  %s;\n' % sig for sig, _, _ in absent),
        'class SRu implements S {': head + ''.join(
            '  @override %s => %s;\n' % (sig, lit(ru)) for sig, ru, _ in absent),
        'class SKy implements S {': head + ''.join(
            '  @override %s => %s;\n' % (sig, lit(ky)) for sig, _, ky in absent),
    }
    for cls in ['class SKy implements S {', 'class SRu implements S {', 'abstract class S {']:
        j = close_of(cls)
        s = s[:j] + blocks[cls] + s[j:]
    io.open(P, 'w', encoding='utf-8').write(s)
    print('добавлено строк:', len(absent))
