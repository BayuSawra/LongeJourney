import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

PATH = Path(__file__).resolve().parents[1] / "localization.py"
spec = importlib.util.spec_from_file_location("lj_localization", PATH)
localization = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = localization
spec.loader.exec_module(localization)


class LocalizationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = {"ui.test": localization.Message("ui.test", "Source {name} [i]text[/i]")}
        self.target = {"ui.test": localization.Message("ui.test", "Target {name} [i]text[/i]", ["#. source-sha256: " + localization.source_hash(self.source["ui.test"].text)])}
        self.write()

    def write(self):
        localization.write_po(self.root / "zh_CN.po", "zh_CN", self.source, "nplurals=1; plural=0;")
        localization.write_po(self.root / "en.po", "en", self.target, "nplurals=2; plural=(n != 1);")

    def test_roundtrip(self):
        catalogs = localization.validate_catalogs(self.root)
        self.assertEqual(len(catalogs), 2)
        self.assertEqual(catalogs["en"]["ui.test"].text, self.target["ui.test"].text)

    def test_multiline_quotes_and_unicode(self):
        path = self.root / "en.po"
        self.target["ui.test"].text = 'One "quote"\nTwo \\three\t\u4e2d'
        self.write()
        _, messages = localization.read_po(path)
        self.assertEqual(messages["ui.test"].text, self.target["ui.test"].text)
        path.write_text(path.read_text(encoding="utf-8") + '\nmsgid "other"\nmsgstr "line one\\n"\n"line two"\n', encoding="utf-8")
        self.assertEqual(localization.read_po(path)[1]["other"].text, "line one\nline two")

    def test_duplicate_key_rejected(self):
        path = self.root / "en.po"
        with path.open("a", encoding="utf-8") as file:
            file.write('\nmsgid "ui.test"\nmsgstr "Duplicate"\n')
        with self.assertRaisesRegex(ValueError, "duplicate ID"):
            localization.read_po(path)

    def test_missing_translation_rejected(self):
        self.target.clear()
        self.write()
        with self.assertRaisesRegex(ValueError, "ID mismatch"):
            localization.validate_catalogs(self.root)

    def test_extra_translation_rejected(self):
        self.target["extra"] = localization.Message("extra", "Extra")
        self.write()
        with self.assertRaisesRegex(ValueError, "ID mismatch"):
            localization.validate_catalogs(self.root)

    def test_blank_translation_rejected(self):
        self.target["ui.test"].text = "   "
        self.write()
        with self.assertRaisesRegex(ValueError, "empty ID/translation"):
            localization.validate_catalogs(self.root)

    def test_fuzzy_rejected(self):
        self.target["ui.test"].flags.add("fuzzy")
        self.write()
        with self.assertRaisesRegex(ValueError, "needs review"):
            localization.validate_catalogs(self.root)

    def test_source_change_requires_review(self):
        self.source["ui.test"].text += " changed"
        self.write()
        with self.assertRaisesRegex(ValueError, "source changed"):
            localization.validate_catalogs(self.root)

    def test_missing_stamp_requires_review(self):
        self.target["ui.test"].comments.clear()
        self.write()
        with self.assertRaisesRegex(ValueError, "source changed"):
            localization.validate_catalogs(self.root)

    def test_placeholder_or_markup_change_rejected(self):
        for value in ["Target {other} [i]text[/i]", "Target {name} [b]text[/b]", "Target {name} {name} [i]text[/i]"]:
            with self.subTest(value=value):
                self.target["ui.test"].text = value
                self.write()
                with self.assertRaisesRegex(ValueError, "placeholder/markup mismatch"):
                    localization.validate_catalogs(self.root)

    def test_moving_placeholders_is_valid(self):
        self.target["ui.test"].text = "[i]text[/i] Target {name}"
        self.write()
        localization.validate_catalogs(self.root)

    def test_markdown_protects_targets_not_labels(self):
        self.assertEqual(localization.tokens("[flower](items/flower.md)"), localization.tokens("[Fleur](items/flower.md)"))
        self.assertNotEqual(localization.tokens("[flower](items/flower.md)"), localization.tokens("[flower](other.md)"))

    def test_language_filename_mismatch_rejected(self):
        path = self.root / "en.po"
        path.write_text(path.read_text(encoding="utf-8").replace("Language: en", "Language: fr"), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Language header"):
            localization.read_po(path)

    def test_malformed_or_incomplete_entry_rejected(self):
        for value in ['msgid "key"\n', 'msgid "key"\nmsgstr bad\n', 'msgid "key"\nmsgstr "one"\nmsgstr "two"\n']:
            path = self.root / "en.po"
            path.write_text(value, encoding="utf-8")
            with self.assertRaises(ValueError):
                localization.read_po(path)

    def test_unsupported_plural_not_silently_skipped(self):
        path = self.root / "en.po"
        with path.open("a", encoding="utf-8") as file:
            file.write('\nmsgid "apple"\nmsgid_plural "apples"\nmsgstr[0] "apple"\n')
        with self.assertRaisesRegex(ValueError, "unsupported PO directive"):
            localization.read_po(path)

    def test_obsolete_not_silently_skipped(self):
        path = self.root / "en.po"
        with path.open("a", encoding="utf-8") as file:
            file.write('\n#~ msgid "old"\n')
        with self.assertRaisesRegex(ValueError, "obsolete"):
            localization.read_po(path)

    def test_init_locale_creates_only_blank_unreviewed_entries(self):
        self.assertEqual(localization.init_locale(self.root, "fr", "nplurals=2; plural=(n > 1);"), 1)
        header, messages = localization.read_po(self.root / "fr.po")
        self.assertEqual(header["Language"], "fr")
        self.assertEqual(messages["ui.test"].text, "")
        self.assertIn("fuzzy", messages["ui.test"].flags)
        with self.assertRaisesRegex(ValueError, "already exists"):
            localization.init_locale(self.root, "fr", "nplurals=2; plural=(n > 1);")

    def test_locale_rejects_paths_and_noncanonical_codes(self):
        for value in ["../en", "en/US", "", "zh-CN", "FR", "x\n"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                localization.validate_locale(value)
        for value in ["en", "zh_CN", "pt_BR", "sr_Latn_RS", "es_419"]:
            localization.validate_locale(value)

    def test_sync_preserves_existing_translations_and_stamps(self):
        self.source["ui.new"] = localization.Message("ui.new", "New source")
        self.write()
        old = localization.read_po(self.root / "en.po")[1]["ui.test"]
        self.assertEqual(localization.sync_locale(self.root, "en"), 1)
        updated = localization.read_po(self.root / "en.po")[1]
        self.assertEqual(updated["ui.test"], old)
        self.assertEqual(updated["ui.new"].text, "")
        self.assertIn("fuzzy", updated["ui.new"].flags)
        self.assertEqual(localization.sync_locale(self.root, "en"), 0)

    def test_sync_does_not_silently_delete_retired_translation(self):
        self.target["retired"] = localization.Message("retired", "Keep for review")
        self.write()
        before = (self.root / "en.po").read_bytes()
        with self.assertRaisesRegex(ValueError, "retired IDs"):
            localization.sync_locale(self.root, "en")
        self.assertEqual((self.root / "en.po").read_bytes(), before)

    def test_segments_cannot_change_order(self):
        with self.assertRaisesRegex(ValueError, "segment order"):
            localization.validate_structure("A[n]B[n+]C", "A[n+]B[n]C", "test")

    def test_bbcode_requires_balanced_nesting(self):
        with self.assertRaisesRegex(ValueError, "unbalanced"):
            localization.validate_structure("[b][i]X[/i][/b]", "[b][i]X[/b][/i]", "test")


if __name__ == "__main__":
    unittest.main()
