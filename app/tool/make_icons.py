# -*- coding: utf-8 -*-
"""Иконки приложения из фирменного знака ЭлPay.

Знак повторяет логотип из брендбука ELBAGAR: вертикальная опора и три
перекладины. Фон — тёмный, как на карточках объектов; опора и нижняя
перекладина — фирменный зелёный, верхние — белые.

Запуск: python3 tool/make_icons.py
"""
from PIL import Image, ImageDraw

BG = (20, 34, 41)          # тёмный фон карточек
GREEN = (31, 184, 134)     # Brand.primary
WHITE = (255, 255, 255)

# координаты знака в сетке 240×240 (как в _MarkPainter)
BARS = [
    ((45, 40, 38, 160), GREEN),
    ((45, 162, 150, 38), GREEN),
    ((95, 40, 100, 38), WHITE),
    ((95, 101, 100, 38), WHITE),
]


def render(size, rounded=False, padding=0.14):
    scale = 8
    big = size * scale
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if rounded:
        d.rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * 0.22), fill=BG)
    else:
        d.rectangle([0, 0, big, big], fill=BG)

    inner = big * (1 - padding * 2)
    k = inner / 240
    off = big * padding
    for (x, y, w, h), color in BARS:
        d.rounded_rectangle(
            [off + x * k, off + y * k, off + (x + w) * k, off + (y + h) * k],
            radius=max(2, int(4 * k)),
            fill=color,
        )
    return img.resize((size, size), Image.LANCZOS)


ANDROID = {
    'mipmap-mdpi': 48, 'mipmap-hdpi': 72, 'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144, 'mipmap-xxxhdpi': 192,
}
IOS = {
    'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40, 'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29, 'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80, 'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120, 'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76, 'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167, 'Icon-App-1024x1024@1x.png': 1024,
}

if __name__ == '__main__':
    for folder, size in ANDROID.items():
        render(size, rounded=True).save(f'android/app/src/main/res/{folder}/ic_launcher.png')
    for name, size in IOS.items():
        # у iOS иконки без прозрачности и без своих скруглений
        render(size).convert('RGB').save(
            f'ios/Runner/Assets.xcassets/AppIcon.appiconset/{name}')
    # веб
    render(192, rounded=True).save('web/icons/Icon-192.png')
    render(512, rounded=True).save('web/icons/Icon-512.png')
    render(192).convert('RGB').save('web/icons/Icon-maskable-192.png')
    render(512).convert('RGB').save('web/icons/Icon-maskable-512.png')
    render(64, rounded=True).save('web/favicon.png')
    print('иконки обновлены')
