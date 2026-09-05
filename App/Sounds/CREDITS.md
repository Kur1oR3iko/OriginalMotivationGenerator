# Sound effects

- `page.mp3`, `send.wav`: supplied by Kurio, copied unchanged from the repository root.
- `click.wav`: Kurio's `click.ogg`, decoded to 16-bit PCM WAV with its original stereo channels and sample rate.
- `tick.wav`: `Audio/tick_001.ogg` from Kenney's **Interface Sounds (1.0)**, decoded to 16-bit PCM WAV. Played at 25% volume.

Kenney source: https://kenney.nl/assets/interface-sounds

License: Creative Commons Zero (CC0), permitting personal and commercial use. The original license is preserved in `Kenney-LICENSE.txt`.

The page effect plays at 1.6× speed so it finishes before the next 0.5-second automatic phrase refresh. The other sounds use their original speed. Each effect restarts on a new trigger rather than accumulating overlapping copies.
