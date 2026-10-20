# EarShare launch posts (drafts)

## Show HN

**Title** (≤ 80 chars):

> Show HN: EarShare – Play your Mac's audio on two AirPods at once

**URL:** https://github.com/pazaricha/EarShare

**First comment** (post right after submitting):

> Hi HN. Our kids go to sleep around 8, and that's when my partner and I want to watch something. The TV wakes them up, and macOS will only route sound to one pair of Bluetooth headphones at a time.
>
> macOS can actually do this: Audio MIDI Setup lets you build a "Multi-Output Device". But that takes a dozen clicks every time, and the combined device has no volume control. One of us always ends up with it too loud.
>
> EarShare is a small menu-bar app that does it for you. Tick two or more outputs, click "Share sound", and each one gets its own volume slider. Stop puts your old output back.
>
> How it works, for the curious:
> - It creates a *stacked* CoreAudio aggregate device (`kAudioAggregateDeviceIsStackedKey`) with drift compensation on every device except the clock master, and sets it as the default output.
> - Volume is set on each real device (`VirtualMainVolume`), not on the aggregate, which is why separate sliders work.
> - Two gotchas that cost me time. A *private* aggregate (`IsPrivateKey = 1`) is accepted without error but can never become the system default. And including a virtual loopback device (Zoom, Teams) quietly makes the whole aggregate non-default-able, so the app filters on `kAudioDevicePropertyDeviceCanBeDefaultDevice`.
>
> It's about 400 lines of Swift with no dependencies, built with just the Command Line Tools. MIT licensed.
>
> Known limits: it's not notarized yet (there's a one-time "Open Anyway" step). If anything uses an AirPods mic, that pair drops to call-quality audio. Bluetooth devices can drift a few ms apart.
>
> Happy to answer questions, and PRs are welcome.

---

## LinkedIn

> 🍿 Our kids fall asleep. Movie time. Except the TV wakes them up.
>
> So my partner and I wanted to watch on the laptop with headphones, both of us. Turns out your Mac will only play sound on one pair of AirPods at a time.
>
> So I built EarShare 🎧
>
> It's a tiny free Mac app that plays your audio on two (or more) AirPods, headphones or speakers at the same time, and each person gets their own volume slider. One click to start, one click to stop.
>
> I built it in one evening, pairing with Claude Code: research, a plan, then two AI agents writing the audio engine and the UI in parallel while I reviewed and debugged. The icon and artwork were AI-generated too. It's a good example of how small the gap between "I wish this existed" and "it's on GitHub" has become.
>
> It's open source (MIT). Grab it here 👇
> https://github.com/pazaricha/EarShare
>
> Parents of light sleepers: this one's for you. 😴
>
> #macOS #OpenSource #Parenting #BuildInPublic #AI

**Image:** `marketing/bed-linkedin.png` (1200×627)

---

## Product Hunt

**Name:** EarShare
**Tagline** (≤ 60 chars): `Movie night on two AirPods while the kids sleep`
**Links:** https://github.com/pazaricha/EarShare (Website + Download → latest release)
**Pricing:** Free · Open source
**Topics:** Mac, Parenting, Open Source, Audio
**Thumbnail:** `marketing/producthunt/thumbnail.png` (240×240)
**Gallery** (1270×760, in order): `marketing/producthunt/1-hero.png`, `2-share.png`, `3-volume.png`, `4-bed.png`, `5-connect.png`
**Video music credit** (put in the YouTube description): Music: "And So It Begins" by Artificial.Music (CC BY)
**Video:** upload `marketing/video/earshare-howto.mp4` to YouTube (unlisted is fine) and paste the link. Product Hunt only accepts YouTube/Loom links.

**Description** (≤ 260 chars):
> Your Mac plays sound to one pair of AirPods at a time. EarShare plays it to two (or more) at once, with a volume slider for each person. Connect, tick, share: three steps in your menu bar. Free and open source.

**Maker's first comment:**
> Hey Product Hunt 👋
>
> Our kids go to bed at 8, and that's our movie time. The TV wakes them up, and a Mac only plays sound to one pair of headphones at a time. So one of us always lost.
>
> EarShare fixes that. Click the 🍿 in your menu bar:
> 1️⃣ Connect both pairs of AirPods
> 2️⃣ Tick who's listening
> 3️⃣ Share sound, and each of you sets your own volume
>
> It works with any mix of AirPods, Bluetooth headphones and speakers. There are no drivers or accounts, and it's free and open source (MIT).
>
> One honest note: it isn't notarized by Apple yet, so the first launch needs a one-time "Open Anyway" in System Settings.
>
> I'd love to hear what you'd use it for. Long flights on a laptop? Two people on one Mac in a library? Tell me!
