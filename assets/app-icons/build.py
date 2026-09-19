#!/usr/bin/env python3
"""Maintainer-only, offline build. Never installs a font or addresses SketchyBar.

Use the pinned requirements and an explicitly downloaded --base font.
The source SVGs use black fill, white subtraction and optional evenodd paths.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import SVGPath
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables.otTables import Ligature
import pathops

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
BASE_URL = "https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.89/sketchybar-app-font.ttf"
BASE_SHA256 = "d7f111a888147133830884acc46394e1665e91a7b251e64e9511bc974831d99c"
FAMILY = "AI First App Icons"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def outline(source):
    root = ET.parse(source).getroot()
    result = pathops.Path()
    for element in root:
        if element.tag.split("}")[-1] not in ("path", "rect"):
            raise ValueError("Only path/rect elements supported: " + str(source))
        if set(element.attrib) & {"stroke", "clip-path", "filter", "opacity"}:
            raise ValueError("Flatten strokes/effects before building: " + str(source))
        shape = pathops.Path()
        if element.get("fill-rule") == "evenodd":
            shape.fillType = pathops.FillType.EVEN_ODD
        container = ET.Element("svg")
        container.append(element)
        SVGPath.fromstring(ET.tostring(container)).draw(shape.getPen())
        shape = pathops.simplify(shape)
        operation = pathops.PathOp.DIFFERENCE if element.get("fill") == "#fff" else pathops.PathOp.UNION
        result = pathops.op(result, shape, operation)
    return pathops.simplify(result)


def build(base, output):
    if digest(base) != BASE_SHA256:
        raise ValueError("Base font checksum mismatch; use the recorded v2.0.89 asset")
    font = TTFont(base, recalcTimestamp=False)
    order = list(font.getGlyphOrder())
    substitutions = font["GSUB"].table.LookupList.Lookup[0].SubTable[0].ligatures
    cmap = font.getBestCmap()
    width = font["hmtx"].metrics[":default:"][0]
    additions = []
    source_hashes = {}
    for source in sorted((ROOT / "svgs").glob("*.svg")):
        token = ":" + source.stem + ":"
        if token in order or any(ord(c) not in cmap for c in token):
            raise ValueError("Duplicate token or missing ligature character: " + token)
        path = outline(source)
        x0, y0, x1, y1 = path.bounds
        scale = 940 / max(x1 - x0, y1 - y0)
        tx = (width - (x1 - x0) * scale) / 2 - x0 * scale
        ty = (1000 - (y1 - y0) * scale) / 2 + y1 * scale
        pen = TTGlyphPen(None)
        path.draw(TransformPen(Cu2QuPen(pen, max_err=0.5, reverse_direction=True),
                               (scale, 0, 0, -scale, tx, ty)))
        glyph = pen.glyph()
        font["glyf"][token] = glyph
        glyph.recalcBounds(font["glyf"])
        font["hmtx"].metrics[token] = (width, glyph.xMin)
        order.append(token)
        ligature = Ligature()
        ligature.LigGlyph = token
        ligature.Component = [cmap[ord(c)] for c in token[1:]]
        ligature.CompCount = len(token)
        substitutions.setdefault(cmap[ord(token[0])], []).append(ligature)
        # Private-use codepoints for inspection; app scripts use ligatures.
        codepoint = 0xF000 + len(additions)
        if any(codepoint in table.cmap for table in font["cmap"].tables if table.isUnicode()):
            raise ValueError("Private-use codepoint collision")
        for table in font["cmap"].tables:
            if table.isUnicode():
                table.cmap[codepoint] = token
        additions.append(token)
        source_hashes[str(source.relative_to(ROOT))] = digest(source)
    font.setGlyphOrder(order)
    font["maxp"].numGlyphs = len(order)
    for entries in substitutions.values():
        entries.sort(key=lambda entry: (-entry.CompCount, entry.LigGlyph))
    for record in font["name"].names:
        if record.nameID in (1, 3, 4, 6):
            value = "AIFirstAppIcons-Regular" if record.nameID == 6 else FAMILY
        elif record.nameID == 5:
            value = "Version 1.000; upstream 2.0.89"
        else:
            continue
        record.string = value.encode(record.getEncoding())
    font["head"].created = font["head"].modified = 3872707200
    font["head"].fontRevision = 1.0
    mapping = REPO / "home/.config/sketchybar/plugins/icon_map.sh"
    used = set(re.findall(r'icon_result="(:[a-z0-9_-]+:)"', mapping.read_text()))
    ligatures = sorted(entry.LigGlyph for entries in substitutions.values() for entry in entries)
    missing = used - set(ligatures)
    if missing:
        raise ValueError("Mapping contains missing glyphs: " + ", ".join(sorted(missing)))
    output.mkdir(parents=True, exist_ok=True)
    target = output / "ai-first-app-icons.ttf"
    font.save(target, reorderTables=True)
    manifest = dict(schema=1, family=FAMILY, version="1.000", upstream_url=BASE_URL,
                    upstream_sha256=BASE_SHA256, font_sha256=digest(target),
                    additions=additions, ligatures=ligatures, sources=source_hashes,
                    mapping_sha256=digest(mapping), builder_sha256=digest(Path(__file__)),
                    requirements_sha256=digest(ROOT / "requirements.txt"))
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for license_file in (ROOT / "licenses").glob("*.txt"):
        (output / license_file.name).write_bytes(license_file.read_bytes())
    print(f"Built {target}: {len(additions)} additions, {len(ligatures)} ligatures")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=REPO / "home/.config/sketchybar/fonts")
    args = parser.parse_args()
    build(args.base, args.output)
