# Synthesizes a soft music-box Brahms' Lullaby (public-domain melody, 1868) -> marketing/video/lullaby.wav
import os, wave
import numpy as np

SR, BPM = 44100, 72
BEAT = 60 / BPM
N = {"C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00, "A4": 440.00, "B4": 493.88, "C5": 523.25}
# (note, beats); played an octave up for the music-box sound
MELODY = [("E4", .5), ("E4", .5),
          ("G4", 2), ("E4", .5), ("E4", .5), ("G4", 2), ("E4", .5), ("G4", .5),
          ("C5", 1), ("B4", 1.5), ("A4", .5), ("A4", 1), ("G4", 1), ("D4", .5), ("E4", .5),
          ("F4", 1), ("D4", 1), ("D4", .5), ("E4", .5), ("F4", 2), ("D4", .5), ("F4", .5),
          ("B4", .5), ("A4", .5), ("G4", 1), ("B4", 1), ("C5", 2), ("C4", .5), ("C4", .5),
          ("C5", 2), ("A4", .5), ("F4", .5), ("G4", 2), ("E4", .5), ("C4", .5),
          ("F4", 1), ("G4", 1), ("A4", 1), ("G4", 2), ("C4", .5), ("C4", .5),
          ("C5", 2), ("A4", .5), ("F4", .5), ("G4", 2), ("E4", .5), ("C4", .5),
          ("F4", 1), ("E4", 1), ("D4", 1), ("C4", 3)]

def pluck(freq, secs):
    t = np.arange(int(SR * secs)) / SR
    env = np.exp(-t * 3.2) * np.minimum(1, t / 0.004)
    # music-box timbre: fundamental + slightly inharmonic overtones that die fast
    tone = np.sin(2*np.pi*freq*t) + .35*np.sin(2*np.pi*freq*2.01*t)*np.exp(-t*6) + .12*np.sin(2*np.pi*freq*3.98*t)*np.exp(-t*10)
    return tone * env

total = sum(b for _, b in MELODY) * BEAT + 3
out = np.zeros(int(SR * total))
pos = 0.0
for note, beats in MELODY:
    s = pluck(N[note] * 2, 2.5)
    i = int(pos * SR); out[i:i + len(s)] += s[:len(out) - i]
    pos += beats * BEAT
for delay, gain in [(.13, .35), (.29, .22), (.47, .12)]:  # cheap room reverb
    d = int(delay * SR); out[d:] += gain * out[:-d].copy()
out = out / np.abs(out).max() * 0.7
pcm = (out * 32767).astype(np.int16)
path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "marketing/video/lullaby.wav")
with wave.open(path, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print(path, f"{total:.1f}s")
