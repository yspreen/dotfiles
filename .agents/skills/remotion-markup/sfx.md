---
name: sfx
description: Including sound effects
metadata:
  tags: sfx, sound, effect, audio
---

To include a sound effect, use the `<Audio>` tag:

```tsx
import { Audio } from "@remotion/sfx";

<Audio src={"https://remotion.media/whoosh.wav"} />;
```

The following sound effects are available:

- `https://remotion.media/whoosh.wav`
- `https://remotion.media/whip.wav`
- `https://remotion.media/page-turn.wav`
- `https://remotion.media/switch.wav`
- `https://remotion.media/mouse-click.wav`
- `https://remotion.media/shutter-modern.wav`
- `https://remotion.media/shutter-old.wav`
- `https://remotion.media/ding.wav`
- `https://remotion.media/bruh.wav`
- `https://remotion.media/vine-boom.wav`
- `https://remotion.media/windows-xp-error.wav`
- `https://remotion.media/fah.wav`
- `https://remotion.media/spongebob-fail.wav`
- `https://remotion.media/omg-hell-nah.wav`
- `https://remotion.media/price-is-right-fail.wav`
- `https://remotion.media/romance-meme.wav`
- `https://remotion.media/bone-crack.wav`
- `https://remotion.media/anime-wow.wav`
- `https://remotion.media/yippee.wav`
- `https://remotion.media/loading-lag.wav`
- `https://remotion.media/wilhelm-scream.wav`
- `https://remotion.media/mac-quack.wav`
- `https://remotion.media/skedaddle.wav`
- `https://remotion.media/snapchat-notification.wav`
- `https://remotion.media/nelly-ahh.wav`
- `https://remotion.media/sanctuary-guardian-what.wav`
- `https://remotion.media/minecraft-hurt.wav`
- `https://remotion.media/oh-my-god-vine.wav`
- `https://remotion.media/illuminati-confirmed.wav`
- `https://remotion.media/dramatic-boomer.wav`
- `https://remotion.media/triggered.wav`
- `https://remotion.media/record-scratch.wav`

For more sound effects, search the internet. A good resource is https://github.com/kapishdima/soundcn/tree/main/assets.

## Generate a basic local kit

Only generate sound effects when the user requested audio and suitable assets are unavailable. Run the included dependency-free generator with an explicit output directory:

```bash
node /absolute/path/to/remotion-markup/scripts/generate-basic-sfx.mjs public/sfx
```

It creates `whoosh.wav`, `click.wav`, and `impact.wav`. It refuses to overwrite existing files. Preview the sounds and adjust their timing and volume for the composition instead of treating them as defaults.
