#!/usr/bin/env python3
"""Class diff: a refactoring PR's classes on one board, where what the PR removes
pulses red, then what it adds pulses green. Nothing moves.

    python3 class-diff.py docs/diagrams/x.json [--before-after] [--together]

Reads the spec x.json and writes beside it x.d2 (generated: edit the JSON and
re-run) and x.svg, the animation. --before-after adds x-before-after.d2 and .png:
two panels with every class in the same place. Frames of the animation go to
$TMPDIR/class-diff/ for checking. Needs d2, and _style.d2 beside the spec. The
spec format is in the skill's references/class-diff.md.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import difflib
import html
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
TEAL, GREEN, RED, SLATE = "#6ccbd8", "#2f9e44", "#c8401f", "#66778a"
PANEL, PAPER = "#fbfaf6", "#f3f1ea"
TYPES = "#4a5a6a"  # the member type column (theme key AA2), the house edge-label slate
EDGE_WIDTH = 6
GHOST = 0.18  # before/after panels: a class missing from that state
FAINT = 0.12  # the pulse fades a line to faint, never to zero, so it stays in place
PULSE = 7.0  # seconds per loop
STRIP = 90  # px added above the board for the phase label
FRAMES = (("removed", 1.0), ("added", 4.5))
STATES = ("both", "before", "after")
EXISTS = {"both": {"before", "after"}, "before": {"before"}, "after": {"after"}}
HEADER = {"both": TEAL, "after": GREEN, "before": RED}

CSS = """
.pr {{ animation: pr {s}s infinite; }}
.pg {{ opacity: {lo}; animation: {pg} {s}s infinite; }}
.prl {{ animation: prl {s}s infinite; }}
.pgl {{ opacity: 0; animation: {pgl} {s}s infinite; }}
@keyframes pr {{ 0%, 35% {{ opacity: 1; }} 50%, 85% {{ opacity: {lo}; }} 100% {{ opacity: 1; }} }}
@keyframes pg {{ 0%, 35% {{ opacity: {lo}; }} 50%, 85% {{ opacity: 1; }} 100% {{ opacity: {lo}; }} }}
@keyframes prl {{ 0%, 35% {{ opacity: 1; }} 50%, 85% {{ opacity: 0; }} 100% {{ opacity: 1; }} }}
@keyframes pgl {{ 0%, 35% {{ opacity: 0; }} 50%, 85% {{ opacity: 1; }} 100% {{ opacity: 0; }} }}
"""


class SpecError(Exception):
    """The spec is wrong; args[0] lists every problem found."""


class Failure(Exception):
    """d2, the environment or the SVG is not what the script expects."""


@dataclass(frozen=True)
class Member:
    vis: str
    name: str
    type: str

    @property
    def method(self) -> bool:
        return "(" in self.name


@dataclass
class Row:
    member: Member
    status: str  # same, added or removed
    key: str = ""


@dataclass
class Cls:
    name: str
    state: str
    before: list
    after: list
    id: str = ""
    rows: list = field(default_factory=list)


@dataclass
class Edge:
    src: Cls
    dst: Cls
    label: str
    state: str
    index: int = 0

    @property
    def gid(self) -> str:
        """The id d2 gives the edge's group: repeated pairs count up."""
        return f"({self.src.id} -&gt; {self.dst.id})[{self.index}]"


@dataclass
class Diff:
    title: str
    pr: int | None
    base: str | None
    classes: list
    edges: list

    @property
    def who(self) -> str:
        return f"#{self.pr}" if self.pr else "this PR"


# --- The spec ------------------------------------------------------------------


def parse_member(text: str) -> Member:
    """'+find(id: UUID): Order' -> ('+', 'find(id: UUID)', 'Order')."""
    s = " ".join(text.split())
    vis = "+"
    if s[:1] in ("+", "-", "#"):
        vis, s = s[0], s[1:].lstrip()
    depth = 0
    for i, ch in enumerate(s):
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == ":" and depth == 0:
            return Member(vis, s[:i].rstrip(), s[i + 1 :].strip())
    return Member(vis, s, "")


def keyed(rows: list) -> list:
    """Give each row its d2 key. d2 merges keys that differ only in case, so a
    clash gets trailing spaces; kept rows claim their keys before removed ones."""
    taken = set()
    for r in sorted(rows, key=lambda r: r.status == "removed"):
        key = r.member.vis + r.member.name
        while key.lower() in taken:
            key += " "
        taken.add(key.lower())
        r.key = key
    return rows


def diff_rows(before: list, after: list) -> list:
    """Both member lists as rows in d2's render order: after's members, then the
    removed ones, with fields before methods (d2 draws them that way anyway)."""
    rows = [Row(m, "same" if m in before else "added") for m in after]
    rows += [Row(m, "removed") for m in before if m not in after]
    rows = [r for r in rows if not r.member.method] + [r for r in rows if r.member.method]
    return keyed(rows)


def slug_ids(classes: list) -> None:
    """Ids d2 can't mistake for a keyword (Style, Link, Legend...), unique ignoring case."""
    taken = set()
    for c in classes:
        base = "c_" + (re.sub(r"[^a-z0-9]+", "_", c.name.lower()).strip("_") or "class")
        cid, n = base, 1
        while cid in taken:
            n += 1
            cid = f"{base}_{n}"
        taken.add(cid)
        c.id = cid


def load(path: Path) -> tuple:
    """The spec as a Diff, plus warnings. Raises SpecError listing every problem."""
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise SpecError([f"line {e.lineno}, column {e.colno}: {e.msg}"]) from None
    errors: list = []
    err = errors.append

    def obj(value, allowed, where) -> bool:
        if not isinstance(value, dict):
            err(f"{where}: must be an object")
            return False
        for k in value:
            if k not in allowed:
                err(f"{where}: unknown key {k!r} (allowed: {', '.join(allowed)})")
        return True

    def text(value, where, required=True):
        if value is None:
            if required:
                err(f"{where}: missing")
            return None
        if not isinstance(value, str) or not value.strip() or "\n" in value:
            err(f"{where}: must be one line of text")
            return None
        return value.strip()

    def state(value, where) -> str:
        if value is None:
            return "both"
        if value not in STATES:
            err(f"{where}: must be before, after or both, not {value!r}")
            return "both"
        return value

    def members(value, where) -> list:
        if not isinstance(value, list):
            err(f"{where}: must be a list of members such as \"-id: UUID\"")
            return []
        out = []
        for i, m in enumerate(value):
            s = text(m, f"{where}[{i}]")
            if s is None:
                continue
            member = parse_member(s)
            if not member.name:
                err(f"{where}[{i}]: {s!r} has no name")
            elif member in out:
                err(f"{where}[{i}]: {s!r} is listed twice")
            else:
                out.append(member)
        return out

    if not obj(raw, ("pr", "base", "title", "classes", "edges"), "spec"):
        raise SpecError(errors)
    title = text(raw.get("title"), "title")
    if title:
        odd = [ch for ch in title if not (ch.isascii() and ch.isprintable()) and ch != "·"]
        if odd:
            err(f"title: {odd[0]!r} is missing from the sketch font; write ASCII plus '·' "
                "('->' for an arrow, '...' for an ellipsis)")
        if re.match(r"#\d", title):
            err("title: leave the PR number out; the script adds it from pr")
    pr = raw.get("pr")
    if pr is not None:
        digits = str(pr).lstrip("#") if isinstance(pr, (int, str)) and not isinstance(pr, bool) else ""
        if digits.isdigit() and int(digits) > 0:
            pr = int(digits)
        else:
            err(f"pr: must be the PR number, such as 12, not {pr!r}")
            pr = None
    base = text(raw.get("base"), "base", required=False)

    classes: list = []
    by_name: dict = {}
    raw_classes = raw.get("classes")
    if not isinstance(raw_classes, list) or not raw_classes:
        err("classes: must be a list with at least one class")
        raw_classes = []
    for i, c in enumerate(raw_classes):
        where = f"classes[{i}]"
        if not obj(c, ("name", "in", "members", "before", "after"), where):
            continue
        name = text(c.get("name"), f"{where}.name")
        where = f"{where} ({name})" if name else where
        st = state(c.get("in"), f"{where}.in")
        if "members" in c and ("before" in c or "after" in c):
            err(f"{where}: give members, or before and after, not both")
        elif "members" in c:
            before = after = members(c["members"], f"{where}.members")
        elif "before" in c and "after" in c:
            if st != "both":
                err(f"{where}: a class that exists {st} only lists its members once, in members")
            before = members(c["before"], f"{where}.before")
            after = members(c["after"], f"{where}.after")
        else:
            err(f"{where}: needs members (unchanged), or before and after (changed)")
            continue
        if name in by_name:
            err(f"{where}: another class is also called {name!r}")
        elif name:
            by_name[name] = Cls(name, st, before, after)
            classes.append(by_name[name])

    edges: list = []
    seen: set = set()
    raw_edges = raw.get("edges", [])
    if not isinstance(raw_edges, list):
        err("edges: must be a list")
        raw_edges = []
    for i, e in enumerate(raw_edges):
        where = f"edges[{i}]"
        if not obj(e, ("from", "to", "label", "in"), where):
            continue
        ends = []
        for end in ("from", "to"):
            name = text(e.get(end), f"{where}.{end}")
            if name and name not in by_name:
                close = difflib.get_close_matches(name, list(by_name), n=1)
                hint = f"; did you mean {close[0]!r}?" if close else ""
                err(f"{where}.{end}: no class called {name!r}{hint}")
            ends.append(by_name.get(name))
        label = text(e.get("label"), f"{where}.label")
        st = state(e.get("in"), f"{where}.in")
        src, dst = ends
        if not (src and dst and label):
            continue
        for c in {src.name: src, dst.name: dst}.values():
            if not EXISTS[st] <= EXISTS[c.state]:
                err(f"{where}: {src.name} -> {dst.name} is in {st} states, but {c.name} exists {c.state} only")
        if (src.name, dst.name, label) in seen:
            err(f"{where}: {src.name} -> {dst.name} ({label}) is listed twice; "
                "an arrow in both states is written once, without in")
        seen.add((src.name, dst.name, label))
        edges.append(Edge(src, dst, label, st))

    for c in classes:
        changed = c.state == "both" and c.before != c.after
        c.rows = diff_rows(c.before, c.after) if changed else keyed([Row(m, "same") for m in c.after])
        c.rows = [r for r in c.rows if not r.member.method] + [r for r in c.rows if r.member.method]
    removed = any(c.state == "before" or any(r.status == "removed" for r in c.rows) for c in classes)
    removed |= any(e.state == "before" for e in edges)
    added = any(c.state == "after" or any(r.status == "added" for r in c.rows) for c in classes)
    added |= any(e.state == "after" for e in edges)
    if classes and not errors and not (removed or added):
        err("nothing changes between before and after; draw a plain class diagram (class.d2) instead")
    if errors:
        raise SpecError(errors)

    slug_ids(classes)
    count: dict = {}
    for e in edges:
        pair = (e.src.id, e.dst.id)
        e.index = count.get(pair, 0)
        count[pair] = e.index + 1
    warnings = [f"nothing is {w}, so the {colour} phase shows nothing"
                for w, colour, some in (("removed", "red", removed), ("added", "green", added)) if not some]
    return Diff(title, pr, base, classes, edges), warnings


# --- d2 source -----------------------------------------------------------------


def q(s: str) -> str:
    """A d2 double-quoted string, so '#', ':', ',' and '.' stay text."""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def head(diff: Diff, stem: str, note: str = "") -> list:
    text = f"#{diff.pr} · {diff.title}" if diff.pr else diff.title
    text = re.sub(r"([\\`*_\[\]<>])", r"\\\1", text)  # markdown would eat or reject these
    bar = "|||" if "|" in text else "|"
    return [
        "...@_style",
        f"# Generated by class-diff.py from {stem}.json: edit that and re-run the script{note}.",
        "",
        "# Member types in slate instead of the house brick red: in a diff, red means removed.",
        f'vars: {{d2-config: {{theme-overrides: {{AA2: "{TYPES}"}}}}}}',
        "",
        f"title: {bar}md",
        f"  # {text}",
        f"{bar} {{near: top-center}}",
        "",
    ]


def class_lines(cid: str, name: str, fill: str, rows: list, extra=()) -> list:
    out = [f"{cid}: {q(name)} {{", "  shape: class", f'  style.fill: "{fill}"']
    out += [f"  {e}" for e in extra]
    for r in rows:
        out.append(f"  {q(r.key)}: {q(r.member.type)}" if r.member.type else f"  {q(r.key)}")
    return out + ["}"]


def edge_style(state: str, extra=()) -> str:
    style = list(extra)
    if state != "both":
        colour = RED if state == "before" else GREEN
        style = [f'style.stroke: "{colour}"', f'style.font-color: "{colour}"',
                 f"style.stroke-width: {EDGE_WIDTH}"] + style
    return f" {{{'; '.join(style)}}}" if style else ""


def legend(diff: Diff, ghost: bool = False) -> list:
    # The phase labels above the board reuse these texts: d2 embeds only the
    # glyphs it draws in each font, and this is the face the labels are set in.
    rows = [("gone", RED, f"Removed by {diff.who}"), ("new", GREEN, f"Added by {diff.who}")]
    out = ['legend: "" {', "  near: bottom-center", f"  grid-rows: {len(rows) + ghost}", "  grid-columns: 2",
           "  grid-gap: 10", f'  style: {{fill: "{PAPER}"; stroke-width: 1}}', "  *.style.font-size: 16",
           "  *.style.bold: false"]
    for key, colour, label in rows:
        out += [f'  {key}: "" {{style.fill: "{colour}"; width: 24; height: 24}}',
                f'  {key}-label: {q(label)} {{shape: text; style.font-color: "{colour}"}}']
    if ghost:
        out += [f'  ghost: "" {{width: 24; height: 24; style: {{fill: "{SLATE}"; opacity: {GHOST}}}}}',
                f"  ghost-label: {q('Faint: not on this side')} {{shape: text}}"]
    return out + ["}"]


def diff_d2(diff: Diff, stem: str) -> str:
    out = head(diff, stem, " (plain d2 would render it without the pulse)") + ["direction: down", ""]
    for c in diff.classes:
        out += class_lines(c.id, c.name, HEADER[c.state], c.rows)
    out += [f"{e.src.id} -> {e.dst.id}: {q(e.label)}{edge_style(e.state)}" for e in diff.edges]
    return "\n".join(out + [""] + legend(diff)) + "\n"


def d2(args: list, cwd: Path, source: str | None = None) -> str:
    """Run d2 with the house style intact: no D2_* overrides, stdin closed so a
    first-run Chromium prompt fails instead of hanging."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("D2_")}
    feed = {"input": source} if source is not None else {"stdin": subprocess.DEVNULL}
    p = subprocess.run(["d2", *args], cwd=cwd, env=env, capture_output=True, text=True, encoding="utf-8", **feed)
    if p.returncode:
        msg = (p.stderr or p.stdout).strip()
        if args[-1].endswith(".png") and re.search(r"chrom|playwright", msg, re.I):
            msg += ("\nPNG output needs d2's one-time Chromium download (about 150 MB): "
                    "ask first, then re-run this command with CI=1 in front.")
        raise Failure(f"d2 {' '.join(args)} failed:\n{msg}")
    return p.stdout


# --- The animation ---------------------------------------------------------------

GROUP_TAG = re.compile(r"<g\b[^>]*?(/?)>|</g>")
TEXT = re.compile(r"<text\b([^>]*)>([^<]*)</text>")


def top_groups(svg: str) -> dict:
    """{d2 id: (start, end)} of each element group. d2 nests its boards in <svg>,
    so its elements are exactly the <g>s at depth 0, classed by base64 id."""
    out, depth, start, gid = {}, 0, None, None
    for m in GROUP_TAG.finditer(svg):
        if m.group(0) == "</g>":
            depth -= 1
            if depth == 0 and start is not None:
                out[gid] = (start, m.end())
                start = None
        elif not m.group(1):
            if depth == 0:
                gid = decode_id(m.group(0))
                start = m.start() if gid else None
            depth += 1
    return out


def decode_id(tag: str) -> str | None:
    m = re.match(r'<g class="([A-Za-z0-9+/]+={0,2})"', tag)
    try:
        return base64.b64decode(m.group(1), validate=True).decode() if m else None
    except (binascii.Error, UnicodeDecodeError):
        return None


def attr(tag: str, name: str) -> str | None:
    m = re.search(rf'\s{name}="([^"]*)"', tag)
    return m.group(1) if m else None


def add_to(tag: str, name: str, value: str, sep: str) -> str:
    m = re.search(rf'\s{name}="([^"]*)"', tag)
    if not m:
        return tag.replace("<text", f'<text {name}="{value}"', 1)
    old = m.group(1)
    return tag[: m.start(1)] + (old + sep + value if old else value) + tag[m.end(1) :]


def paint(tag: str, status: str) -> str:
    """A removed row turns red and is struck through, an added one turns green;
    both pulse with their phase."""
    if status == "removed":
        return add_to(add_to(tag, "class", "pr", " "), "style", f"fill:{RED};text-decoration:line-through", ";")
    return add_to(add_to(tag, "class", "pg", " "), "style", f"fill:{GREEN}", ";")


def colour_rows(group: str, c: Cls) -> str:
    """Paint the changed member rows of a class that exists in both states.
    Its texts line up in rows: the header first, then one line per member
    (visibility, name, type; a field without a type has no type cell)."""
    if all(r.status == "same" for r in c.rows):
        return group
    lines: dict = {}
    for t in TEXT.finditer(group):
        lines.setdefault(float(attr(t.group(1), "y")), []).append(t)
    rows = [lines[y] for y in sorted(lines)][1:]
    if len(rows) != len(c.rows):
        raise Failure(f"{c.name}: the SVG has {len(rows)} member rows, the spec {len(c.rows)}")
    edits = []
    for cells, row in zip(rows, c.rows):
        cells = sorted(cells, key=lambda t: float(attr(t.group(1), "x")))
        name = html.unescape(cells[1].group(2)) if len(cells) > 1 else ""
        if name != row.key[1:]:
            raise Failure(f"{c.name}: expected the row {row.key!r}, the SVG has {name!r}")
        if row.status != "same":
            edits += [(t, row.status) for t in cells]
    for t, status in sorted(edits, key=lambda e: -e[0].start()):
        group = group[: t.start()] + paint(t.group(0), status) + group[t.end() :]
    return group


def pulse(svg: str, diff: Diff) -> str:
    """Wrap what exists in one state in <g class="pr|pg"> (never classing d2's own
    group, whose inline opacity the animation would override) and paint rows."""
    groups = top_groups(svg)
    jobs = [(c.id, c) for c in diff.classes] + [(e.gid, e) for e in diff.edges if e.state != "both"]
    missing = [gid for gid, _ in jobs if gid not in groups]
    if missing:
        raise Failure(f"no group for {', '.join(missing)} in d2's SVG; has d2 changed its output?")
    for gid, item in sorted(jobs, key=lambda j: -groups[j[0]][0]):
        s, e = groups[gid]
        if item.state == "both":
            grp = colour_rows(svg[s:e], item)
        else:
            grp = f'<g class="{"pr" if item.state == "before" else "pg"}">{svg[s:e]}</g>'
        svg = svg[:s] + grp + svg[e:]
    return svg


def add_strip(svg: str, diff: Diff, together: bool) -> str:
    """Grow the canvas 90 px upwards for the phase label, add the CSS."""
    outer = re.search(r"<svg\b[^>]*>", svg)
    x, y, w, h = (float(v) for v in attr(outer.group(0), "viewBox").split())
    tag = re.sub(r'\s(?:width|height)="[^"]*"', "", outer.group(0))
    tag = re.sub(r'viewBox="[^"]*"', f'viewBox="{x:g} {y - STRIP:g} {w:g} {h + STRIP:g}" '
                 f'width="{w:g}" height="{h + STRIP:g}"', tag)
    paper = re.search(r'<rect\b[^>]*\sfill="(#[0-9a-fA-F]+)"', svg[outer.end() :])
    font = re.search(r"d2-\d+", svg).group(0) + "-font-regular"
    css = CSS.format(s=PULSE, lo=FAINT, pg="pr" if together else "pg", pgl="prl" if together else "pgl")
    cx, ly = x + w / 2, y - STRIP / 2 + 14
    spots = [(cx - 20, "end"), (cx + 20, "start")] if together else [(cx, "middle")] * 2
    labels = "".join(
        f'<text class="{cls}" x="{px:g}" y="{ly:g}" text-anchor="{anchor}" font-family="{font}, sans-serif" '
        f'font-size="40" fill="{colour}">{html.escape(text)}</text>'
        for (cls, colour, text), (px, anchor) in zip(
            (("prl", RED, f"Removed by {diff.who}"), ("pgl", GREEN, f"Added by {diff.who}")), spots))
    top = (f'<style>{css}</style><rect x="{x:g}" y="{y - STRIP:g}" width="{w:g}" height="{STRIP}" '
           f'fill="{paper.group(1) if paper else PAPER}"/>')
    svg = svg[: outer.start()] + tag + top + svg[outer.end() :]
    end = svg.rindex("</svg>")
    return svg[:end] + labels + svg[end:]


# --- Frames --------------------------------------------------------------------


def find_chrome() -> Path | None:
    """d2's own headless Chromium, the newest revision."""
    roots = [os.environ["PLAYWRIGHT_BROWSERS_PATH"]] if os.environ.get("PLAYWRIGHT_BROWSERS_PATH") else \
        ["~/Library/Caches/ms-playwright", "~/.cache/ms-playwright"]
    for root in roots:
        found = [p for pattern in ("chromium_headless_shell-*/*/chrome-headless-shell",
                                   "chromium_headless_shell-*/*/headless_shell")
                 for p in Path(root).expanduser().glob(pattern)]
        if found:
            return max(found, key=lambda p: int(re.sub(r"\D", "", p.parent.parent.name) or 0))
    return None


def frames(svg: str, stem: str, together: bool) -> list | None:
    """Screenshot the animation frozen in each phase; None without Chromium.
    Headless Chrome's virtual time does not advance CSS animations, so each
    copy pauses them at a negative delay instead."""
    chrome = find_chrome()
    if not chrome:
        return None
    out = Path(tempfile.gettempdir()) / "class-diff"
    out.mkdir(exist_ok=True)
    outer = re.search(r"<svg\b[^>]*>", svg)
    size = ",".join(str(math.ceil(float(attr(outer.group(0), k)))) for k in ("width", "height"))
    shots = []
    with tempfile.TemporaryDirectory() as tmp:
        for name, t in (("changed", 1.0),) if together else FRAMES:
            frozen = Path(tmp) / f"{name}.svg"
            frozen.write_text(svg[: outer.end()] + "<style>* { animation-play-state: paused !important; "
                              f"animation-delay: -{t}s !important; }}</style>" + svg[outer.end() :], encoding="utf-8")
            png = out / f"{stem}-{name}.png"
            png.unlink(missing_ok=True)
            subprocess.run([str(chrome), "--headless", "--no-sandbox", "--hide-scrollbars",
                            "--force-device-scale-factor=1", f"--window-size={size}", f"--screenshot={png}",
                            f"--user-data-dir={tmp}/profile", frozen.as_uri()],
                           capture_output=True, timeout=60, check=False)
            if png.exists():
                shots.append(png)
    return shots


# --- Before/after ----------------------------------------------------------------


def outline(group: str) -> tuple:
    """Width and height of a class box, from its outline."""
    m = re.search(r'<path d="([^"]+)"[^>]*class="shape', group)
    if m:
        nums = [float(n) for n in re.findall(r"-?\d+\.?\d*", m.group(1))]
        return max(nums[0::2]) - min(nums[0::2]), max(nums[1::2]) - min(nums[1::2])
    m = re.search(r'<rect\b[^>]*\swidth="([\d.]+)" height="([\d.]+)"[^>]*class="shape', group)
    return float(m.group(1)), float(m.group(2))


def same_rows(members: list) -> list:
    return keyed([Row(m, "same") for m in members])


def before_after(diff: Diff, folder: Path, stem: str) -> list:
    """Two panels holding the same graph. Every class gets the larger of its two
    natural sizes, so dagre places it identically in both; a state hides the
    arrows it lacks (opacity 0) and fades the classes it lacks."""
    probe = ["...@_style", ""]
    for c in diff.classes:
        for s, members in (("b", c.before), ("a", c.after)):
            probe += class_lines(f"{s}_{c.id}", c.name, TEAL, same_rows(members))
    svg = d2(["-", "-"], folder, "\n".join(probe) + "\n")
    groups = top_groups(svg)
    sizes = {}
    for c in diff.classes:
        dims = [outline(svg[slice(*groups[f"{s}_{c.id}"])]) for s in "ba"]
        sizes[c.id] = (int(max(d[0] for d in dims) + 6), int(max(d[1] for d in dims) + 6))

    out = head(diff, stem) + ["grid-rows: 1", "grid-columns: 2", "grid-gap: 60", ""]
    captions = {"before": "Before" + (f" · {diff.base}" if diff.base else ""),
                "after": "After" + (f" · #{diff.pr}" if diff.pr else "")}
    for panel in ("before", "after"):
        out += [f"{panel}: {q(captions[panel])} {{", f'  style.fill: "{PANEL}"']
        for c in diff.classes:
            extra = [f"width: {sizes[c.id][0]}", f"height: {sizes[c.id][1]}"]
            if panel not in EXISTS[c.state]:
                extra.append(f"style.opacity: {GHOST}")
            rows = same_rows(c.before if panel == "before" else c.after)
            out += ["  " + line for line in class_lines(c.id, c.name, HEADER[c.state], rows, extra)]
        for e in diff.edges:
            hide = [] if panel in EXISTS[e.state] else ["style.opacity: 0"]
            out.append(f"  {e.src.id} -> {e.dst.id}: {q(e.label)}{edge_style(e.state, hide)}")
        out += ["}", ""]
    out += legend(diff, ghost=any(c.state != "both" for c in diff.classes))
    source = folder / f"{stem}-before-after.d2"
    source.write_text("\n".join(out) + "\n", encoding="utf-8")
    image = folder / f"{stem}-before-after.png"
    d2([source.name, image.name], folder)
    return [source, image]


# --- Main ------------------------------------------------------------------------


def run(args) -> None:
    spec = args.spec
    if not spec.is_file():
        raise Failure(f"no spec at {spec}")
    if not shutil.which("d2"):
        raise Failure("d2 is not installed; the d2 skill's Setup says how to install it")
    folder, stem = spec.resolve().parent, spec.stem
    if not (folder / "_style.d2").is_file():
        raise Failure(f"no _style.d2 beside the spec; copy the house style there first:\n"
                      f"  cp {SKILL_DIR / 'style.d2'} {folder / '_style.d2'}")
    diff, warnings = load(spec)
    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    source = folder / f"{stem}.d2"
    source.write_text(diff_d2(diff, stem), encoding="utf-8")
    svg = add_strip(pulse(d2([source.name, "-"], folder), diff), diff, args.together)
    image = folder / f"{stem}.svg"
    image.write_text(svg, encoding="utf-8")
    written = [source, image] + (before_after(diff, folder, stem) if args.before_after else [])
    print("wrote " + ", ".join(os.path.relpath(p) for p in written), flush=True)
    shots = frames(svg, stem, args.together)
    if shots:
        print("frames to check: " + " ".join(str(p) for p in shots))
    else:
        print("warning: no frames; d2's headless Chromium was not found (d2 downloads it with its "
              "first PNG). Open the SVG in a browser to check it.", file=sys.stderr)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="class-diff.py", description=__doc__.split("\n\n")[0],
                                 epilog="The spec format is in the d2 skill's references/class-diff.md.")
    ap.add_argument("spec", type=Path, help="the JSON spec; outputs are written beside it")
    ap.add_argument("--before-after", action="store_true",
                    help="also write <spec>-before-after.d2 and .png: two panels, every class in the same place")
    ap.add_argument("--together", action="store_true",
                    help="pulse everything the PR changes at once instead of red, then green")
    args = ap.parse_args(argv)
    try:
        run(args)
    except SpecError as e:
        print(f"{args.spec}: fix the spec and re-run:", file=sys.stderr)
        for problem in e.args[0]:
            print(f"  {problem}", file=sys.stderr)
        return 1
    except Failure as e:
        print(f"class-diff: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
