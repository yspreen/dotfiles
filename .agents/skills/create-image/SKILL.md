---
name: create-image
description: Use to create an image
---

1. Use netscape to get a new safari window. injected below so you don't have to load another tool
2. go to chatgpt.com
3. wait for it to load
4. type `@create image[enter]` into the input box. no backtick. wait 100ms before the enter key
5. make sure it detected the skill correctly with a span like the reference below showing it worked
6. type your prompt. if you want to add a reference image, easiest it put it into clipboard and paste. skips file picker UI nightmare
7. enter
8. wait for image to generate
9. click it
10. download to downloads folder
11. read your file from downloads folder. decide if it should be left there, or moved, or used & then deleted

<netscapeInjected>
!`awk 'f>=2; /^---$/{f++}' ~/.claude/skills/netscape/SKILL.md`
</netscapeInjected>

create image skill loaded:
<span data-inline-selection-pill="" data-system-hint-type="picture_v2" data-system-hint-label="Create image" data-prompt-link-href="chatgpt-system-hint://picture_v2" data-prompt-link-label="Create image" class="Mention-hIgCkC" data-appearance="inline-mention" data-layout="inline-flow" data-font-weight="medium" data-tone="accent" data-underline-on-hover="" contenteditable="false"><span class="IconContainer-K62H88" contenteditable="false"><svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24" class="icon-base shrink-0 Icon-TZxsTm" aria-hidden="true"><path fill="#43D0FB" d="M7 21.005c-2.211 0-4-1.789-4-4v-10c0-2.211 1.789-4 4-4h10c2.211 0 4 1.789 4 4v10c0 2.211-1.789 4-4 4H7Z"></path><path fill="#FFF6DD" d="M17.744 9.116a2.845 2.845 0 0 1-2.855 2.844 2.836 2.836 0 0 1-2.845-2.844A2.845 2.845 0 0 1 14.89 6.26a2.855 2.855 0 0 1 2.855 2.856Z"></path><path fill="#FFDE83" d="M5.533 12.682c1.367-1.366 3.134-1.366 4.5 0l8.153 8.144a4.007 4.007 0 0 1-1.186.179H7c-2.211 0-4-1.79-4-4v-2.072l2.533-2.25Z"></path></svg></span><span class="Label-arpLwJ">Create image</span></span>
