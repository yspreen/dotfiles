---
name: remotion-render
description: Use when exporting a Remotion composition as a video or still, including transparent output. Do not use for Studio previews, embedded Players, or rendering infrastructure in apps.
version: 4.0.514
---

## General rendering strategy

Render a video using:

```
npx remotion render
```

Full list of options: https://www.remotion.dev/docs/cli/render.md

Render a still using:

```
npx remotion still
```

Full list of options: https://www.remotion.dev/docs/cli/still.md

## Visual verification

After a requested render, inspect the output instead of relying only on a successful CLI exit:

1. Pick frames covering each scene, transition, and dense text layout.
2. Render those exact frames with `npx remotion still <composition-id> --frame=<frame> --overwrite`.
3. Inspect the images for overflow, unsafe margins, accidental wrapping, low contrast, stale layers, and bad transition states.
4. Fix the source, render again, and repeat until the inspected frames are clean.

Also spot-check the encoded video when timing, audio sync, or compression matters. Do not expand a preview-only request into a full render.

## Transparent videos

See [Transparent videos](./transparent-videos.md) for rendering out a video with transparency.
