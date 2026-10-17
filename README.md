# Cancionero HKN

App para iOS (iPhone y iPad) con el cancionero de Hakuna Group Music en formato cuaderno: acordes, cambio de tono, anotaciones, marcas de voz e instrumentos. Uso personal.

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
| `tools/importer/` | Script que convierte el cancionero `.md` a `data/songbook.json` |
| `data/` | Cancionero original y JSON generado |

Si cambias el cancionero `.md`, regenera el JSON y cópialo a la app:

```sh
python3 tools/importer/import_songbook.py data/source/HKN_2026_cancionero_acordes.md data/songbook.json
cp data/songbook.json App/CancioneroHKN/Resources/songbook.json
```

Pruebas: `python3 -m unittest discover -s tools/importer` y, en la Mac, `cd CancioneroCore && swift test`.
