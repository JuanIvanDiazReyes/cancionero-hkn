# Cancionero HKN

App para iOS (iPhone y iPad), CTEA, para leer cancioneros en formato cuaderno: acordes, cambio de tono, anotaciones, marcas de voz e instrumentos. Uso personal.

Plan aprobado: SwiftUI + PencilKit + SwiftData, iOS 17+, en cinco fases.

| Fase | Contenido |
| --- | --- |
| 1 | Importar el cancionero (.md → JSON) |
| 2 | Lector y transposición |
| 3 | Cuaderno: voces, instrumentos, iconos, dibujo |
| 4 | Edición musical: tempo, acordes, letra, melodía |
| 5 | Personalización y respaldo |

## Abrir la app en Xcode

1. Abre `App/CancioneroHKN.xcodeproj`.
2. En el proyecto, pestaña **Signing & Capabilities**, elige tu Apple ID en **Team** (cuenta gratuita sirve).
3. Conecta el iPhone, elígelo arriba y pulsa ▶︎ (Run).

Con una cuenta gratuita la app caduca a los 7 días; vuelve a pulsar Run para renovarla. Tus ajustes no se pierden.

## Estructura

| Carpeta | Qué hay |
| --- | --- |
| `App/` | Proyecto de Xcode y pantallas de la app (SwiftUI + SwiftData) |
| `CancioneroCore/` | Paquete Swift con el modelo de canciones, transposición y búsqueda, con pruebas |
| `tools/importer/` | Scripts que convierten el cancionero `.md` a `data/songbook.json` y a `.ctea` |
| `data/` | Cancionero original, JSON generado y `Cancionero HKN 2026.ctea` |

## Canciones aparte de la app

La app no trae canciones. La primera vez muestra **Importar cancionero**: elige un archivo `.ctea`
(o tócalo en Archivos, WhatsApp, Mail o AirDrop y se abre en CTEA). En **Ajustes → Exportar cancionero**
se comparte un `.ctea` con tus ediciones y canciones propias («Solo canciones») o con todo («Todo»).
Al importar con canciones ya cargadas se elige **Combinar** o **Reemplazar todo**.

Un `.ctea` es JSON: `{"format": "ctea", "version": 1, "name", "exportedAt", "songs", "notebook"}`
(ver `CancioneroCore/Sources/CancioneroCore/CteaFile.swift`). La app también importa las copias de
seguridad `.json` anteriores.

Si cambias el cancionero `.md`, regenera el JSON y el `.ctea`:

```sh
python3 tools/importer/import_songbook.py data/source/HKN_2026_cancionero_acordes.md data/songbook.json
python3 tools/importer/make_ctea.py data/songbook.json "data/Cancionero HKN 2026.ctea"
```

Pruebas: `python3 -m unittest discover -s tools/importer` y, en la Mac, `cd CancioneroCore && swift test`.
