#!/usr/bin/env python3
"""Sound effects for the film, made in code, and the final mix with the music.

  Tools/film-sfx.py picture.mp4 music.m4a out.mp4 [music offset] [paper|desktop]

Every sound sits on an action in the cut (times below are seconds into the finished film, worked out from
Script.cut in Film.swift; if the cut changes, these must follow). Tones are simple 8-bit blips on the
pentatonic the music sits in (E minor / G major), so they can't clash with it.
"""
import subprocess, sys, wave
import numpy as np

picture, music, out = sys.argv[1:4]
music_at = float(sys.argv[4]) if len(sys.argv) > 4 else 2.1
SR = 48000
length = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                        "-of", "csv=p=0", picture]).decode())
track = np.zeros(int(length * SR) + SR, dtype=np.float64)
rng = np.random.default_rng(7)
E5, G5, A5, B5, D6, E6, G6 = 659.25, 783.99, 880.0, 987.77, 1174.66, 1318.51, 1567.98

def put(t, sound, gain=1.0):
    i = int(t * SR)
    if i < 0 or i >= len(track): return
    n = min(len(sound), len(track) - i)
    track[i:i + n] += sound[:n] * gain

def env(n, attack=0.003, decay=6.0):
    t = np.arange(n) / SR
    return np.minimum(1, t / attack) * np.exp(-decay * t / (n / SR))

def click(pitch=2200.0, dur=0.022):
    """A soft mouse or key tick: a tiny noise burst with a short pitched knock under it."""
    n = int(dur * SR); t = np.arange(n) / SR
    return (0.6 * rng.standard_normal(n) * np.exp(-t * 380) + 0.8 * np.sin(2 * np.pi * pitch * t) * np.exp(-t * 160)) * 0.5

def blip(freq, dur=0.085):
    """An 8-bit note: a square wave with its top harmonics rolled off."""
    n = int(dur * SR); t = np.arange(n) / SR
    wave_ = sum(np.sin(2 * np.pi * freq * k * t) / k for k in (1, 3, 5, 7))
    return wave_ * env(n, decay=3.2) * 0.42

def notes(freqs, step=0.085, last=0.22):
    total = np.zeros(int((step * (len(freqs) - 1) + last) * SR) + 1)
    for i, f in enumerate(freqs):
        s = blip(f, last if i == len(freqs) - 1 else step * 1.1)
        a = int(i * step * SR)
        total[a:a + len(s)] += s
    return total

def whoosh(dur=0.36, up=True):
    """Air: noise through a moving low-pass, swelling and falling away."""
    n = int(dur * SR); x = rng.standard_normal(n); y = np.zeros(n); acc = 0.0
    sweep = np.linspace(0.02, 0.22, n) if up else np.linspace(0.22, 0.02, n)
    for i in range(n):
        acc += sweep[i] * (x[i] - acc); y[i] = acc
    return y * np.sin(np.pi * np.arange(n) / n) ** 2 * 1.6

def pop(freq=330.0, dur=0.11):
    """A rounded pop: a sine that drops in pitch as it dies."""
    n = int(dur * SR); t = np.arange(n) / SR
    f = freq * (1.9 - 0.9 * t / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, attack=0.002, decay=4.5)

def shutter():
    """A camera: two dry clicks close together, then a tiny bright ping."""
    s = np.zeros(int(0.3 * SR))
    for at, g in ((0.0, 1.0), (0.07, 0.8)):
        c = click(1400.0, 0.03); a = int(at * SR); s[a:a + len(c)] += c * g
    p = blip(G6, 0.12) * 0.35; a = int(0.1 * SR); s[a:a + len(p)] += p
    return s

# --- the film, action by action -----------------------------------------------------------------------
layout = sys.argv[5] if len(sys.argv) > 5 else "paper"
if layout == "paper":
    put(1.10, click(), 0.55)                                   # click the sleeping widget
    put(1.36, whoosh(up=True), 0.30)                           # the chat opens
    for i in range(25):                                        # typing the prompt
        put(2.00 + 0.056 * i + rng.uniform(-0.006, 0.006), click(rng.uniform(1700, 2600), 0.016), 0.24)
    put(3.95, pop(520.0, 0.09), 0.40)                          # send
    put(5.22, whoosh(up=False), 0.28)                          # back to the widget
    put(5.82, notes([E5, B5], last=0.16), 0.38)                # it wakes
    for t in (7.80, 9.82, 11.80):                              # a step ticks over
        put(t, blip(E6, 0.06), 0.22)
    put(14.42, shutter(), 0.62)                                # the snapshot
    put(17.86, notes([G5, D6], step=0.11, last=0.2), 0.40)     # needs you: a question
    put(21.40, click(), 0.55)                                  # click "answer in Claude"
    put(21.70, whoosh(up=True), 0.28)
    put(23.00, click(), 0.55)                                  # pick the answer
    put(23.92, whoosh(up=False), 0.26)
    put(24.62, notes([E5, G5, B5, E6], last=0.3), 0.42)        # done
    put(26.85, click(), 0.55)                                  # click the finished card
    put(27.10, whoosh(up=True), 0.28)
    for t in (27.65, 27.79, 27.93, 29.10, 29.24):              # the reply writing itself in
        put(t, click(2400.0, 0.014), 0.16)
    put(28.30, pop(300.0), 0.42)                               # the image lands
    put(31.25, whoosh(dur=0.45, up=False), 0.28)               # out to the desktop
    for t, f in ((31.79, 262.0), (32.34, 294.0), (32.89, 330.0), (33.44, 392.0)):
        put(t, pop(f, 0.13), 0.55)                             # each size lands, a step higher
    put(35.25, notes([G5, D6], step=0.11, last=0.2), 0.30)     # all four need you
    put(37.15, whoosh(dur=0.4, up=True), 0.24)                 # the download card
    put(37.75, notes([B5, E6], step=0.12, last=0.3), 0.30)

else:
    # The desktop staging (DesktopFilm). Its events are written on the widget's clock, as in Film.swift, and
    # mapped through its cut: [-2, 6) then [8, 16) then [18, 42.4).
    def at(w): return w + 2 if w < 6 else (w if w < 16 else w - 2)
    put(at(-1.00), click(), 0.55)                                   # click the sleeping widget
    put(at(-0.72), whoosh(up=True), 0.30)                           # the chat grows out of it
    for i in range(25):                                             # typing the prompt
        put(at(-0.10 + 0.056 * i) + rng.uniform(-0.006, 0.006), click(rng.uniform(1700, 2600), 0.016), 0.24)
    put(at(1.85), pop(520.0, 0.09), 0.40)                           # send
    put(at(2.02), notes([E5, B5], last=0.16), 0.38)                 # the widget wakes beside the chat
    put(at(3.02), whoosh(up=False), 0.28)                           # the chat closes
    for w in (4.0, 8.02, 10.0):                                     # a step ticks over
        put(at(w), blip(E6, 0.06), 0.22)
    put(at(13.52), shutter(), 0.62)                                 # the snapshot (flash is 1.5 s into the act)
    put(at(18.06), notes([G5, D6], step=0.11, last=0.2), 0.40)      # needs you: a question
    put(at(21.60), click(), 0.55)                                   # click "answer in Claude"
    put(at(21.78), whoosh(up=True), 0.28)
    put(at(23.05), click(), 0.55)                                   # pick the answer
    put(at(24.07), notes([E5, G5, B5, E6], last=0.3), 0.42)         # done
    put(at(24.33), whoosh(up=False), 0.26)
    put(at(26.30), click(), 0.55)                                   # click the finished card
    put(at(26.53), whoosh(up=True), 0.28)
    for u in (0.5, 0.64, 0.78, 1.95, 2.09):                         # the reply writing itself in
        put(at(26.55 + u), click(2400.0, 0.014), 0.16)
    put(at(27.70), pop(300.0), 0.42)                                # the image lands
    put(at(30.68), whoosh(dur=0.45, up=False), 0.28)                # the chat closes; out to the whole screen
    for w, f in ((32.6, 294.0), (33.15, 330.0), (33.7, 392.0)):
        put(at(w), pop(f, 0.13), 0.55)                              # each other size lands, a step higher
    put(at(36.06), notes([G5, D6], step=0.11, last=0.2), 0.30)      # all four need you
    put(at(37.96), whoosh(dur=0.4, up=True), 0.24)                  # the download card
    put(at(38.55), notes([B5, E6], step=0.12, last=0.3), 0.30)

track = np.clip(track, -0.95, 0.95)[: int(length * SR)]
sfx_path = out.rsplit(".", 1)[0] + "-sfx.wav"
with wave.open(sfx_path, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((track * 32767).astype("<i2").tobytes())

# The music's own ending, instead of a fade: at "splice" (film seconds, on a beat) the track jumps forward a
# whole number of bars ("jump" seconds), so its final hit lands just before the film ends and it stops cleanly.
# Set MUSIC_EDIT=splice:jump (e.g. 35.95:20.0); without it the music fades out over the last 2.1 s.
import os
edit = os.environ.get("MUSIC_EDIT")
if edit:
    splice, jump = (float(v) for v in edit.split(":"))
    x = 0.06
    music_chain = (f"[1:a]asplit[ma][mb];[ma]atrim=0:{splice + x:.3f}[m1];"
                   f"[mb]atrim={splice + jump - x:.3f},asetpts=PTS-STARTPTS[m2];"
                   f"[m1][m2]acrossfade=d={2 * x:.3f}:c1=tri:c2=tri,afade=t=in:d=0.35,"
                   f"afade=t=out:st={length - 0.25:.2f}:d=0.25,loudnorm=I=-17:TP=-2:LRA=11[m];")
else:
    fade = max(0, length - 2.1)
    music_chain = f"[1:a]afade=t=in:d=0.35,afade=t=out:st={fade:.2f}:d=2.1,loudnorm=I=-17:TP=-2:LRA=11[m];"
graph = (music_chain +
         f"[2:a]aformat=channel_layouts=stereo,volume=1.0[s];[m][s]amix=inputs=2:normalize=0,alimiter=limit=0.9[a]")
subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-i", picture, "-ss", str(music_at), "-i", music,
                       "-i", sfx_path, "-filter_complex", graph, "-map", "0:v", "-map", "[a]", "-c:v", "copy",
                       "-c:a", "aac", "-b:a", "192k", "-t", str(length), "-movflags", "+faststart", out])
print("wrote", out, "and", sfx_path)
