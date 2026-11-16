import XCTest
@testable import CancioneroCore

final class ChordSymbolTests: XCTestCase {
    func testParsesQualitiesAndBass() throws {
        let fsm = try XCTUnwrap(ChordSymbol.parse("F#m7"))
        XCTAssertEqual(fsm.root, 6)
        XCTAssertEqual(fsm.quality, "m7")
        XCTAssertEqual(fsm.noteNames, ["F#", "A", "C#", "E"])

        let slash = try XCTUnwrap(ChordSymbol.parse("D/F#"))
        XCTAssertEqual(slash.root, 2)
        XCTAssertEqual(slash.bass, 6)

        XCTAssertEqual(ChordSymbol.parse("G(add9)")?.quality, "add9")
        XCTAssertEqual(ChordSymbol.parse("GSus")?.quality, "sus4")
        XCTAssertEqual(ChordSymbol.parse("F#sus")?.quality, "sus4")
        XCTAssertEqual(ChordSymbol.parse("Bb")?.root, 10)
        XCTAssertEqual(ChordSymbol.parse("Bb")?.usesFlats, true)
        XCTAssertEqual(ChordSymbol.parse("Bm*")?.isVariant, true)
        XCTAssertEqual(ChordSymbol.parse("Bm*")?.name, "Bm")
        XCTAssertEqual(ChordSymbol.parse("C/Am")?.bass, 9)
        XCTAssertNil(ChordSymbol.parse("GCD"))
        XCTAssertNil(ChordSymbol.parse("Cd"))
    }

    func testSplitsJoinedChords() {
        XCTAssertEqual(ChordSymbol.split("GCD").map(\.name), ["G", "C", "D"])
        XCTAssertEqual(ChordSymbol.split("A-E").map(\.name), ["A", "E"])
        XCTAssertEqual(ChordSymbol.split("Am…").map(\.name), ["Am"])
        XCTAssertEqual(ChordSymbol.split("EF#E-F#EF#").map(\.name), ["E", "F#", "E", "F#", "E", "F#"])
        XCTAssertEqual(ChordSymbol.split("Bb").map(\.name), ["Bb"])
        XCTAssertEqual(ChordSymbol.split("Em7/G").map(\.name), ["Em7/G"])
        XCTAssertTrue(ChordSymbol.split("Cd").isEmpty)
    }
}

final class GuitarChordTests: XCTestCase {
    func shapes(_ name: String) -> [String] {
        GuitarChords.shapes(for: ChordSymbol.parse(name)!).map(\.diagram)
    }

    func testCommonOpenChordsComeFirst() {
        XCTAssertEqual(shapes("C").first, "x32010")
        XCTAssertEqual(shapes("G").first, "320003")
        XCTAssertEqual(shapes("D").first, "xx0232")
        XCTAssertEqual(shapes("Am").first, "x02210")
        XCTAssertEqual(shapes("Em").first, "022000")
        XCTAssertEqual(shapes("F").first, "133211")
        XCTAssertEqual(shapes("Bm").first, "x24432")
        XCTAssertEqual(shapes("F#m").first, "244222")
    }

    func testSlashChords() {
        XCTAssertEqual(shapes("D/F#").first, "2x0232")
        XCTAssertEqual(shapes("G/B").first, "x20003")
        XCTAssertEqual(shapes("C/E").first, "032010")
        XCTAssertEqual(shapes("C/G").first, "332010")
        XCTAssertEqual(shapes("F/A").first, "x03211")
        XCTAssertEqual(shapes("Am/G").first, "302210")
    }

    func testFingers() {
        let f = GuitarShape(diagram: "133211")!
        XCTAssertEqual(f.barre, GuitarShape.Barre(fret: 1, from: 0, to: 5))
        XCTAssertEqual(f.fingers, [1, 3, 4, 2, 1, 1])

        let c = GuitarShape(diagram: "x32010")!
        XCTAssertNil(c.barre)
        XCTAssertEqual(c.fingers, [nil, 3, 2, nil, 1, nil])

        let d = GuitarShape(diagram: "xx0232")!
        XCTAssertNil(d.barre)
        XCTAssertEqual(d.fingers, [nil, nil, nil, 1, 3, 2])

        let dm7 = GuitarShape(diagram: "xx0211")!
        XCTAssertEqual(dm7.barre, GuitarShape.Barre(fret: 1, from: 4, to: 5))

        let bm = GuitarShape(diagram: "x24432")!
        XCTAssertEqual(bm.baseFret, 1)
        XCTAssertEqual(GuitarShape(diagram: "x57765")!.baseFret, 5)
    }

    func testCustomDiagramsFromTheSongbook() {
        XCTAssertEqual(GuitarShape(diagram: "x 2 4 4 3 0")?.diagram, "x24430")
        XCTAssertEqual(GuitarShape(diagram: "x02010")?.diagram, "x02010")
        XCTAssertNil(GuitarShape(diagram: "x0201"))
        let bm = ChordSymbol.parse("Bm*")!
        XCTAssertEqual(GuitarChords.shapes(for: bm, custom: "x 2 4 4 3 0").first?.diagram, "x24430")
    }

    /// Todas las posiciones escritas a mano suenan el acorde que dicen.
    func testOpenShapesAreCorrect() {
        for (root, quality, diagram) in GuitarChords.openShapes {
            let chord = ChordSymbol.parse(root + quality)!
            XCTAssertEqual(chord.quality, quality, root + quality)
            XCTAssertTrue(GuitarShape(diagram: diagram)!.plays(chord), "\(root)\(quality) \(diagram)")
        }
    }

    /// Cualquier acorde de cualquier tipo tiene al menos una posición correcta y tocable.
    func testEveryChordHasAPlayableShape() {
        let names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
        let kinds = Set(ChordSymbol.qualities.map(\.spelling))
        for name in names {
            for kind in kinds {
                let chord = ChordSymbol.parse(name + kind)!
                let found = GuitarChords.shapes(for: chord)
                XCTAssertFalse(found.isEmpty, name + kind)
                for shape in found {
                    XCTAssertTrue(shape.plays(chord), "\(name)\(kind) \(shape.diagram)")
                    XCTAssertLessThanOrEqual(shape.fingers.compactMap { $0 }.max() ?? 0, 4)
                }
            }
        }
    }

    /// Los 111 acordes distintos del cancionero se pueden mostrar.
    func testWholeSongbookHasDiagrams() throws {
        let lib = try SongLibrary(json: Data(contentsOf: SongbookTests.url))
        var missing: [String] = []
        for song in lib.songs {
            for token in Set(song.allChords) {
                if song.chordDefinitions[token] != nil { continue }
                let chords = ChordSymbol.split(token)
                if chords.isEmpty || chords.contains(where: { GuitarChords.shapes(for: $0).isEmpty }) {
                    missing.append(token)
                }
            }
        }
        XCTAssertEqual(missing, [])
    }
}

final class PianoVoicingTests: XCTestCase {
    func testRootPosition() {
        let c = PianoVoicing(chord: ChordSymbol.parse("C")!)
        XCTAssertEqual(c.keys, [0, 4, 7])
        XCTAssertNil(c.bassKey)
        XCTAssertEqual(c.octaves, 2)

        let am7 = PianoVoicing(chord: ChordSymbol.parse("Am7")!)
        XCTAssertEqual(am7.keys, [9, 12, 16, 19])
    }

    func testSlashAndNinth() {
        let dfs = PianoVoicing(chord: ChordSymbol.parse("D/F#")!)
        XCTAssertEqual(dfs.bassKey, 6)
        XCTAssertEqual(dfs.keys, [14, 18, 21])
        XCTAssertEqual(dfs.octaves, 2)

        let badd9 = PianoVoicing(chord: ChordSymbol.parse("Badd9")!)
        XCTAssertEqual(badd9.keys, [11, 15, 18, 25])
        XCTAssertEqual(badd9.octaves, 3)
        XCTAssertTrue(PianoVoicing.isBlack(25))
    }
}

final class SongLinksTests: XCTestCase {
    func kind(_ text: String) -> LinkKind? { SongLinks.url(from: text).map(LinkKind.detect) }

    func testDetectsServices() {
        XCTAssertEqual(kind("https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC?si=x"), .spotify)
        XCTAssertEqual(kind("spotify:track:4uLU6hMCjMI75M1A2tKUQC"), .spotify)
        XCTAssertEqual(kind("https://www.youtube.com/watch?v=dQw4w9WgXcQ"), .youtube)
        XCTAssertEqual(kind("https://youtu.be/dQw4w9WgXcQ"), .youtube)
        XCTAssertEqual(kind("https://music.youtube.com/watch?v=x"), .youtube)
        XCTAssertEqual(kind("https://drive.google.com/file/d/1abc/view"), .drive)
        XCTAssertEqual(kind("https://docs.google.com/document/d/1abc"), .drive)
        XCTAssertEqual(kind("https://music.apple.com/mx/album/x/1"), .appleMusic)
        XCTAssertEqual(kind("https://hakuna.org"), .other)
        XCTAssertEqual(kind("https://notspotify.com/x"), .other)
    }

    func testExtractsLinkFromSharedText() {
        let shared = "Escucha Al estar en la presencia en Spotify: https://open.spotify.com/track/abc?si=1"
        XCTAssertEqual(SongLinks.url(from: shared)?.absoluteString, "https://open.spotify.com/track/abc?si=1")
        XCTAssertEqual(SongLinks.url(from: "  youtu.be/abc \n")?.host, "youtu.be")
        XCTAssertNil(SongLinks.url(from: "hola"))
        XCTAssertNil(SongLinks.url(from: ""))
    }
}
