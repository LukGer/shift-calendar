#!/usr/bin/env python3
"""Turns the downloaded source recordings into the Tones in ShiftAlarm/Tones.

AlarmKit plays a named sound of under 30 seconds and may not loop it, so each Tone fills about 28 seconds
with its recording, cut so that playing it again from the start continues without a jump. Each is
high-passed, mixed to mono, brought to the same loudness under a peak limiter, and saved as IMA4 .caf.

The sources are Pixabay downloads (Pixabay Content License), kept out of the repo because the licence
forbids redistributing them on their own:
  birdsong.mp3     "Beautiful Birdsong 8" by audiopapkin, Pixabay 303721
  kalimba.mp3      "Pedalling Away (Kalimba)" by swantwirls, Pixabay 289940
  cheerful.mp3     "Happy Loop" by birdfish (freesound_community), Pixabay 6199
  alarm-clock.mp3  "Clock Alarm" by microsammy, Pixabay 8762

Run from the repo root on a Mac with ffmpeg: scripts/prepare-tones.py <directory with the sources>
"""

import array
import json
import os
import subprocess
import sys
import tempfile

RATE = 44100
LOUDNESS = -16.0
FADE_IN = 2.0
OUT = os.path.join(os.path.dirname(__file__), "..", "ShiftAlarm", "Tones")


def decode(path):
    """Mono float samples, with the rumble a phone speaker can't play removed."""
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-af", "highpass=f=60", "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
        capture_output=True, check=True).stdout
    return array.array("f", raw).tolist()


def filtered(samples, filters):
    """The samples through an ffmpeg audio filter chain."""
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
         "-af", filters, "-f", "f32le", "-"],
        input=array.array("f", samples).tobytes(), capture_output=True, check=True).stdout
    return array.array("f", raw).tolist()


def at(seconds):
    return round(seconds * RATE)


def cut(samples, start, end):
    return samples[at(start):at(end)]


def faded(samples, fade_in=0.005, fade_out=0.005):
    """Short fades so a cut never clicks."""
    samples = list(samples)
    for i in range(at(fade_in)):
        samples[i] *= i / at(fade_in)
    for i in range(at(fade_out)):
        samples[-1 - i] *= i / at(fade_out)
    return samples


def joined(*parts):
    return [sample for part in parts for sample in part]


def folded_loop(samples, start, period, repeats, tail):
    """`repeats` periods from `start`, with the ringing-out after the last folded onto the first,
    so the loop runs on without a gap."""
    loop = cut(samples, start, start + period * repeats)
    ringing_out = cut(samples, start + period * repeats, start + period * repeats + tail)
    for i, sample in enumerate(ringing_out):
        loop[i] += sample
    return loop


def crossfaded_loop(samples, start, length, crossfade):
    """`length` seconds from `start`, whose end fades into its start."""
    loop = cut(samples, start, start + length)
    after = cut(samples, start + length, start + length + crossfade)
    for i, sample in enumerate(after):
        fade = i / len(after)
        loop[i] = loop[i] * fade + sample * (1 - fade)
    return loop


def birdsong(samples):
    return faded(crossfaded_loop(samples, start=0.5, length=28.0, crossfade=1.5), fade_in=FADE_IN)


def kalimba(samples):
    """The whole piece, then its opening again, fading out before the strum at 10.9 seconds.
    Its metallic attack around 3 kHz and its highs are tamed, which sound harsh on a phone speaker."""
    samples = filtered(samples, "equalizer=f=3200:t=q:w=1:g=-6,highshelf=f=6000:g=-6")
    piece = cut(samples, 0.85, 17.95)
    opening = faded(cut(samples, 0.85, 10.8), fade_out=0.25)
    return faded(joined(piece, opening), fade_in=FADE_IN)


def cheerful(samples):
    """Repeats every 4 seconds; seven periods fill 28 seconds."""
    loop = folded_loop(samples, start=0.03, period=4.0, repeats=4, tail=2.0)
    return faded(joined(loop, loop[:at(12.0)]), fade_in=FADE_IN)


def alarm_clock(samples):
    """Builds up, then rings once a second; the build-up plays once and the ring repeats.
    The cut-off ring at the very end of the recording is left out. Its build-up starts quietly, so it needs no fade-in."""
    build_up = cut(samples, 0.0, 12.5)
    ring = faded(cut(samples, 11.5, 12.5))
    return joined(build_up, *[ring] * 16)


TONES = {"birdsong": birdsong, "kalimba": kalimba, "cheerful": cheerful, "alarm-clock": alarm_clock}


def integrated_loudness(path):
    report = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "loudnorm=print_format=json", "-f", "null", "-"],
        capture_output=True, text=True, check=True).stderr
    return float(json.loads(report[report.rindex("{"):report.rindex("}") + 1])["input_i"])


def write(name, samples, directory):
    assert len(samples) < at(29.0), f"{name} is {len(samples) / RATE:.1f} s; AlarmKit needs under 30 s"
    raw = os.path.join(directory, f"{name}.f32")
    with open(raw, "wb") as file:
        array.array("f", samples).tofile(file)
    source = ["-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", raw]
    plain = os.path.join(directory, f"{name}-plain.wav")
    subprocess.run(["ffmpeg", "-v", "error", "-y", *source, plain], check=True)
    gain = LOUDNESS - integrated_loudness(plain)
    wav = os.path.join(directory, f"{name}.wav")
    subprocess.run(["ffmpeg", "-v", "error", "-y", *source,
                    "-af", f"volume={gain}dB,alimiter=limit=0.84:attack=1:release=50:level=false",
                    "-c:a", "pcm_s16le", wav], check=True)
    caf = os.path.join(OUT, f"{name}.caf")
    subprocess.run(["afconvert", "-f", "caff", "-d", "ima4", "-c", "1", wav, caf], check=True)
    print(f"{name}.caf  {len(samples) / RATE:.1f} s  {gain:+.1f} dB")


if __name__ == "__main__":
    sources = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as directory:
        for name, prepare in TONES.items():
            write(name, prepare(decode(os.path.join(sources, f"{name}.mp3"))), directory)
