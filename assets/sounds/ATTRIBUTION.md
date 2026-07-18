# Lobby sound assets — provenance

**2026-07-16** · Original CC0 1.0 for this repo (not Kenney/third-party).  
**Reproduce:** `python scripts/generate_lobby_sounds.py` (deterministic; do not
regen unless SHA-256 below stay identical — PR2E temp-dir verified).  
**Format:** mono PCM16 @ 44.1 kHz; sample-peak normalize to **-1.5 dBTP**.

| File | Synthesis (`scripts/generate_lobby_sounds.py`) |
|---|---|
| click_1.wav | sine 880 Hz, 80 ms |
| click_3.wav | sine 220 Hz, 100 ms |
| rollover_2.wav | sweep 400→700 Hz, 140 ms |
| rollover_5.wav | sweep 900→1600 Hz, 120 ms |
| switch_1.wav | square 660 Hz, 60 ms |
| switch_7.wav | falling chirp, 180 ms |
| switch_19.wav | 1200/1800/2700 Hz partials, 200 ms |
| switch_32.wav | dual beep + LCG noise, 160 ms |

## Loudness (honest)

Design −18 LUFS-I is not meaningful for 60–200 ms UI clicks. Measured peak −1.50
dBFS (all); RMS −4.51…−13.21 dBFS; `ffmpeg ebur128` I≈−70 LUFS\* (clips ≪ R128
gating). True-peak may exceed sample peak on square/noise. Perceived parity =
manual QA. Cmd: `ffmpeg -nostats -i <wav> -filter_complex ebur128=peak=true -f null -`

## Audio policy

Keep `respectSilence: true` (silent-mode preference). `AudioContextConfig` cannot
combine it with `mixWithOthers`; background mix out of scope. No behavior change
without evidence.

SHA-256: a460627c9c71aa274b77c2912923a306b93e4f9bd310d47ed85938cc6ed20cbe click_1.wav · d9808d197539fd84d0f409cc311904c9a23f1fe89f8012cace36cfe749a816b4 click_3.wav · 29c5f7883dba13cb46f1e8f287f3af48982c8a267cd676a3d26bf1c8c4503900 rollover_2.wav · 9ec32d5fbaf7e03ee60af00fa366f5082f4ec3fd636b08b84860df54edacdc20 rollover_5.wav · 9eff32a4bd9d40aa7a552da9a62c786906fad06829693ebb3ca266b90121300c switch_1.wav · 7b7583825c43dee1ad096e84c5a1de416e9d67c0ceeacfe0174710de0a7755ca switch_7.wav · 507b0cc5eeec8f08451d4baf585510109b5e1b6e620479292fb291660c9fedda switch_19.wav · 31ed0e84e938e76810ac09af9b7032a1d295d4faf70b51ef950956ff3efb5e71 switch_32.wav
