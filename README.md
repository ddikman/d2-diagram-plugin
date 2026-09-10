# d2 skill

A personal Claude Code skill that turns "draw the login flow" into a [D2](https://d2lang.com)
source file and a rendered PNG (or SVG, or an animated GIF), in a vivid hand-drawn style with one
of six colour themes.

## Install

```bash
brew install d2
git clone git@github.com:ddikman/d2-diagram-plugin.git ~/code/d2-diagram-plugin
ln -s ~/code/d2-diagram-plugin ~/.claude/skills/d2
```

PNG and GIF output need a headless Chromium that d2 downloads once (about 150 MB); the skill asks
before that happens.

## Use

```
> draw the checkout flow: cart, payment service, email worker
> sequence diagram of the OAuth callback, as svg
> make an animated walkthrough of the deploy pipeline
> /d2 style            # contact sheet of the six themes, pick by number
> /d2 style sunset     # switch this repo to a theme directly
```

Diagrams land in `docs/diagrams/<name>.d2` next to their image. Each one starts with
`...@_style`, importing the theme file that sits beside it, so plain `d2 docs/diagrams/x.d2 x.png`
gives the same picture. The first repo you draw in gets the theme from
`~/.config/d2-diagram/_style.d2` (the default is `poster`).

## Themes

`assets/themes/` holds six plain D2 files: `poster`, `teal`, `sunset`, `ocean`, `plum` and
`chalkboard`. Preview them all on your own diagram with
`bash scripts/preview.sh --sample path/to/diagram.d2`, or edit the hex values to taste; which key
colours what is documented in `references/style.md`.

## Layout

```
SKILL.md              the skill
scripts/              preflight.sh (environment), render.sh (render wrapper), preview.sh (contact sheet)
assets/               sample.d2, themes/*.d2, contact-sheet.html
references/           diagram types, D2 cheat sheet, output formats, style file and themes
tests/                smoke.sh, fixtures/shapes.d2 (every d2 shape)
```

`bash tests/smoke.sh` checks the themes, the render rules and the import flow; add `--png` to
exercise the Chromium path.
