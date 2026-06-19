#!/usr/bin/env python3
import sys, os
from PIL import Image, ImageDraw, ImageFont

MK = "/Users/stevendiviney/code/ScreenTimeShield/Marketing"
SFNS = "/System/Library/Fonts/SFNS.ttf"
NOTO = "/nix/store/1zqf71m9w1kaf6qjgpbafihvjz5isf0w-noto-fonts-cjk-sans-2.004/share/fonts/opentype/noto-cjk/NotoSansCJK-VF.otf.ttc"
CJK_INDEX = {"ja": 0, "ko": 1, "zh-Hans": 2, "zh-Hant": 3}

BASE = {1: "store_1_no_text.png", 2: "store_2_no_text.png",
        3: "store_3_no_text.png", 4: "store_4_no_text.png"}

TOP_Y = 143          # caps-top of line 1 (from reference)
CX = 621             # horizontal center
WHITE = (255, 255, 255)
BASE_SIZE = 118      # SFNS size giving capH 83 (matches reference)
LEADING_RATIO = 137 / 118   # baseline-to-baseline / font size
MAX_LINE_W = 1010    # shrink font if any line exceeds this

# caption[locale] = [slot1, slot2, slot3, slot4]; '\n' = explicit line break
CAPS = {
 "en": ["Screen Time\nLimits That Stick", "Block Any App or\nWebsite",
        "Limits You\nCan't Skip", "Locked Until\nTime's Up"],
 "de": ["Limits, die\nwirklich halten", "Blockiere jede\nApp & Website",
        "Unumgehbare\nLimits", "Gesperrt, bis die\nZeit um ist"],
 "es": ["Límites que\nsí se cumplen", "Bloquea cualquier\napp o web",
        "Límites que no\npuedes saltarte", "Bloqueado hasta\nque acabe el tiempo"],
 "fr": ["Des limites qui\ntiennent vraiment", "Bloquez n'importe\nquelle app ou site",
        "Des limites\nincontournables", "Verrouillé\njusqu'à la fin"],
 "it": ["Limiti che\nfunzionano davvero", "Blocca qualsiasi\napp o sito",
        "Limiti che non\npuoi saltare", "Bloccato fino allo\nscadere del tempo"],
 "pt-PT": ["Limites que se\ncumprem mesmo", "Bloqueia qualquer\napp ou site",
           "Limites que não\npodes saltar", "Bloqueado até o\ntempo acabar"],
 "ja": ["ちゃんと続く\n利用制限", "あらゆるアプリや\nサイトをブロック",
        "スキップできない\n制限", "時間まで\n解除できない"],
 "ko": ["확실하게 지켜지는\n사용 시간 제한", "모든 앱과\n웹사이트 차단",
        "건너뛸 수 없는\n제한", "시간이 끝날\n때까지 잠금"],
 "zh-Hans": ["真正有效的\n屏幕时间限制", "屏蔽任何\n应用或网站",
             "无法跳过的\n限制", "锁定直到\n时间结束"],
 "zh-Hant": ["真正有效的\n螢幕時間限制", "封鎖任何\n應用程式或網站",
             "無法略過的\n限制", "鎖定直到\n時間結束"],
}

def load_font(locale, size):
    if locale in CJK_INDEX:
        f = ImageFont.truetype(NOTO, size, index=CJK_INDEX[locale])
        weight = "Bold"            # CJK needs more weight to read at this size
    else:
        f = ImageFont.truetype(SFNS, size)
        weight = "Semibold"        # matches the reference Latin weight
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f

def line_width(font, text):
    b = font.getbbox(text)
    return b[2] - b[0]

def render(locale, slot, outdir):
    base = Image.open(os.path.join(MK, BASE[slot])).convert("RGB")
    text = CAPS[locale][slot - 1]
    lines = text.split("\n")
    size = BASE_SIZE
    # shrink to fit
    for _ in range(40):
        font = load_font(locale, size)
        if max(line_width(font, ln) for ln in lines) <= MAX_LINE_W:
            break
        size -= 3
    font = load_font(locale, size)
    capH = font.getbbox("H")[3] - font.getbbox("H")[1]
    leading = LEADING_RATIO * size
    baseline1 = TOP_Y + capH
    draw = ImageDraw.Draw(base)
    for i, ln in enumerate(lines):
        by = baseline1 + i * leading
        draw.text((CX, by), ln, font=font, fill=WHITE, anchor="ms")
    os.makedirs(outdir, exist_ok=True)
    out = os.path.join(outdir, f"app_store_{slot}.png")
    base.save(out, "PNG")  # RGB, no alpha
    return out, size

if __name__ == "__main__":
    locales = sys.argv[1:] or list(CAPS.keys())
    for loc in locales:
        outdir = os.path.join(MK, loc)
        for slot in (1, 2, 3, 4):
            out, size = render(loc, slot, outdir)
            print(f"{loc} slot{slot}: size={size} -> {out}")
