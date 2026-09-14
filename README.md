# My D2 diagram style

A personal Claude Code skill. Ask for a diagram and `/d2` writes a [D2](https://d2lang.com) source
file next to a rendered PNG (or SVG, or an animated GIF) in my style: hand-drawn sketch mode, slate
ink, teal and cyan shapes, yellow groups, soft orange databases, on warm grey paper.

## Install

The skill follows Anthropic's open [Agent Skills](https://agentskills.io) format, so it installs
with the `skills` CLI, the standard installer for that format, into Claude Code, Cursor, Codex,
OpenCode and some seventy other agents.

```bash
# Claude Code, user-level (available in every project)
npx skills add ddikman/d2-diagram-plugin -a claude-code -g

# Cursor
npx skills add ddikman/d2-diagram-plugin -a cursor -g

# every agent the CLI knows about, or any other by name (codex, opencode, ...)
npx skills add ddikman/d2-diagram-plugin -a '*' -g
```

Drop `-g` to install into the current project only (it lands in `.agents/skills/d2` with a
symlink for each agent). `npx skills list` shows what is installed, `npx skills update` pulls
the latest version, `npx skills remove d2` takes it out again.

The format has no install hooks, so nothing runs at install time. Instead the skill checks for
[d2](https://d2lang.com) the first time it is used and, if it is missing, asks before installing
it: Homebrew on macOS, otherwise the official install script into `~/.local` (no sudo). Nothing
is installed without a yes. To do it up front: `brew install d2` or
`curl -fsSL https://d2lang.com/install.sh | sh -s --`.

Without the CLI, a clone and a symlink do the same for Claude Code:

```bash
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
