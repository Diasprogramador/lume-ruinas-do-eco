"""Render Lume's original loopable score and attack sounds, using only Python stdlib."""
from array import array
from pathlib import Path
import math
import random
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
TAU = math.tau


def frequency(note):
    return 440 * 2 ** ((note - 69) / 12)


def write(name, left, right=None):
    channels = 2 if right is not None else 1
    peak = max(max(abs(v) for v in left), max(abs(v) for v in right) if right else 0)
    scale = 0.72 / max(peak, 0.001) if right is not None else min(1, 0.88 / max(peak, 0.001))
    pcm = array("h")
    for i, value in enumerate(left):
        pcm.append(int(value * scale * 32767))
        if right is not None:
            pcm.append(int(right[i] * scale * 32767))
    with wave.open(str(OUT / (name + ".wav")), "wb") as output:
        output.setnchannels(channels)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    rms = math.sqrt(sum(v * v for v in left) / len(left))
    print(f"{name}: {len(left)/RATE:.2f}s, peak={peak:.3f}, RMS={rms:.4f}", flush=True)


def score(name, bpm, bars, battle=False):
    beat = 60 / bpm
    length = int(bars * 4 * beat * RATE)
    left, right = array("f", [0]) * length, array("f", [0]) * length
    chords = [(50, 57, 62, 64), (46, 53, 57, 60), (48, 55, 60, 64), (45, 52, 57, 60)]
    rng = random.Random(718)

    def note(start, duration, midi, amp, instrument="pad", pan=0):
        start = int(start * RATE)
        count = int(duration * RATE)
        hz = frequency(midi)
        for i in range(count):
            t = i / RATE
            if instrument == "pad":
                envelope = math.sin(math.pi * i / count) ** 1.2
                value = (math.sin(TAU * hz * t) + 0.25 * math.sin(TAU * hz * 2 * t)
                         + 0.12 * math.sin(TAU * hz * 1.003 * t)) * envelope * amp
            elif instrument == "bell":
                envelope = min(1, t * 100) * math.exp(-t * 2.7)
                value = (math.sin(TAU * hz * t) + 0.28 * math.sin(TAU * hz * 2.76 * t)
                         + 0.1 * math.sin(TAU * hz * 4.2 * t)) * envelope * amp
            elif instrument == "bass":
                envelope = min(1, t * 6) * min(1, (duration-t) * 3)
                value = (math.sin(TAU * hz * t) + 0.15 * math.sin(TAU * hz * 2 * t)) * amp * envelope
            else:
                envelope = math.exp(-t * 12) * min(1, t * 300)
                value = math.sin(TAU * (60 * t + 2 * (1-math.exp(-t*20)))) * amp * envelope
                value += rng.uniform(-1, 1) * amp * 0.15 * math.exp(-t * 30)
            index = (start + i) % length
            l, r = value * (1-pan) * 0.7, value * (1+pan) * 0.7
            left[index] += l
            right[index] += r
            if instrument == "bell":
                left[(index + int(beat * 0.75 * RATE)) % length] += r * 0.26
                right[(index + int(beat * 1.5 * RATE)) % length] += l * 0.17

    melody = [74, 76, 77, 81, 79, 77, 76, 72, 74, 69, 72, 76, 74, 72, 69, 67]
    for bar in range(bars):
        chord = chords[bar % 4]
        start = bar * 4 * beat
        for voice, pitch in enumerate(chord):
            note(start, 5 * beat, pitch, 0.045 if battle else 0.033, pan=(voice-1.5)*0.22)
        note(start, 3.8 * beat, chord[0]-12, 0.045, "bass")
        steps = 8 if battle else 4
        for step in range(steps):
            pitch = chord[(step + bar) % 4]+12
            note(start+step*4*beat/steps, 1.8*beat, pitch, 0.075 if battle else 0.063,
                 "bell", pan=math.sin(step*1.2)*0.5)
        if not battle:
            note(start+beat, 2.6*beat, melody[bar%len(melody)], 0.055, "bell", pan=0.15)
        else:
            for pulse in [0, 1.5, 2, 3]:
                note(start+pulse*beat, 0.35, 40, 0.11 if pulse in [0,2] else 0.055, "drum")
    write(name, left, right)


def effect(name, duration, kind, seed):
    rng = random.Random(seed)
    values = array("f")
    phase = 0.0
    filtered = 0.0
    for i in range(int(duration * RATE)):
        t = i / RATE
        u = t / duration
        noise = rng.uniform(-1, 1)
        filtered += 0.24 * (noise-filtered)
        attack = min(1, t*200)
        if kind == "swing":
            envelope = math.sin(math.pi*u)**1.8
            value = filtered*envelope*0.8 + noise*envelope*0.08
        elif kind in ("hit", "heavy", "impact"):
            hz = {"hit":170, "heavy":100, "impact":72}[kind]
            phase += TAU*(hz*(1-u)+35)/RATE
            value = math.sin(phase)*math.exp(-u*6)*0.65
            value += noise * math.exp(-u*16)*0.25
            value += math.sin(TAU*1750*t)*math.exp(-u*12)*0.12
        elif kind in ("magic", "ascend", "dive"):
            hz = 240+u*850 if kind != "dive" else 760-u*650
            phase += TAU*hz/RATE
            value = (math.sin(phase)*0.32 + math.sin(phase*1.5)*0.18 + filtered*0.2)*(1-u)**1.4
        elif kind == "charge":
            phase += TAU*(220+u*700)/RATE
            value = math.sin(phase)*math.sin(TAU*8*t)*math.sin(math.pi*u)*0.25
        elif kind in ("seed", "shrine", "ui", "purchase"):
            hz = {"seed":880,"shrine":330,"ui":700,"purchase":660}[kind]
            value = (math.sin(TAU*hz*t)*0.3 + math.sin(TAU*hz*1.5*t)*0.15 +
                     math.sin(TAU*hz*2*t)*0.1)*math.exp(-u*5)
        elif kind == "hurt":
            value = (math.sin(TAU*(110*t-35*t*t))*0.5+filtered*0.3)*math.exp(-u*6)
        else:
            phase += TAU*(400+u*300)/RATE
            value = (math.sin(phase)*0.4+filtered*0.2)*math.sin(math.pi*u)
        values.append(value*attack)
    write(name, values)


if __name__ == "__main__":
    score("gardens", 72, 16)
    score("guardian", 108, 8, battle=True)
    specs = [("swing",.18),("hit",.17),("heavy",.42),("impact",.5),
             ("magic",.42),("ascend",.55),("dive",.4),("charge",.25),
             ("seed",.28),("shrine",.9),("ui",.1),("purchase",.55),
             ("hurt",.3),("jump",.14),("dash",.16)]
    for i, (name, duration) in enumerate(specs):
        effect(name, duration, name, 400+i)
