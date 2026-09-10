# My D2 diagram style

A personal Claude Code skill. Ask for a diagram and `/d2` writes a [D2](https://d2lang.com) source
file next to a rendered PNG (or SVG, or an animated GIF) in my style: hand-drawn sketch mode, slate
ink, teal and cyan shapes, yellow groups, soft orange databases, on warm grey paper.

## Install

```bash
brew install d2
git clone git@github.com:ddikman/d2-diagram-plugin.git ~/code/d2-diagram-plugin
ln -s ~/code/d2-diagram-plugin ~/.claude/skills/d2
```

## How it works

Diagrams land in `docs/diagrams/<name>.d2` beside their image. Each one starts with `...@_style`,
importing a copy of `style.d2` that sits next to it, so plain `d2 docs/diagrams/x.d2 x.png` gives
the same picture with no flags. The style is ordinary D2: a `vars` block with the colours, a paper
colour and a few `***` house rules. Edit `style.d2` to change the master, then copy it over a repo's
`_style.d2` and re-render. The colour keys are explained at the top of the file.

`references/` holds the two notes the skill reads while drawing: which diagram fits which question,
and the D2 syntax that is easy to get wrong.
