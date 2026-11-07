---
name: scan-to-pdf
description: Turn a photo of a paper document (or the clipboard image) into a small, high-contrast, searchable scan PDF on macOS. Use when asked to "scan", "make a scan PDF", "clean up this photo of a document", or optimize a document image for contrast, legibility or file size.
---

# Scan to PDF

`scan.swift` (next to this file) does the whole pipeline with built-in macOS frameworks plus ImageMagick:

1. **Crop + flatten**: Vision `VNDetectDocumentSegmentationRequest` finds the page quad, `CIPerspectiveCorrection` removes the camera angle and background.
2. **Whiten**: `CIDocumentEnhancer` evens out lighting.
3. **Contrast**: `CIToneCurve` maps everything lighter than ~0.8 to pure white (kills bleed-through from sheets underneath) and darkens ink. Colored ink (blue pen, red stamps) is kept.
4. **Size**: ImageMagick quantizes to 8 colors, no dithering. Smaller than JPEG and has no ringing around text.
5. **Searchable**: Vision OCR (`ja-JP`, `en-US`, accurate) writes an invisible text layer.
6. Page width is A4 (595 pt); height follows the page aspect.

## Run

```sh
swift ~/.claude/skills/scan-to-pdf/scan.swift <input-image> <output.pdf>
```

Requires `magick` on PATH (`brew install imagemagick`). Prints the OCR line count. First run compiles, takes ~30 s.

Clipboard input: check `osascript -e 'clipboard info'` first. If it has `«class PNGf»` or `TIFF`, save it:

```sh
osascript -e 'set f to open for access POSIX file "/tmp/clip.png" with write permission' \
  -e 'write (the clipboard as «class PNGf») to f' -e 'close access f'
```

If the clipboard only has text, use the image attached to the chat instead and tell the user.

## Verify

Always look at the result before reporting:

```sh
qlmanage -t -s 1400 -o /tmp out.pdf   # then Read /tmp/out.pdf.png
swift -e 'import PDFKit; print(PDFDocument(url: URL(fileURLWithPath: "out.pdf"))!.string!)'
```

Check that:
- the crop is the top sheet only, not the table or a stack of sheets
- no gray ghost text is left from the back side or the sheet below
- thin lines and small print survived the threshold
- handwriting color is still distinct

Expect ~150 KB for a phone photo of one A4 page. Reference result: 5.1 MB PNG became 150 KB.

## Tuning

- **Ghost text still visible**: lower `inputPoint3` x (0.8 to 0.75).
- **Faint pencil or thin lines vanish**: raise it (0.8 to 0.85), or raise `inputPoint2` y.
- **Gray fills in diagrams disappear**: expected with this curve. If they matter, use `-colors 16` and point3 x 0.88.
- **Pure black text, no colored ink**: add `-colorspace Gray -colors 4` to the magick args for an even smaller file.
- **Wrong crop**: segmentation picked a different sheet. Crop the input roughly first (`magick in.png -crop WxH+X+Y`), then rerun.
- **OCR languages**: edit `recognitionLanguages`. The invisible-text font is Hiragino, which covers Latin and CJK.

## Multiple pages

Run once per image, then merge:

```sh
swift -e 'import PDFKit; let o = PDFDocument(); for (i, p) in CommandLine.arguments.dropFirst(2).enumerated() { o.insert(PDFDocument(url: URL(fileURLWithPath: p))!.page(at: 0)!, at: i) }; o.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))' merged.pdf p1.pdf p2.pdf
```

## Avoid

- **Adobe Acrobat via computer use**: its UI ignores synthetic clicks (`AXError.notImplemented`) from both computer-use backends. Scan & OCR may also be paywalled on trial installs.
- **Preview**: can make a PDF, but has no perspective correction or background cleanup.
- **JPEG embedding**: about 2x larger at the same legibility, and blocky around strokes.
