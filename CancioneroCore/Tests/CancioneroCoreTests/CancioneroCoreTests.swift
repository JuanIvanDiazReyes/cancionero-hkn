import XCTest
@testable import CancioneroCore

final class TransposerTests: XCTestCase {
    func t(_ chord: String, _ semitones: Int, _ acc: Accidentals = .sharps) -> String {
        Transposer.transpose(chord, by: semitones, accidentals: acc)
    }

    func testBasicChords() {
        XCTAssertEqual(t("C", 2), "D")
        XCTAssertEqual(t("Am", 3), "Cm")
        XCTAssertEqual(t("F#m", 1), "Gm")
        XCTAssertEqual(t("B7", 1), "C7")
        XCTAssertEqual(t("G", -2), "F")
        XCTAssertEqual(t("C", -1), "B")
    }

    func testSuffixesAndBass() {
        XCTAssertEqual(t("Cadd9", 2), "Dadd9")
        XCTAssertEqual(t("D/F#", 2), "E/G#")
        XCTAssertEqual(t("G/B", 2), "A/C#")
        XCTAssertEqual(t("Em7/G", 5), "Am7/C")
        XCTAssertEqual(t("Dsus4", 7), "Asus4")
        XCTAssertEqual(t("Emadd9", 2), "F#madd9")
        XCTAssertEqual(t("Fmaj7", 1), "F#maj7")
        XCTAssertEqual(t("Bm*", 2), "C#m*")
    }

    func testFlats() {
        XCTAssertEqual(t("C", 1, .flats), "Db")
        XCTAssertEqual(t("Bb", 2, .flats), "C")
        XCTAssertEqual(t("Bb", 0, .sharps), "A#")
        XCTAssertEqual(t("G#m", 0, .flats), "Abm")
    }

    func testRiffs() {
        XCTAssertEqual(t("DED-EDEDE", 2), "EF#E-F#EF#EF#")
        XCTAssertEqual(t("GCGC", 5), "CFCF")
    }

    func testFullCycleIsIdentity() {
        for chord in ["C#m", "D/F#", "Gsus2", "A7", "Bm7"] {
            XCTAssertEqual(t(chord, 12), chord)
            XCTAssertEqual(t(t(chord, 5), -5), chord)
        }
    }
}

final class KeyTests: XCTestCase {
    func testGuessFromFirstChord() {
        XCTAssertEqual(Key.guess(from: ["A", "E", "D"])?.name(), "A")
        XCTAssertEqual(Key.guess(from: ["Am", "G"])?.name(), "Am")
        XCTAssertEqual(Key.guess(from: ["Cmaj7"])?.name(), "C")
    }

    func testAccidentalsByKey() {
        XCTAssertEqual(Key(tonic: 5, isMinor: false).preferredAccidentals, .flats)   // F
        XCTAssertEqual(Key(tonic: 7, isMinor: false).preferredAccidentals, .sharps)  // G
        XCTAssertEqual(Key(tonic: 2, isMinor: true).preferredAccidentals, .flats)    // Dm
    }

    func testCapoSuggestion() {
        XCTAssertEqual(CapoAdvisor.suggestedCapo(forSounding: Key(tonic: 7, isMinor: false)), 0)  // G
        XCTAssertEqual(CapoAdvisor.suggestedCapo(forSounding: Key(tonic: 3, isMinor: false)), 1)  // Eb → D
        XCTAssertEqual(CapoAdvisor.suggestedCapo(forSounding: Key(tonic: 11, isMinor: true)), 2)  // Bm → Am
    }
}

final class PresentationTests: XCTestCase {
    let song = Song(id: "x", number: 1, title: "Prueba", album: "A", capo: 2, blocks: [
        SongBlock(lines: [
            .instrumental(label: "INTRO", chords: ["G", "D"], text: "INTRO: G D"),
            .lyric(text: "Hola mundo", chords: [PositionedChord(pos: 0, chord: "G"), PositionedChord(pos: 5, chord: "D/F#")]),
        ]),
    ])

    func testDefaultKeepsOriginal() {
        let p = SongPresentation(song: song, settings: ChordSettings())
        XCTAssertEqual(p.blocks, song.blocks)
        XCTAssertEqual(p.shapesKey?.name(), "G")
        XCTAssertEqual(p.soundingKey?.name(), "A")  // G con cejilla 2
    }

    func testTransposeMovesEveryChord() {
        let p = SongPresentation(song: song, settings: ChordSettings(transpose: 2))
        guard case let .instrumental(_, chords, text) = p.blocks[0].lines[0],
              case let .lyric(_, lyricChords) = p.blocks[0].lines[1] else { return XCTFail() }
        XCTAssertEqual(chords, ["A", "E"])
        XCTAssertEqual(text, "INTRO: A E")
        XCTAssertEqual(lyricChords.map(\.chord), ["A", "E/G#"])
        XCTAssertEqual(p.soundingKey?.name(), "B")
    }

    func testRemovingCapoKeepsSoundingKey() {
        let p = SongPresentation(song: song, settings: ChordSettings(capo: 0))
        XCTAssertEqual(p.shapesKey?.name(), "A")
        XCTAssertEqual(p.soundingKey?.name(), "A")
    }
}

final class LayoutTests: XCTestCase {
    func testPiecesSplitAtChords() {
        let words = ChordLayout.words(text: "Al estar en", chords: [
            PositionedChord(pos: 0, chord: "A"), PositionedChord(pos: 6, chord: "C#m"),
        ])
        XCTAssertEqual(words.count, 3)
        XCTAssertEqual(words[0].pieces, [ChordPiece(chord: "A", text: "Al ")])
        XCTAssertEqual(words[1].pieces, [ChordPiece(chord: nil, text: "est"), ChordPiece(chord: "C#m", text: "ar ")])
        XCTAssertEqual(words.flatMap(\.pieces).map(\.text).joined(), "Al estar en")
    }

    func testChordAtEnd() {
        let words = ChordLayout.words(text: "amor", chords: [PositionedChord(pos: 4, chord: "E")])
        XCTAssertEqual(words[0].pieces.last, ChordPiece(chord: "E", text: ""))
    }
}

final class SongbookTests: XCTestCase {
    static let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("data/songbook.json")

    func testLoadsWholeSongbook() throws {
        let lib = try SongLibrary(json: Data(contentsOf: Self.url))
        XCTAssertEqual(lib.songs.count, 126)
        XCTAssertEqual(lib.albums.first?.name, "HAKUNA")
        XCTAssertEqual(lib.albums.count, 13)
    }

    func testSearch() throws {
        let lib = try SongLibrary(json: Data(contentsOf: Self.url))
        XCTAssertEqual(lib.search("encIendeme").first?.number, 2)
        XCTAssertEqual(lib.search("15").map(\.number), [15])
        XCTAssertTrue(lib.search("hermosura de tu santidad").contains { $0.number == 1 })
    }

    func testEveryChordTransposesAndComesBack() throws {
        let lib = try SongLibrary(json: Data(contentsOf: Self.url))
        for song in lib.songs {
            for chord in song.allChords {
                for s in 1...11 {
                    let up = Transposer.transpose(chord, by: s, accidentals: .sharps)
                    XCTAssertEqual(Transposer.transpose(up, by: -s, accidentals: .sharps),
                                   Transposer.transpose(chord, by: 0, accidentals: .sharps), "\(song.id) \(chord)")
                }
            }
        }
    }
}

final class AnnotationCatalogTests: XCTestCase {
    func testIdsAreUnique() {
        XCTAssertEqual(Set(Instrument.all.map(\.id)).count, Instrument.all.count)
        XCTAssertEqual(Set(Sticker.all.map(\.id)).count, Sticker.all.count)
    }

    func testLookups() {
        XCTAssertEqual(Instrument.find("piano")?.emoji, "🎹")
        XCTAssertEqual(Sticker.find("x2")?.look, .text("x2"))
        XCTAssertNil(Instrument.find("ukelele"))
        XCTAssertEqual(Voice(rawValue: "together")?.title, "Juntos")
    }
}
