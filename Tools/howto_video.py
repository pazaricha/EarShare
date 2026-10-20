# Builds marketing/video/earshare-howto.mp4 + .gif from the panel snapshots (run Tools/snapshots.sh first).
# Usage: <venv-with-pillow>/bin/python Tools/howto_video.py
import os, subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SNAP, OUT = f"{ROOT}/marketing/snapshots", f"{ROOT}/marketing/video"
W, H = 1920, 1080
BOLD = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 64, index=1)
SUB = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 38, index=0)
SMALL = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 30, index=0)

def background():
    bed = Image.open(f"{ROOT}/marketing/bed/v1.png").convert("RGB").resize((W, H))
    bed = bed.filter(ImageFilter.GaussianBlur(18))
    return Image.blend(bed, Image.new("RGB", (W, H), (10, 14, 40)), 0.55)

BG = background()
ICON = Image.open(f"{ROOT}/art/AppIcon-256.png").convert("RGBA")
GLYPH = Image.open(f"{ROOT}/Resources/MenuBarIcon@2x.png").convert("RGBA")

def menubar(img, highlight=False):
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W, 48), fill=(30, 32, 48))
    x = W - 420
    if highlight: d.rounded_rectangle((x - 12, 2, x + GLYPH.width + 12, 46), 10, outline=(255, 200, 80), width=4)
    white = Image.new("RGBA", GLYPH.size, (255, 255, 255, 255)); white.putalpha(GLYPH.getchannel("A"))
    img.paste(white, (x, 8), white)
    d.text((W - 340, 10), "Tue 9:41 PM", font=SMALL, fill=(235, 235, 245))
    return x

def frame(title, sub, snap=None, highlight_menu=False):
    img = BG.copy().convert("RGBA")
    mx = menubar(img, highlight_menu)
    d = ImageDraw.Draw(img)
    d.text((120, 300), title, font=BOLD, fill="white")
    y = 390
    for line in sub.split("\n"):
        d.text((120, y), line, font=SUB, fill=(215, 220, 245)); y += 52
    if snap:
        p = Image.open(f"{SNAP}/{snap}.png").convert("RGBA")
        scale = min(1.0, 900 / p.height); p = p.resize((int(p.width * scale), int(p.height * scale)))
        px = min(mx - p.width // 2, W - p.width - 60); py = 70
        shadow = Image.new("RGBA", (p.width + 80, p.height + 80), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle((40, 50, p.width + 40, p.height + 40), 24, fill=(0, 0, 0, 150))
        img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(20)), (px - 40, py - 40))
        mask = Image.new("L", p.size, 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, *p.size), 22, fill=255)
        img.paste(p, (px, py), mask)
    return img.convert("RGB")

def card(lines, icon=True):
    img = BG.copy().convert("RGBA"); d = ImageDraw.Draw(img)
    if icon: img.alpha_composite(ICON, ((W - 256) // 2, 230))
    y = 530
    for text, font in lines:
        w = d.textlength(text, font=font); d.text(((W - w) / 2, y), text, font=font, fill="white"); y += font.size + 30
    return img.convert("RGB")

# (image, seconds)
scenes = [
    (card([("EarShare", BOLD), ("Two headphones. One movie. Sleeping kids.", SUB)]), 3.0),
    (frame("Click the popcorn icon", "EarShare lives in the menu bar,\nnext to the clock.", None, True), 2.5),
    (frame("1. Connect headphones", "Paired AirPods show up here.\nOne click to connect.", "1-connect"), 3.0),
    (frame("1. Connect headphones", "Connecting…", "2-connecting"), 1.5),
    (frame("2. Tick who's listening", "Both AirPods are connected now.\nTick each one you want.", "3-connected"), 2.5),
    (frame("2. Tick who's listening", "Two ticked: you're ready.", "4-ticked"), 2.0),
    (frame("3. Share sound", "Press the green button.\nThe movie plays in both AirPods.", "4-ticked"), 2.5),
    (frame("Set your own volume", "Each person gets a slider.\nPress Stop when the credits roll.", "5-sharing-dark"), 3.5),
    (card([("Free and open source", BOLD), ("github.com/pazaricha/EarShare", SUB)]), 3.0),
]

os.makedirs(f"{OUT}/frames", exist_ok=True)
FADE = 0.4
args, filters = [], []
for i, (img, secs) in enumerate(scenes):
    path = f"{OUT}/frames/{i:02d}.png"; img.save(path)
    args += ["-loop", "1", "-t", str(secs), "-i", path]
# chain crossfades
offset, prev = 0.0, "0:v"
for i in range(1, len(scenes)):
    offset += scenes[i - 1][1] - FADE
    filters.append(f"[{prev}][{i}:v]xfade=transition=fade:duration={FADE}:offset={offset:.2f}[v{i}]")
    prev = f"v{i}"
fc = f"{OUT}/filter.txt"; open(fc, "w").write(";".join(filters))
mp4 = f"{OUT}/earshare-howto.mp4"
total = sum(s for _, s in scenes) - FADE * (len(scenes) - 1)
# music: Tools/lullaby.py output, faded out with the last scene
open(fc, "a").write(f";[{len(scenes)}:a]atrim=0:{total:.2f},afade=t=in:d=0.5,afade=t=out:st={total - 2.5:.2f}:d=2.5,volume=0.8[a]")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *args, "-i", f"{OUT}/lullaby.wav", "-/filter_complex", fc,
                "-map", f"[{prev}]", "-map", "[a]", "-c:a", "aac", "-b:a", "160k",
                "-r", "30", "-pix_fmt", "yuv420p", "-c:v", "libx264", "-crf", "20", mp4], check=True)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", mp4, "-vf",
                "fps=8,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse",
                f"{OUT}/earshare-howto.gif"], check=True)
print("ok", mp4)
