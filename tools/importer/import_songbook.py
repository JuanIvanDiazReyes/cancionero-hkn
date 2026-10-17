#!/usr/bin/env python3
"""Convierte el cancionero en Markdown (acordes encima de la letra) a JSON.

Uso:
    python3 tools/importer/import_songbook.py \
        data/source/HKN_2026_cancionero_acordes.md data/songbook.json \
        --report docs/fase1/informe.md --sample docs/fase1/muestra.md

Formato de salida (data/songbook.json):
    {"version": 1, "songs": [Song, ...]}
    Song   = {id, number, title, album, capo, chordDefinitions, blocks}
    Block  = {label, lines: [Line, ...]}           # separados por línea en blanco
    Line   = {"type": "lyric", "text", "chords": [{"pos", "chord"}]}
           | {"type": "instrumental", "label", "chords": [str], "text"}
           | {"type": "directive", "text"}            # p. ej. "(ESTRIBILLO X3)"
    `pos` es el índice (en caracteres, texto NFC) de la sílaba sobre la que
    se toca el acorde; pos == len(text) significa al final de la línea.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from dataclasses import dataclass, field

# --- Acordes -----------------------------------------------------------------

ROOT = r"[A-G](?:#|b)?"
QUALITY = r"(?:maj7|maj9|maj|min|m|dim|aug|sus2|sus4|sus|Sus|add9|add11|add2|add4|\+|º|°)?"
EXT = r"(?:maj7|maj9|m7|m9|7|9|11|13|6|5|sus2|sus4|sus|add9|add11|add2|add4|b5|#5|b9|#9|#11|M7|\(.*?\))*"
# "*" y "…" son marcas del PDF (acorde rasgueado/sostenido); "E/Am" aparece tal cual.
CHORD_RE = re.compile(rf"^{ROOT}{QUALITY}{EXT}(?:/{ROOT}m?)?[*…]?$")
# Secuencias pegadas tipo "DED" o "DED-EDEDE" (riffs rápidos sobre una sílaba).
RIFF_RE = re.compile(r"^(?:[A-G](?:#|b)?m?)+(?:-(?:[A-G](?:#|b)?m?)+)*$")
# Erratas conocidas del PDF original.
CHORD_FIXES = {"Fm#": "F#m", "Cm#": "C#m", "Gm#": "G#m", "Dm#": "D#m", "Am#": "A#m"}
# Tokens que pueden ir en una línea de acordes sin ser acordes.
FILLER_RE = re.compile(r"^(?:-|–|—|/|\||\(x\d+\)|x\d+|\(|\)|…|\.\.\.)$", re.I)

LABELS = ("INTRO", "OUTRO", "OUT", "SOLO", "PUENTE", "ESTRIBILLO", "CORO",
          "INTERLUDIO", "FINAL", "ESTROFA", "PRECORO")
LABEL_LINE_RE = re.compile(rf"^\s*({'|'.join(LABELS)})\s*:\s*(.*)$", re.I)
DIRECTIVE_RE = re.compile(r"^\s*\(([^()]*)\)\s*$")
CAPO_RE = re.compile(r"^\s*Cejilla\s+(\d+)\s*(?:º|°|er|o|ro|do|to)?\.?\s*traste", re.I)
CHORD_DEF_RE = re.compile(r"^\s*([A-G][^\s:]*)\s*:\s*([0-9xX ]{6,})\s*$")

# Palabras con las que un verso partido suele terminar (no cierran frase).
DANGLING_WORDS = {
    "a", "al", "con", "de", "del", "el", "en", "la", "las", "lo", "los", "me",
    "mi", "mis", "nos", "para", "por", "que", "se", "su", "sus", "te", "tu",
    "tus", "un", "una", "y", "e", "o", "ni", "sin", "sobre", "como", "cuando",
    "hasta", "desde", "entre", "hacia", "le", "les", "muy", "más", "tan",
}
TERMINAL_PUNCT = tuple(".,;:!?¡¿)]»”\"…")
SPLIT_MIN_LEN = 26  # Las columnas del PDF parten versos de ~30-40 caracteres.


def normalize_chord(tok: str) -> str:
    return CHORD_FIXES.get(tok, tok)


# Nombres de acorde que una canción define con su diagrama (p. ej. "Cd" en la 94).
_song_chord_names: set[str] = set()


def is_chord_token(tok: str) -> bool:
    tok = normalize_chord(tok)
    return bool(CHORD_RE.match(tok) or RIFF_RE.match(tok) or tok in _song_chord_names)


def is_chord_line(line: str) -> bool:
    toks = line.split()
    if not toks:
        return False
    chords = [t for t in toks if not FILLER_RE.match(t)]
    return bool(chords) and all(is_chord_token(t) for t in chords)


def chord_positions(line: str) -> list[tuple[int, str]]:
    out = []
    for m in re.finditer(r"\S+", line):
        tok = m.group(0)
        if FILLER_RE.match(tok):
            continue
        out.append((m.start(), normalize_chord(tok)))
    return out


# --- Modelo intermedio -------------------------------------------------------

@dataclass
class Lyric:
    text: str
    chords: list[tuple[int, str]] = field(default_factory=list)
    src_line: int = 0
    seg_len: int = -1  # largo del último trozo físico (tras unir versos)

    def __post_init__(self):
        if self.seg_len < 0:
            self.seg_len = len(self.text)

    def as_json(self):
        return {"type": "lyric", "text": self.text,
                "chords": [{"pos": p, "chord": c} for p, c in self.chords]}


@dataclass
class Song:
    number: int
    title: str
    album: str
    src_line: int
    raw: list[tuple[int, str]] = field(default_factory=list)
    capo: int | None = None
    chord_defs: dict = field(default_factory=dict)
    blocks: list = field(default_factory=list)
    doubts: list = field(default_factory=list)
    joins: int = 0


def slugify(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


# --- Lectura del Markdown ----------------------------------------------------

def read_songs(path: str) -> list[Song]:
    text = unicodedata.normalize("NFC", open(path, encoding="utf-8").read())
    songs: list[Song] = []
    album = None
    cur: Song | None = None
    in_code = False
    for i, line in enumerate(text.split("\n"), start=1):
        if line.startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            if cur is not None:
                cur.raw.append((i, line.rstrip()))
            continue
        if line.startswith("## ") and not line.startswith("### "):
            name = line[3:].strip()
            album = None if name.lower() == "índice" else name
        elif line.startswith("### ") and album:
            m = re.match(r"###\s+(\d+)\.\s+(.*)$", line)
            if m:
                cur = Song(int(m.group(1)), m.group(2).strip(), album, i)
                songs.append(cur)
    return songs


# --- Análisis de cada canción -------------------------------------------------

def parse_song(song: Song) -> None:
    # 1) Metadatos al inicio: cejilla y diagramas de acordes.
    _song_chord_names.clear()
    for _, line in song.raw:
        d = CHORD_DEF_RE.match(line)
        if d:
            _song_chord_names.add(normalize_chord(d.group(1)))
    body = []
    for ln, line in song.raw:
        m = CAPO_RE.match(line)
        if m and song.capo is None:
            song.capo = int(m.group(1))
            continue
        d = CHORD_DEF_RE.match(line)
        if d and not is_chord_line(line):
            song.chord_defs[normalize_chord(d.group(1))] = " ".join(d.group(2).split())
            continue
        body.append((ln, line))

    # 2) Bloques separados por líneas en blanco.
    raw_blocks, buf = [], []
    for ln, line in body:
        if line.strip():
            buf.append((ln, line))
        elif buf:
            raw_blocks.append(buf)
            buf = []
    if buf:
        raw_blocks.append(buf)

    # 3) Cada bloque: pares acorde+letra, líneas instrumentales, directivas.
    for rb in raw_blocks:
        items = []
        k = 0
        while k < len(rb):
            ln, line = rb[k]
            nxt = rb[k + 1][1] if k + 1 < len(rb) else None
            lab = LABEL_LINE_RE.match(line)
            if lab:
                rest = lab.group(2)
                label = lab.group(1).upper()
                if rest.strip() and not is_chord_line(rest):
                    song.doubts.append((ln, f"Etiqueta {label} con contenido que no son acordes: «{rest.strip()}»"))
                items.append({"type": "instrumental", "label": label,
                              "chords": [c for _, c in chord_positions(rest)] if is_chord_line(rest) else [],
                              "text": line.strip()})
                k += 1
                continue
            if DIRECTIVE_RE.match(line) and not is_chord_line(line):
                items.append({"type": "directive", "text": line.strip()})
                k += 1
                continue
            if is_chord_line(line):
                if nxt is not None and not is_chord_line(nxt) and not LABEL_LINE_RE.match(nxt) \
                        and not (DIRECTIVE_RE.match(nxt)):
                    lyric = rb[k + 1][1]
                    chords = []
                    for col, ch in chord_positions(line):
                        chords.append((min(col, len(lyric.rstrip())), ch))
                    items.append(Lyric(lyric.strip(), _shift(chords, lyric), rb[k + 1][0]))
                    k += 2
                    continue
                items.append({"type": "instrumental", "label": None,
                              "chords": [c for _, c in chord_positions(line)],
                              "text": line.strip()})
                k += 1
                continue
            items.append(Lyric(line.strip(), [], ln))
            k += 1
        song.blocks.append(items)

    # 4) Unir versos partidos por las dos columnas del PDF.
    _join_split_lines(song)

    # 5) Etiquetas de bloque.
    out = []
    for items in song.blocks:
        label = None
        if items and isinstance(items[0], dict) and items[0]["type"] == "instrumental" and items[0]["label"]:
            label = items[0]["label"] if len(items) == 1 else None
        out.append({"label": label,
                    "lines": [it.as_json() if isinstance(it, Lyric) else it for it in items]})
    song.blocks = out

    # 6) Comprobaciones.
    for b in song.blocks:
        for l in b["lines"]:
            if l["type"] == "lyric":
                for c in l["chords"]:
                    if not is_chord_token(c["chord"]):
                        song.doubts.append((0, f"Acorde no reconocido «{c['chord']}»"))


def _shift(chords, lyric):
    """La letra se guarda sin la sangría inicial: ajusta las columnas."""
    indent = len(lyric) - len(lyric.lstrip())
    return [(max(0, p - indent), c) for p, c in chords]


def _ends_open(text: str) -> bool:
    t = text.rstrip()
    if not t or t.endswith(TERMINAL_PUNCT):
        return False
    return True


def _join_split_lines(song: Song) -> None:
    """Une una línea de letra con la siguiente cuando el PDF la partió.

    Seguro: la línea anterior no termina en puntuación y la siguiente empieza
    en minúscula, o la anterior termina en una palabra que no cierra frase
    ("tu", "de", "la"...). En ambos casos la anterior debe ser larga, como las
    líneas que el PDF corta por ancho de columna.
    Dudoso (se une y se anota en el informe): la siguiente empieza en
    mayúscula pero la anterior acaba en palabra que no cierra frase.
    """
    for bi, items in enumerate(song.blocks):
        merged = []
        for it in items:
            prev = merged[-1] if merged else None
            if isinstance(it, Lyric) and isinstance(prev, Lyric) and prev.text and it.text:
                last_word = re.findall(r"[\wáéíóúñü]+$", prev.text.lower())
                dangling = bool(last_word) and last_word[0] in DANGLING_WORDS
                first = it.text.lstrip("¡¿(«\"“")[:1]
                lower_start = first.islower()
                long_prev = prev.seg_len >= SPLIT_MIN_LEN
                if _ends_open(prev.text) and long_prev and (lower_start or dangling):
                    if not lower_start:
                        song.doubts.append((it.src_line,
                            f"Unidas por palabra final «{last_word[0]}»: «{prev.text} | {it.text}»"))
                    offset = len(prev.text) + 1
                    prev.chords += [(p + offset, c) for p, c in it.chords]
                    prev.text = f"{prev.text} {it.text}"
                    prev.seg_len = len(it.text)
                    song.joins += 1
                    continue
            merged.append(it)
        song.blocks[bi] = merged
    # Primera línea de un bloque en minúscula: posible verso partido por una
    # línea en blanco del PDF.
    for items in song.blocks:
        if items and isinstance(items[0], Lyric) and items[0].text[:1].islower():
            song.doubts.append((items[0].src_line,
                f"Bloque que empieza en minúscula (¿continúa el anterior?): «{items[0].text}»"))


# --- Salidas -------------------------------------------------------------------

def song_json(s: Song) -> dict:
    return {"id": f"{s.number:03d}-{slugify(s.title)}", "number": s.number,
            "title": s.title, "album": s.album, "capo": s.capo,
            "chordDefinitions": s.chord_defs, "blocks": s.blocks}


def render_chords_over_lyrics(line: dict) -> str:
    text, chords = line["text"], line["chords"]
    if not chords:
        return text
    top = ""
    for c in chords:
        pos = max(c["pos"], len(top) + (1 if top else 0))
        top = top.ljust(pos) + c["chord"]
    return top.rstrip() + "\n" + text


def render_song(s: dict) -> str:
    out = [f"### {s['number']}. {s['title']}", "",
           f"Álbum: {s['album']}" + (f" · Cejilla {s['capo']}" if s["capo"] else ""), "", "```text"]
    for name, frets in s["chordDefinitions"].items():
        out.append(f"{name}: {frets}")
    for b in s["blocks"]:
        for l in b["lines"]:
            out.append(render_chords_over_lyrics(l) if l["type"] == "lyric" else l["text"])
        out.append("")
    if out[-1] == "":
        out.pop()
    out += ["```", ""]
    return "\n".join(out)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("source")
    ap.add_argument("output")
    ap.add_argument("--report")
    ap.add_argument("--sample")
    ap.add_argument("--sample-ids", default="1,2,15,25,40,53,63,74,93,94")
    a = ap.parse_args(argv)

    songs = read_songs(a.source)
    for s in songs:
        parse_song(s)
    data = {"version": 1, "source": a.source.split("/")[-1], "songs": [song_json(s) for s in songs]}
    with open(a.output, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")

    total_joins = sum(s.joins for s in songs)
    with_doubts = [s for s in songs if s.doubts]
    print(f"{len(songs)} canciones, {total_joins} versos unidos, "
          f"{sum(len(s.doubts) for s in songs)} dudas en {len(with_doubts)} canciones → {a.output}")

    if a.report:
        lines = ["# Fase 1 · Informe de importación", "",
                 f"- Canciones importadas: {len(songs)}",
                 f"- Versos partidos que se unieron automáticamente: {total_joins}",
                 f"- Canciones con cejilla: {sum(1 for s in songs if s.capo)}",
                 f"- Canciones con dudas para revisar a mano: {len(with_doubts)}", "",
                 "Cada duda indica la línea del archivo original (`data/source/...md`).", ""]
        for s in with_doubts:
            lines.append(f"## {s.number}. {s.title}")
            lines.append("")
            for ln, msg in s.doubts:
                lines.append(f"- {'línea ' + str(ln) + ': ' if ln else ''}{msg}")
            lines.append("")
        open(a.report, "w", encoding="utf-8").write("\n".join(lines))
    if a.sample:
        ids = {int(x) for x in a.sample_ids.split(",")}
        parts = ["# Fase 1 · Muestra de canciones convertidas", "",
                 "Así quedan las canciones después de la conversión: versos partidos unidos y "
                 "acordes recolocados sobre la sílaba. Compáralas con el cancionero original.", ""]
        parts += [render_song(sj) for sj in data["songs"] if sj["number"] in ids]
        open(a.sample, "w", encoding="utf-8").write("\n".join(parts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
