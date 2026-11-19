# SPDX-License-Identifier: MIT
"""SET-9-38: the packaged app declares its localizations and ships InfoPlist strings for each."""
import pathlib
import plistlib
import re
import unittest

TOOLS = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = (TOOLS / 'package-neutral.sh').read_text(encoding='utf-8')


class BundleLocalizationTests(unittest.TestCase):
    def info_plist(self):
        body = SCRIPT.split('Contents/Info.plist" <<PLIST', 1)[1].split('\nPLIST', 1)[0]
        body = body.replace('$cockpit_entry', 'false').replace('$owner_test_plist', '')
        return plistlib.loads(body.strip().encode('utf-8'))

    def test_declares_english_and_simplified_chinese(self):
        info = self.info_plist()
        self.assertEqual(info['CFBundleLocalizations'], ['en', 'zh-Hans'])
        self.assertEqual(info['CFBundleDevelopmentRegion'], 'en')

    def test_each_declared_localization_ships_user_visible_plist_strings(self):
        info = self.info_plist()
        for language in info['CFBundleLocalizations']:
            match = re.search(r'%s\.lproj/InfoPlist\.strings" <<\'STRINGS\'\n(.*?)\nSTRINGS' % re.escape(language), SCRIPT, re.S)
            self.assertIsNotNone(match, language)
            keys = re.findall(r'^"(\w+)" = ', match.group(1), re.M)
            self.assertEqual(keys, ['CFBundleDisplayName', 'NSHumanReadableCopyright'], language)
        # The Chinese text is Chinese.
        zh = re.search(r"zh-Hans\.lproj/InfoPlist\.strings\" <<'STRINGS'\n(.*?)\nSTRINGS", SCRIPT, re.S).group(1)
        self.assertRegex(zh, r'[\u4e00-\u9fff]')

if __name__ == '__main__':
    unittest.main()
