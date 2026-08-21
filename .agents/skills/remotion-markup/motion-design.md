# Motion design

Use this guidance for promos, intros, reels, logo motion, and requests to make an existing composition feel less flat or generic. Match the user's brand and intended energy. A restrained explainer may need fewer effects than a launch promo.

## Diagnose the frame

- Weak hierarchy: choose one focal element. Separate it through scale, position, contrast, or motion.
- Fade-only entrances: when the brief calls for energy, combine opacity with a small translation or scale change.
- Simultaneous entrances: stagger related items by a few frames so the eye knows where to look first.
- Constant motion: add holds after important reveals. Viewers need still frames to read and register changes.
- Flat depth: add one subtle device such as a gradient, shadow, texture, foreground overlap, or parallax. Do not stack effects without a reason.
- Static footage or stills: animate the crop only when it supports the subject. Keep faces, products, and UI details in frame.
- Weak ending: give the payoff or call to action its own visual beat.

## Pace the sequence

- Establish subject or claim early in short promos.
- Alternate movement with readable holds. Do not make every layer move continuously.
- Time changes to narration phrases, musical beats, edits, or changes in meaning.
- Let exits finish before unrelated entrances compete for attention. Overlap only when the transition benefits from it.
- Express timing from `fps` so intent survives frame-rate changes.
- Preview the whole sequence. A good still does not prove good pacing.

## Motion patterns

Choose patterns based on the shot instead of applying all of them:

- Entrance: opacity plus a short `translate` or subtle perceptual `scale` animation.
- Stagger: offset repeated items in reading order. Keep the interval small enough that the group still feels connected.
- Hold and exit: clamp the entrance, leave a readable hold, then use a shorter exit when the desired pace is brisk.
- Emphasis: animate one word, number, underline, or graphic accent rather than every element.
- Counter: use tabular numerals and animate only when the changing value carries meaning.
- Parallax: move foreground and background at different rates when the artwork has clear depth.
- Image move: use a slow crop, pan, or scale for a still when it improves composition. Static images are valid.
- Transition: hide a cut with motion, masking, or matched geometry when a direct cut is not stronger.

Keep `interpolate()` calls and editable values inline. Use `scale`, `translate`, and `rotate` instead of a combined `transform` when Studio interactivity matters. Follow [Remotion Interactivity](../remotion-interactivity/SKILL.md).

## Theme template

Copy [assets/motion-theme.ts](assets/motion-theme.ts) into the project and replace its sample values with the user's brand. The template centralizes reusable colors, fonts, spacing, and radii. Values referenced through a theme are not directly editable as inline Studio values, so inline a value when Studio editing takes priority.

## Safe zones and overflow

Follow [video layout rules](../remotion-create/video-layout.md). Use [text measurement](measuring-text.md) for dynamic or user-provided copy. Check representative frames with the longest expected strings and every target aspect ratio.

## Visual inspection loop

1. Preview the complete sequence for pacing and transition timing.
2. Render representative stills from each scene and transition.
3. Inspect hierarchy, margins, overflow, wrapping, contrast, crop, layer order, and animation endpoints.
4. Fix problems and repeat the same checks.

Render the full video only when the user requested an export. Follow [Remotion Render](../remotion-render/SKILL.md) for final-output verification.
