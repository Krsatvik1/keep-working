# Renders the Keep Working install walkthrough: real screenshots on the film's wallpaper, a clay ring on the one
# Usage: put the screenshots in <dir>/src (finder.png 9.png 10.png 11.png 12.png 16.png end.png), copy this script
# into <dir>, run `python3 install-video.py x`, then: ffmpeg -framerate 30 -i out/%05d.png -c:v libx264 -crf 22 -pix_fmt yuv420p install.mp4
# Screenshots: Satvik took the Gatekeeper and Privacy & Security ones (they are hidden from automated capture).
# thing to click, a caption pill. Frames to out/, then ffmpeg.
import sys, os, math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1920, 1080, 30
CLAY = (217, 119, 87)
font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 40)
font_b = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 40)
try:
    font_b.set_variation_by_name("Semibold")
except Exception:
    pass

wall = Image.new("RGB", (W, H), (238, 234, 228))  # the page's paper

# (image, seconds, step number, caption, ring box in image pixels (x0, y0, x1, y1) or None, fit height share)
scenes = [
    ("finder.png", 3.0, "1", "Unzip it, then drag Keep Working into Applications.", (230, 121, 1212, 151), 0.66, (32, 211, 190, 245)),
    ("9.png", 2.6, "2", "macOS stops it the first time. Click Done.", (274, 556, 494, 612), 0.70, None),
    ("10.png", 3.0, "3", "System Settings, Privacy & Security. Click Open Anyway.", (1470, 696, 1680, 744), 0.74, None),
    ("11.png", 2.6, "3", "Confirm with Open Anyway.", (730, 696, 1178, 750), 0.74, None),
    ("12.png", 2.4, "3", "Then Touch ID or your password.", None, 0.74, None),
    ("16.png", 2.8, "4", "Right-click the desktop and choose Edit Widgets.", (250, 455, 615, 500), 0.68, None),
    ("end.png", 3.2, "4", "Pick a size. It keeps you posted from here.", None, 0.80, None),
]

def rounded(img, r):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, img.width - 1, img.height - 1), r, fill=255)
    return m

def ease(t):
    return t * t * (3 - 2 * t)

def scene_frame(sc, t, dur):
    name, _, num, cap, ring, share, ring2 = sc
    img = Image.open(os.path.join(S, "src", name)).convert("RGB")
    base = H * share / img.height
    k = base * (1.0 + 0.035 * ease(min(1, t / dur)))
    w, h = round(img.width * k), round(img.height * k)
    im = img.resize((w, h), Image.LANCZOS)
    x0, y0 = (W - w) // 2, (H - h) // 2 - 50
    frame = wall.copy()
    # shadow
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((x0, y0 + 24, x0 + w, y0 + h + 24), 28, fill=(60, 40, 30, 70))
    sh = sh.filter(ImageFilter.GaussianBlur(30))
    frame.paste(sh, (0, 0), sh)
    frame.paste(im, (x0, y0), rounded(im, 26))
    d = ImageDraw.Draw(frame, "RGBA")
    # ring: grows in after 0.5 s, then a soft pulse
    for box in [b for b in (ring, ring2) if b]:
        a = ease(max(0, min(1, (t - 0.5) / 0.35)))
        if a > 0:
            pad = 10 + 4 * math.sin(max(0, t - 0.85) * 4)
            bx = (x0 + box[0] * k - pad, y0 + box[1] * k - pad, x0 + box[2] * k + pad, y0 + box[3] * k + pad)
            rr = (bx[3] - bx[1]) / 2
            d.rounded_rectangle(bx, rr, outline=CLAY + (round(255 * a),), width=6)
            d.rounded_rectangle((bx[0] - 6, bx[1] - 6, bx[2] + 6, bx[3] + 6), rr + 6, outline=CLAY + (round(70 * a),), width=6)
    # caption pill
    label = f"{num}   {cap}"
    tw = d.textlength(cap, font=font) + d.textlength(num + "   ", font=font_b)
    pw, ph = tw + 64, 76
    px, py = (W - pw) / 2, H - 120
    d.rounded_rectangle((px, py, px + pw, py + ph), ph / 2, fill=(20, 18, 17, 225))
    d.text((px + 32, py + ph / 2), num, font=font_b, fill=CLAY, anchor="lm")
    d.text((px + 32 + d.textlength(num + "   ", font=font_b), py + ph / 2), cap, font=font, fill=(245, 242, 238), anchor="lm")
    return frame

out = os.path.join(S, "out")
os.makedirs(out, exist_ok=True)
for f in os.listdir(out):
    os.remove(os.path.join(out, f))
XF = 0.35  # crossfade seconds
n = 0
for i, sc in enumerate(scenes):
    dur = sc[1]
    frames = round(dur * FPS)
    for j in range(frames):
        t = j / FPS
        fr = scene_frame(sc, t, dur)
        if i + 1 < len(scenes) and t > dur - XF:
            nxt = scene_frame(scenes[i + 1], 0, scenes[i + 1][1])
            fr = Image.blend(fr, nxt, (t - (dur - XF)) / XF)
        fr.save(os.path.join(out, f"{n:05d}.png"))
        n += 1
print("frames", n)
