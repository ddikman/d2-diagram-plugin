# Class diff (what a refactoring PR moves)

One board holds the classes a refactor touches. What the PR removes pulses red, then what it adds
pulses green, and every class and arrow stays in place. Draw it when a PR moves fields, methods or
references between classes and the reader asks which members and arrows changed. A new design is
a plain class diagram; changed behaviour is a sequence or flow diagram.

You write a JSON spec. `scripts/class-diff.py` turns it into the `.d2`, renders it, animates the
SVG and screenshots both phases. Colours, member order, quoting and the legend are the script's
job, so never edit the `.d2` or `.svg` it writes: fix the spec and re-run.

## Gathering the input

Read the change: `gh pr diff 12`, `git diff main...` for a branch, `git show` for one commit. Draw
the classes it touches plus their direct neighbours, about eight at most. Per class, list only the
members the change is about plus one or two that say what the class is.

## The spec

Start from this skill's `diagrams/class-diff.json` and save yours in the diagrams folder as
`<slug>.json`.

- `title`: what moves, in a few words, ASCII plus `·`. `pr` (the number, `12`) puts `#12 · ` in
  front and names the phases; without it they say "this PR". `base` (`#11`, `main`) labels the
  before panel of `--before-after`.
- `classes`: per class a `name`, then `members` when the class is unchanged, or `before` and
  `after` when it changed. A class on one side only has `"in": "before"` or `"in": "after"` and
  `members`. A renamed class is one of each.
- Members are UML without quotes: `-total: Money`, `+refund(amount: Money): Refund`, `#gateway`.
  Give methods their return type; d2 prints `void` for one without. A member whose type changes
  goes in both lists, once with each type.
- `edges`: `from`, `to` and a `label` per arrow. An arrow is a dependency the change is about (a
  field, a call, a returned type), labelled with its verb, so a call that moves shows as one red
  and one green arrow. Point it in flow direction so the chain reads top to bottom (dagre ranks by
  the arrowhead). An arrow on one side only has `"in"`; a re-pointed or relabelled arrow is a
  removed edge plus an added one.

## Run, check, publish

Run the script with the command in SKILL.md. It lists every problem in the spec at once; fix them
and re-run. It writes `<slug>.d2` and the animated `<slug>.svg`, then prints two frames to read:

- `<slug>-removed.png`: removed rows struck through in red, removed classes and arrows solid, the
  added ones faint.
- `<slug>-added.png`: added rows, classes and arrows solid in green, the removed ones faint.

This check replaces step 6's list. Every changed member is coloured, nothing overlaps and the title
fits; the legend has only the red and green rows, as teal is the plain class colour. When
something overlaps or the board is too wide, trim the spec: fewer classes or members, shorter
labels. If the script found no Chromium, it says so: say the frames went unchecked.

Two flags: `--before-after` also writes `<slug>-before-after.png`, the two states side by side with
every class in the same place. Add it when I ask for a before/after picture or a still for Slack
or slides, which cannot play the SVG. `--together` pulses everything the PR changes at once.

In the report, the `.json` is the source. A PR description cannot show an image from the repo:
upload the SVG (GitHub's attachments take it and play the animation) and embed that URL, with a
one-line caption ("What this PR removes pulses red, then what it adds pulses green."), under the
before/after PNG when there is one.
