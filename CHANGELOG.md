# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0] - 2026-09-05

### Added

- `/d2:diagram` skill: writes a `.d2` source and renders it as PNG (default), SVG,
  animated GIF or animated SVG, choosing the diagram type from a best-practice guide.
- `/d2:style` skill: one-time visual style picker (nine presets on a contact sheet),
  plus `set`, `show`, `tweak`, `adopt`, `auto on|off`, `doctor` and `reset`.
- Style files are plain D2 (`_style.d2`), resolved project first, personal second,
  and imported by every diagram so plain `d2` reproduces the look.
- Bundled OFL fonts (Inter, IBM Plex Mono, Lora) applied through `scripts/render.sh`.
