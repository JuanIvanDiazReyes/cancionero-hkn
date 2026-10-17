"""Pruebas del importador. Ejecutar: python3 -m unittest discover tools/importer"""
import json
import os
import tempfile
import unittest

import import_songbook as imp

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "data", "source", "HKN_2026_cancionero_acordes.md")


def parse(code_block: str) -> dict:
    md = "## TEST\n\n### 1. PRUEBA\n\n```text\n" + code_block.strip("\n") + "\n```\n"
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8") as f:
        f.write(md)
    try:
        song = imp.read_songs(f.name)[0]
    finally:
        os.unlink(f.name)
    imp.parse_song(song)
    return imp.song_json(song)


def lyrics(song: dict) -> list[dict]:
    return [l for b in song["blocks"] for l in b["lines"] if l["type"] == "lyric"]


class ChordTokens(unittest.TestCase):
    def test_common_chords(self):
        for c in ["A", "C#m", "D/F#", "Cadd9", "Em7/G", "Gsus4", "Fmaj7", "Bb", "G(add9)", "Bm*", "E/Am"]:
            self.assertTrue(imp.is_chord_token(c), c)

    def test_riffs(self):
        for c in ["DED", "DED-EDEDE", "GCGC"]:
            self.assertTrue(imp.is_chord_token(c), c)

    def test_words_are_not_chords(self):
        for w in ["Al", "estar", "Ti", "Dios", "Amor", "Cielo"]:
            self.assertFalse(imp.is_chord_token(w), w)

    def test_typo_fixed(self):
        self.assertEqual(imp.normalize_chord("Fm#"), "F#m")


class Parsing(unittest.TestCase):
    def test_chord_positions(self):
        s = parse("""
      A                       C#m
Al estar en la presencia de tu divinidad,
""")
        l = lyrics(s)[0]
        self.assertEqual(l["chords"], [{"pos": 6, "chord": "A"}, {"pos": 30, "chord": "C#m"}])
        self.assertEqual(l["text"][6:], "ar en la presencia de tu divinidad,")

    def test_split_line_joined_with_shifted_chords(self):
        s = parse("""
       E
Enciéndeme y déjame arder donde
      A
haga falta,
""")
        l = lyrics(s)
        self.assertEqual(len(l), 1)
        self.assertEqual(l[0]["text"], "Enciéndeme y déjame arder donde haga falta,")
        a = [c for c in l[0]["chords"] if c["chord"] == "A"][0]
        self.assertEqual(l[0]["text"][a["pos"]:], "alta,")

    def test_short_segment_ends_verse(self):
        s = parse("""
aquellas puestas en las que la
rompiente
abrazaba el anhelo de nuestro
permanente fuego.
""")
        self.assertEqual([l["text"] for l in lyrics(s)],
                         ["aquellas puestas en las que la rompiente",
                          "abrazaba el anhelo de nuestro permanente fuego."])

    def test_punctuated_lines_not_joined(self):
        s = parse("""
Solo así descubro cómo me amas,
solo así descubro cómo me quieres.
""")
        self.assertEqual(len(lyrics(s)), 2)

    def test_capo_labels_and_instrumental(self):
        s = parse("""
Cejilla 3er traste
INTRO: E D E D G

G Bm Em C Cm
(ESTRIBILLO X3)
""")
        self.assertEqual(s["capo"], 3)
        lines = [l for b in s["blocks"] for l in b["lines"]]
        self.assertEqual(lines[0]["label"], "INTRO")
        self.assertEqual(lines[0]["chords"], ["E", "D", "E", "D", "G"])
        self.assertEqual(lines[1]["type"], "instrumental")
        self.assertEqual(lines[2]["type"], "directive")


class WholeSongbook(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        out = tempfile.NamedTemporaryFile(suffix=".json", delete=False).name
        imp.main([SOURCE, out])
        cls.data = json.load(open(out, encoding="utf-8"))
        os.unlink(out)

    def test_all_songs(self):
        self.assertEqual(len(self.data["songs"]), 126)
        self.assertEqual([s["number"] for s in self.data["songs"]], list(range(1, 127)))

    def test_every_chord_parses_and_fits(self):
        for s in self.data["songs"]:
            for l in lyrics(s):
                for c in l["chords"]:
                    self.assertLessEqual(c["pos"], len(l["text"]), (s["id"], l["text"]))
                    self.assertTrue(imp.is_chord_token(c["chord"]) or c["chord"] in s["chordDefinitions"],
                                    (s["id"], c["chord"]))

    def test_no_empty_songs(self):
        for s in self.data["songs"]:
            self.assertTrue(lyrics(s), s["id"])


if __name__ == "__main__":
    unittest.main()
