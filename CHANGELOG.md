# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Every preset now carries a **house style**: a short block of `***` glob rules (rounding, shadows,
  stroke weight, label size, textures) that gives each style a distinct look instead of plain theme
  colours. Triple globs are used deliberately — d2 does not carry `*` or `**` globs across
  `...@_style`. Override per object, per diagram, or turn it off with `/d2:style tweak look off`.
- `preview.sh --sample <file|name>` previews the styles on a diagram other than the default one,
  with `pipeline`, `sequence` and `data-model` bundled under `assets/examples/`. A style picker
  showing a service architecture is not much help if you mostly draw sequence diagrams.
- `scripts/gallery.sh` regenerates the nine README images in `docs/presets/`; `--check` fails when
  they are stale. They used to be copied by hand.
- `tests/fixtures/shapes.d2` — every d2 shape plus sequence diagrams, layers and steps. `smoke.sh`
  renders every preset against it, so a style key that is illegal for one shape can never ship.
- The contact sheet shows theme, layout engine and font for each preset, and every image links to
  its full-size SVG.

### Changed

- `assets/sample.d2` redesigned. The widest preset went from **4.16:1 to 1.86:1** and all fourteen
  now land between 1.55:1 and 1.86:1 with near-uniform heights, so the gallery reads as a grid.
- The contact sheet is responsive (`auto-fit` columns from 480px) and lets each image fill its card
  instead of capping it at 320px tall, which had been shrinking ELK presets to ~83px of height.
- README gallery: one full-width hero plus a collapsed full-size gallery, replacing the 3x3 table
  of images too small to read on GitHub.

### Fixed

- People no longer render squashed. d2 sizes `shape: person` from its label, so a long name such as
  "Release manager" stretched the icon into a wide blob (136x91 instead of the natural 44x66), and
  the larger house-style label fonts made it worse. Every preset now pins persons to 64x88.

- `/d2:style set` and `tweak` now verify a style by **rendering** it. `d2 validate` reports
  `style.3d` and `style.double-border` as valid and they then fail to compile against cylinders,
  people, queues, tables and markdown blocks, so validation alone could install a broken style.
- The style reference no longer claims the Terminal theme draws dotted containers; it does not —
  they come from the terminal preset's house style.

## [0.1.0] - 2026-09-05

### Added

- `/d2:diagram` skill: writes a `.d2` source and renders it as PNG (default), SVG,
  animated GIF or animated SVG, choosing the diagram type from a best-practice guide.
- `/d2:style` skill: one-time visual style picker (nine presets on a contact sheet),
  plus `set`, `show`, `tweak`, `adopt`, `auto on|off`, `doctor` and `reset`.
- Style files are plain D2 (`_style.d2`), resolved project first, personal second,
  and imported by every diagram so plain `d2` reproduces the look.
- Bundled OFL fonts (Inter, IBM Plex Mono, Lora) applied through `scripts/render.sh`.
