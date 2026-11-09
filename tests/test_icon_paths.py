#!/usr/bin/env python3
"""Host tests for the icon catalogue (stdlib unittest).

  python3 tests/test_icon_paths.py

Checks the PDF path extractor on two real official icons and that the
generated TGIconPaths.m carries every name from scripts/icon_picks.txt once.
"""
import os
import re
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))

import official_icon

NUM = re.compile(r'[-+]?(?:\d+\.\d*|\.\d+|\d+)')


class OfficialIconTests(unittest.TestCase):
    def check_icon(self, spec):
        d, w, h = official_icon.icon_path(spec)
        self.assertTrue(d, spec)
        self.assertTrue(d.startswith('M'), spec)
        nums = [float(x) for x in NUM.findall(d)]
        xs, ys = nums[0::2], nums[1::2]
        self.assertTrue(xs and ys, spec)
        # A path that runs outside the MediaBox is clipped or shifted when
        # TGSVGPath maps it into an icon box.
        self.assertGreaterEqual(min(xs), -0.5, spec)
        self.assertLessEqual(max(xs), w + 0.5, spec)
        self.assertGreaterEqual(min(ys), -0.5, spec)
        self.assertLessEqual(max(ys), h + 0.5, spec)

    def test_add_story_pdf(self):
        self.check_icon('Chat List/AddStoryIcon')

    def test_add_pdf(self):
        self.check_icon('Navigation/Add')


class GeneratedCatalogueTests(unittest.TestCase):
    def setUp(self):
        self.picks = os.path.join(ROOT, 'scripts', 'icon_picks.txt')
        self.catalog = os.path.join(ROOT, 'src', 'Views', 'Icons',
                                    'TGIconPaths.m')

    def test_every_pick_is_in_the_catalogue_once(self):
        subprocess.run([sys.executable,
                        os.path.join(ROOT, 'scripts', 'gen_icon_paths.py')],
                       check=True, cwd=ROOT, stdout=subprocess.DEVNULL)
        with open(self.catalog) as handle:
            text = handle.read()
        entries = re.findall(r'\{"([^"]+)", \d+, \d+, \d+, "', text)
        counts = {}
        for name in entries:
            counts[name] = counts.get(name, 0) + 1
        wanted = []
        with open(self.picks) as handle:
            for line in handle:
                parts = line.split()
                if len(parts) < 3 or line.startswith('#') or parts[2] == 'ours':
                    continue
                wanted.append(parts[1])
        self.assertTrue(wanted)
        self.assertEqual(len(wanted), len(set(wanted)), 'duplicate pick name')
        for name in wanted:
            self.assertEqual(counts.get(name), 1, name)
        self.assertEqual(len(entries), len(wanted))


if __name__ == '__main__':
    unittest.main(verbosity=2)
