"""Offline font/mapping contract checks; no third-party Python packages or IPC."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
CONFIG = REPO / "home/.config/sketchybar"


class Font:
    """Read the bundled font's BMP cmap and type-4 GSUB, not a font renderer."""
    def __init__(self, data):
        self.data = data
        assert data[:4] == b"\x00\x01\x00\x00"
        self.tables = {}
        for i in range(self.u16(4)):
            tag, _, offset, size = struct.unpack_from(">4sIII", data, 12 + i * 16)
            assert offset + size <= len(data)
            self.tables[tag.decode()] = offset
        cmap = self.tables["cmap"]
        self.cmap = None
        for i in range(self.u16(cmap + 2)):
            _, _, offset = struct.unpack_from(">HHI", data, cmap + 4 + i * 8)
            if self.u16(cmap + offset) == 4:
                self.cmap = cmap + offset
                break
        assert self.cmap is not None
        self.ligatures = {}
        lookup_list = self.tables["GSUB"] + self.u16(self.tables["GSUB"] + 8)
        for i in range(self.u16(lookup_list)):
            lookup = lookup_list + self.u16(lookup_list + 2 + i * 2)
            assert self.u16(lookup) == 4, "Update verifier for a new GSUB lookup type"
            for j in range(self.u16(lookup + 4)):
                sub = lookup + self.u16(lookup + 6 + j * 2)
                assert self.u16(sub) == 1
                coverage = sub + self.u16(sub + 2)
                starts = self.coverage(coverage)
                assert len(starts) == self.u16(sub + 4)
                for index, first in enumerate(starts):
                    group = sub + self.u16(sub + 6 + index * 2)
                    for k in range(self.u16(group)):
                        lig = group + self.u16(group + 2 + k * 2)
                        components = [first] + [self.u16(lig + 4 + n * 2)
                                               for n in range(self.u16(lig + 2) - 1)]
                        key = tuple(components)
                        assert key not in self.ligatures, "Duplicate substitution"
                        self.ligatures[key] = self.u16(lig)

    def u16(self, offset):
        return struct.unpack_from(">H", self.data, offset)[0]

    def coverage(self, offset):
        kind, count = self.u16(offset), self.u16(offset + 2)
        if kind == 1:
            return [self.u16(offset + 4 + i * 2) for i in range(count)]
        assert kind == 2
        result = []
        for i in range(count):
            first, last, index = struct.unpack_from(">HHH", self.data, offset + 4 + i * 6)
            assert index == len(result)
            result.extend(range(first, last + 1))
        return result

    def char(self, value):
        offset, code = self.cmap, ord(value)
        count = self.u16(offset + 6) // 2
        ends = offset + 14
        starts = ends + 2 * count + 2
        deltas = starts + 2 * count
        ranges = deltas + 2 * count
        for i in range(count):
            start, end = self.u16(starts + i * 2), self.u16(ends + i * 2)
            if start <= code <= end:
                delta = self.u16(deltas + i * 2)
                address = ranges + i * 2
                jump = self.u16(address)
                glyph = self.u16(address + jump + 2 * (code - start)) if jump else code
                return (glyph + delta) & 0xffff if glyph or not jump else 0
        return 0

    def glyph(self, token):
        sequence = tuple(self.char(c) for c in token)
        assert all(sequence), token + " has unmapped characters"
        glyph = self.ligatures[sequence]
        long_offsets = self.u16(self.tables["head"] + 50) == 1
        stride = 4 if long_offsets else 2
        values = struct.unpack_from(">II" if long_offsets else ">HH", self.data,
                                    self.tables["loca"] + glyph * stride)
        begin, end = values if long_offsets else (v * 2 for v in values)
        assert end > begin, token + " has no outline"
        contours, x0, y0, x1, y1 = struct.unpack_from(">hhhhh", self.data, self.tables["glyf"] + begin)
        assert contours != 0 and x1 > x0 and y1 > y0, token + " has empty bounds"
        count = self.u16(self.tables["hhea"] + 34)
        assert self.u16(self.tables["hmtx"] + min(glyph, count - 1) * 4) > 0
        return glyph


class AppIcons(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((CONFIG / "fonts/manifest.json").read_text())
        cls.data = (CONFIG / "fonts/ai-first-app-icons.ttf").read_bytes()
        cls.font = Font(cls.data)

    def test_build_assets_and_sources_match(self):
        self.assertEqual(self.manifest["font_sha256"], hashlib.sha256(self.data).hexdigest())
        sources = REPO / "assets/app-icons"
        self.assertEqual(set(self.manifest["sources"]),
                         {str(p.relative_to(sources)) for p in (sources / "svgs").glob("*.svg")})
        for relative, expected in self.manifest["sources"].items():
            self.assertEqual(expected, hashlib.sha256((sources / relative).read_bytes()).hexdigest(), relative)
        for key, path in (("mapping_sha256", CONFIG / "plugins/icon_map.sh"),
                          ("builder_sha256", sources / "build.py"),
                          ("requirements_sha256", sources / "requirements.txt")):
            self.assertEqual(self.manifest[key], hashlib.sha256(path.read_bytes()).hexdigest(), key)
        for license_name in ("CC0.txt", "MIT-LobeHub.txt"):
            self.assertEqual((sources / "licenses" / license_name).read_bytes(),
                             (CONFIG / "fonts" / license_name).read_bytes())

    def test_every_ligature_has_an_actual_outline(self):
        for token in self.manifest["ligatures"]:
            with self.subTest(token=token):
                self.font.glyph(token)
        tokens = set(re.findall(r'icon_result="([^"]+)"', (CONFIG / "plugins/icon_map.sh").read_text()))
        self.assertLessEqual(tokens, set(self.manifest["ligatures"]))
        additions = [self.font.glyph(token) for token in self.manifest["additions"]]
        self.assertEqual(len(additions), len(set(additions)))

    def test_app_names_localizations_and_bundle_ids(self):
        groups = {
            "manus": ["Manus", "Manus Studio", "im.manus.desktop"],
            "codexbar": ["CodexBar", "Codex Bar", "com.steipete.codexbar"],
            "craft": ["Craft", "com.lukilabs.lukiapp"],
            "xmind": ["Xmind", "XMind", "XMind ZEN", "net.xmind.vana.app"],
            "code": ["Code", "Visual Studio Code", "com.microsoft.VSCode"],
            "openai": ["ChatGPT", "ChatGPT Classic", "com.openai.chat"],
            "codex": ["Codex", "OpenAI Codex", "com.openai.codex"],
            "edrawmax": ["万兴图示", "亿图图示", "EdrawMax", "Edraw Max", "Wondershare EdrawMax", "com.edrawsoft.edrawmax"],
            "edrawmind": ["万兴脑图", "亿图脑图", "MindMaster", "EdrawMind", "Edraw Mind", "Wondershare EdrawMind", "com.edrawsoft.mindmaster"],
            "zcode": ["ZCode", "ZCode Preview", "zcode", "dev.zcode.app"],
            "kimi_code": ["Kimi Code", "com.kimi.code.desktop"],
            "kimi": ["Kimi", "KimiCU"],
            "surge": ["Surge", "com.nssurge.surge-mac"],
            "loopback": ["Loopback", "com.rogueamoeba.Loopback"],
            "qoder": ["Qoder", "Qoder CN", "Qoder CN IDE", "QoderWork", "com.aliyun.lingma.ide"],
            "workbuddy": ["WorkBuddy", "Work Buddy", "com.tencent.workbuddy.mac"],
            "trae": ["TRAE", "Trae CN", "TRAE SOLO CN", "Trae Work", "TraeWork", "cn.trae.solo.app"],
            "doubao_work": ["DoubaoWork", "Doubao Work", "豆包办公", "com.work.pc.doubao"],
            "doubao": ["Doubao", "豆包"],
            "camtasia": ["Camtasia", "Camtasia 2026", "com.techsmith.camtasia"],
            "cola": ["Cola", "ai.colaos.desktop"],
            "preview": ["Preview", "预览"],
            "default": ["Nonexistent Fixture App", "$(touch unsafe)", "Air", "EdrawMax Unrelated", "Not MindMaster"],
        }
        names = [name for values in groups.values() for name in values]
        result = subprocess.run(["/bin/bash", str(CONFIG / "plugins/icon_map.sh"), *names],
                                capture_output=True, text=True, check=True)
        expected = [":" + token + ":" for token, values in groups.items() for _ in values]
        self.assertEqual(expected, result.stdout.splitlines())
        self.assertEqual("", result.stderr)

    def test_sourcing_is_silent_and_strict_shell_safe(self):
        result = subprocess.run(["/bin/bash", "-euc", 'source "$1"; __icon_map "Kimi Code"; printf "%s" "$icon_result"',
                                 "_", str(CONFIG / "plugins/icon_map.sh")], capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(":kimi_code:", result.stdout)

    def test_preserved_theme_and_custom_family(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "bar with space"
            shutil.copytree(CONFIG, config)
            for family, expected in (("sketchybar-app-font", "AI First App Icons"),
                                     ("Custom App Font", "Custom App Font")):
                (config / "theme.conf").write_text('SKETCHYBAR_FONT_APP="' + family + '"\n')
                env = {k: v for k, v in os.environ.items() if not k.startswith("SKETCHYBAR_")}
                env["SKETCHYBAR_THEME_CONFIG_DIR"] = str(config)
                result = subprocess.run(["/bin/bash", str(config / "lib/theme.sh"), "get", "THEME_FONT_APP"],
                                        env=env, capture_output=True, text=True, check=True)
                self.assertEqual(expected, result.stdout.strip())
                self.assertIn(family, (config / "theme.conf").read_text())

    def test_font_load_before_bar_and_failure_stops_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "bar with space 中文"
            shutil.copytree(CONFIG, config)
            log = Path(directory) / "calls"
            script = '''sketchybar() { printf '%s\\n' "$*" >> "$CALL_LOG"; return "$STUB_EXIT"; }
source "$CONFIG_DIR/sketchybarrc"
'''
            env = {k:v for k,v in os.environ.items() if not k.startswith(("SKETCHYBAR_", "AI_FIRST_"))}
            env.update(CONFIG_DIR=str(config), CALL_LOG=str(log), AI_FIRST_PROFILE_LIB=str(config / "absent"),
                       AI_FIRST_BAR_LEFT_ITEMS="", AI_FIRST_BAR_CENTER_ITEMS="", AI_FIRST_BAR_RIGHT_ITEMS="")
            for status in (0, 1):
                log.write_text("")
                result = subprocess.run(["/bin/bash", "-c", script], env=dict(env, STUB_EXIT=str(status)),
                                        capture_output=True, text=True)
                self.assertEqual(status, result.returncode, result.stderr)
                calls = log.read_text().splitlines()
                self.assertEqual("--load-font " + (config / "fonts/ai-first-app-icons.ttf").as_uri(), calls[0])
                self.assertEqual(status == 0, any(c.startswith("--bar ") for c in calls))
            font_path = config / "fonts/ai-first-app-icons.ttf"
            manifest_path = config / "fonts/manifest.json"
            original_font, original_manifest = font_path.read_bytes(), manifest_path.read_bytes()
            for corrupt in (font_path, manifest_path):
                font_path.write_bytes(original_font)
                manifest_path.write_bytes(original_manifest)
                corrupt.write_bytes(b"broken fixture")
                log.write_text("")
                result = subprocess.run(["/bin/bash", "-c", script], env=dict(env, STUB_EXIT="0"),
                                        capture_output=True, text=True)
                self.assertNotEqual(0, result.returncode)
                self.assertIn("verification failed", result.stderr)
                self.assertEqual("", log.read_text())
            (config / "fonts/ai-first-app-icons.ttf").unlink()
            log.write_text("")
            result = subprocess.run(["/bin/bash", "-c", script], env=dict(env, STUB_EXIT="0"),
                                    capture_output=True, text=True)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("font is missing", result.stderr)
            self.assertEqual("", log.read_text())


if __name__ == "__main__":
    if os.environ.get("AI_FIRST_TEST_ISOLATED") != "1":
        raise SystemExit("Run via tests/run-all.sh tests/smoke/app_icons_smoke.sh")
    unittest.main()
