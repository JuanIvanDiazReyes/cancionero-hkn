"""Genera el archivo .ctea que se importa en la app a partir de data/songbook.json.

Uso:
    python3 tools/importer/make_ctea.py data/songbook.json "data/Cancionero HKN 2026.ctea" \
        --name "Cancionero HKN 2026"

Formato (lo lee CteaFile en CancioneroCore):
    {"format": "ctea", "version": 1, "name": ..., "exportedAt": ISO 8601, "songs": [...]}
Las canciones van con el mismo formato que songbook.json. Sin "notebook": no trae
anotaciones, ediciones ni listas.
"""
import argparse
import datetime
import json


def make_ctea(songbook: dict, name: str, exported_at: str) -> dict:
    return {
        "format": "ctea",
        "version": 1,
        "name": name,
        "exportedAt": exported_at,
        "songs": songbook["songs"],
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("songbook")
    ap.add_argument("output")
    ap.add_argument("--name", default="Cancionero HKN 2026")
    args = ap.parse_args(argv)
    with open(args.songbook, encoding="utf-8") as f:
        songbook = json.load(f)
    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
    data = make_ctea(songbook, args.name, now.strftime("%Y-%m-%dT%H:%M:%SZ"))
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"{len(data['songs'])} canciones -> {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
