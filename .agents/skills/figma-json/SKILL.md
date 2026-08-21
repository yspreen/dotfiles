---
name: Figma JSON
description: Turn the copied Figma component into parsable json.
---

Run `/Users/user/Documents/proj/figmajson/run.sh`.

Image bytes are omitted by default. Image fills include a note telling the user to rerun with
`--b64-images`. When base64 image data is requested, run
`/Users/user/Documents/proj/figmajson/run.sh --b64-images`.

For hash-only image fills, `--b64-images` resolves bytes from the Figma desktop disk cache by exact
SHA-1 match. It exits with an error if any image cannot be resolved. A successful JSON response
therefore contains base64 for every image in its top-level `images` array.

Never open or automate the Figma app. Never replace or modify clipboard contents. The script may
read the current clipboard.
