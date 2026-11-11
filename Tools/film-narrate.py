#!/usr/bin/env python3
"""Lays a spoken voiceover and the music under a rendered cut.

  Tools/film-narrate.py picture.mp4 voice.m4a music.m4a out.mp4 [music offset]

The voiceover comes as one long read with uneven pauses. This finds its phrases by their silences and lays
them end to end with even gaps, so the read spans the film from start to finish. The music ducks under the
voice. Phrases are NOT matched to scenes: that needs a transcript (see docs/video.md).
"""
import re, subprocess, sys

picture, voice, music, out = sys.argv[1:5]
music_at = float(sys.argv[5]) if len(sys.argv) > 5 else 2.1

def probe(path):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                          "-of", "csv=p=0", path]).decode())

length, voice_len = probe(picture), probe(voice)
log = subprocess.run(["ffmpeg", "-hide_banner", "-i", voice, "-af", "silencedetect=noise=-38dB:d=0.35",
                      "-f", "null", "-"], capture_output=True, text=True).stderr
starts = [float(x) for x in re.findall(r"silence_start: ([0-9.]+)", log)]
ends = [float(x) for x in re.findall(r"silence_end: ([0-9.]+)", log)]
# Speech is whatever lies between silences.
edges = sorted([(s, "s") for s in starts] + [(e, "e") for e in ends])
phrases, cursor = [], 0.0
for t, kind in edges:
    if kind == "s":
        if t - cursor > 0.15: phrases.append((cursor, t))
    else:
        cursor = t
if voice_len - cursor > 0.15: phrases.append((cursor, voice_len))

pad = 0.07
spoken = sum(b - a for a, b in phrases) + 2 * pad * len(phrases)
lead, tail = 0.35, 0.9
gap = max(0.12, (length - lead - tail - spoken) / max(1, len(phrases) - 1))
parts, labels, at = [], [], lead
for i, (a, b) in enumerate(phrases):
    a, b = max(0, a - pad), min(voice_len, b + pad)
    ms = int(at * 1000)
    parts.append(f"[1:a]atrim={a:.3f}:{b:.3f},asetpts=PTS-STARTPTS,afade=t=in:d=0.03,"
                 f"afade=t=out:st={b - a - 0.05:.3f}:d=0.05,adelay={ms}|{ms}[p{i}]")
    labels.append(f"[p{i}]")
    at += (b - a) + gap
fade = max(0, length - 2.1)
graph = ";".join(parts) + ";" + "".join(labels) + \
    f"amix=inputs={len(labels)}:normalize=0,loudnorm=I=-15:TP=-2:LRA=7,asplit[v1][v2];" \
    f"[2:a]afade=t=in:d=0.35,afade=t=out:st={fade:.2f}:d=2.1,volume=0.5[m];" \
    f"[m][v1]sidechaincompress=threshold=0.02:ratio=9:attack=15:release=350[duck];" \
    f"[duck][v2]amix=inputs=2:normalize=0,alimiter=limit=0.89[a]"
subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-i", picture, "-i", voice, "-ss", str(music_at),
                       "-i", music, "-filter_complex", graph, "-map", "0:v", "-map", "[a]", "-c:v", "copy",
                       "-c:a", "aac", "-b:a", "192k", "-t", str(length), "-movflags", "+faststart", out])
print(f"{len(phrases)} phrases, {spoken:.1f} s of speech, {gap:.2f} s between them, voice ends at {at - gap:.1f} of {length:.1f} s")
print("wrote", out)
