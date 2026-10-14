#!/usr/bin/env bash
# Собирает кабинет служб и кладёт его в /admin рядом с витриной.
# Движок CanvasKit лежит рядом, без CDN: кабинет открывается и там,
# где gstatic.com недоступен. Варианты движка для --wasm не нужны — их убираем.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="${FLUTTER:-flutter}"
cd "$ROOT/app"
"$FLUTTER" build web --release -t lib/admin/main_admin.dart \
  --base-href /elpay-demo/admin/ --no-web-resources-cdn --no-wasm-dry-run \
  -o build/web_admin_pub
rm -rf "$ROOT/admin"
cp -r build/web_admin_pub "$ROOT/admin"
cd "$ROOT/admin"
rm -rf .last_build_id canvaskit/webparagraph canvaskit/wimp.* canvaskit/skwasm* canvaskit/*.symbols canvaskit/chromium/*.symbols
python3 - <<'PY'
import json
s = open('index.html', encoding='utf-8').read()
s = s.replace('<title>ЭлPay</title>', '<title>Кабинет служб ЭлPay</title>')
s = s.replace('content="ЭлPay — коммунальные платежи, садик и школа, билеты"',
              'content="Кабинет служб ЭлPay: абоненты из 1С, начисления, оплаты и реестр"')
s = s.replace('<meta name="apple-mobile-web-app-title" content="ЭлPay">',
              '<meta name="apple-mobile-web-app-title" content="Кабинет ЭлPay">')
open('index.html', 'w', encoding='utf-8').write(s)
m = json.load(open('manifest.json', encoding='utf-8'))
m.update(name='Кабинет служб ЭлPay', short_name='Кабинет ЭлPay', orientation='any',
         description='Кабинет служб ЭлPay: абоненты из 1С, начисления, оплаты и реестр')
json.dump(m, open('manifest.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=4)
PY
du -sh "$ROOT/admin"
