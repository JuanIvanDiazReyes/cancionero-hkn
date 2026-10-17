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

final class SongTextTests: XCTestCase {
    func testWholeSongbookRoundTrips() throws {
        let lib = try SongLibrary(json: Data(contentsOf: SongbookTests.url))
        for song in lib.songs {
            XCTAssertEqual(SongText.blocks(from: SongText.text(for: song.blocks)), song.blocks, song.id)
        }
    }

    func testParsesInlineChords() {
        let blocks = SongText.blocks(from: "| INTRO: A Fm# (x2)\n\n[A]Al estar en[E]\n> (CORO)\n\\| no es acorde\n[Intro] sin acorde")
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].label, "INTRO")
        XCTAssertEqual(blocks[0].lines[0], .instrumental(label: "INTRO", chords: ["A", "F#m"], text: "INTRO: A Fm# (x2)"))
        XCTAssertEqual(blocks[1].lines[0], .lyric(text: "Al estar en", chords: [
            PositionedChord(pos: 0, chord: "A"), PositionedChord(pos: 11, chord: "E"),
        ]))
        XCTAssertEqual(blocks[1].lines[1], .directive(text: "(CORO)"))
        XCTAssertEqual(blocks[1].lines[2], .lyric(text: "| no es acorde", chords: []))
        XCTAssertEqual(blocks[1].lines[3], .lyric(text: "[Intro] sin acorde", chords: []))
    }

    func testChordTokens() {
        for chord in ["A", "F#m", "D/F#", "Cadd9", "Bm*", "DED-EDEDE", "GSus", "Em7/G"] {
            XCTAssertTrue(ChordToken.isChord(chord), chord)
        }
        for word in ["Dios", "Ama", "(x2)", "-", "Al"] {
            XCTAssertFalse(ChordToken.isChord(word), word)
        }
    }
}

final class SongEditingTests: XCTestCase {
    let line = SongLine.lyric(text: "Te adoro a Ti", chords: [
        PositionedChord(pos: 0, chord: "D"), PositionedChord(pos: 3, chord: "Bm"),
    ])

    func testChangeMoveRemoveAdd() {
        XCTAssertEqual(line.replacingChord(at: 1, with: "G"), .lyric(text: "Te adoro a Ti", chords: [
            PositionedChord(pos: 0, chord: "D"), PositionedChord(pos: 3, chord: "G"),
        ]))
        XCTAssertEqual(line.movingChord(at: 0, by: -3), line)
        XCTAssertEqual(line.movingChordByWord(at: 1, forward: true),
                       .lyric(text: "Te adoro a Ti", chords: [
                           PositionedChord(pos: 0, chord: "D"), PositionedChord(pos: 9, chord: "Bm"),
                       ]))
        XCTAssertEqual(line.removingChord(at: 0).chordCount, 1)
        XCTAssertEqual(line.addingChord("E", at: 11), .lyric(text: "Te adoro a Ti", chords: [
            PositionedChord(pos: 0, chord: "D"), PositionedChord(pos: 3, chord: "Bm"), PositionedChord(pos: 11, chord: "E"),
        ]))
        XCTAssertEqual(line.replacingChord(at: 0, with: " "), line.removingChord(at: 0))
    }

    func testEditingLyricKeepsChordsOnTheirWords() {
        let edited = line.replacingLyric(with: "Yo te adoro a Ti")
        XCTAssertEqual(edited, .lyric(text: "Yo te adoro a Ti", chords: [
            PositionedChord(pos: 3, chord: "D"), PositionedChord(pos: 6, chord: "Bm"),
        ]))
    }

    func testInstrumentalEdits() {
        let intro = SongLine.instrumental(label: "INTRO", chords: ["G", "D"], text: "INTRO: G D")
        XCTAssertEqual(intro.replacingChord(at: 1, with: "C"),
                       .instrumental(label: "INTRO", chords: ["G", "C"], text: "INTRO: G C"))
        XCTAssertEqual(intro.addingChord("Em", at: 0).chordCount, 3)
    }

    func testDuplicate() {
        let song = Song(id: "a", number: 3, title: "Hola", album: "HAKUNA", blocks: [SongBlock(lines: [line])])
        let copy = song.duplicated(id: "b", number: 1001)
        XCTAssertEqual(copy.title, "Hola (mi versión)")
        XCTAssertEqual(copy.album, Song.customAlbum)
        XCTAssertEqual(copy.blocks, song.blocks)
        let changed = copy.replacingLine(at: LineAnchor(block: 0, line: 0), with: .directive(text: "x"))
        XCTAssertEqual(changed.line(at: LineAnchor(block: 0, line: 0)), .directive(text: "x"))
        XCTAssertNil(changed.line(at: LineAnchor(block: 1, line: 0)))
    }
}

final class TempoTests: XCTestCase {
    func testTapTempo() {
        var tap = TapTempo()
        XCTAssertNil(tap.tap(at: 10))
        XCTAssertEqual(tap.tap(at: 10.5), 120)
        XCTAssertEqual(tap.tap(at: 11.0), 120)
        XCTAssertNil(tap.tap(at: 20))  // pausa larga: empieza de nuevo
        XCTAssertEqual(tap.tap(at: 21), 60)
    }

    func testAccents() {
        let sixEight = TimeSignature(beats: 6, unit: 8)
        XCTAssertEqual((0..<6).filter(sixEight.isAccent), [0, 3])
        XCTAssertEqual((0..<4).filter(TimeSignature(beats: 4, unit: 4).isAccent), [0])
        XCTAssertEqual(TempoRange.clamp(500), 260)
        XCTAssertEqual(TempoRange.marking(for: 72), "Adagio")
    }
}

final class MelodyTests: XCTestCase {
    func testParse() {
        let items = Melody.parse("Do Re#:8 Mib5:2. | - C4 bb3:16")
        XCTAssertEqual(items, [
            .note(MelodyNote(pitch: 60)),
            .note(MelodyNote(pitch: 63, value: .eighth, accidental: 1)),
            .note(MelodyNote(pitch: 75, value: .half, dotted: true, accidental: -1)),
            .bar,
            .note(MelodyNote(pitch: nil)),
            .note(MelodyNote(pitch: 60)),
            .note(MelodyNote(pitch: 58, value: .sixteenth, accidental: -1)),
        ])
        XCTAssertTrue(Melody.isValid("Sol La Si"))
        XCTAssertFalse(Melody.isValid("Sol hola"))
        XCTAssertFalse(Melody.isValid("Do:3"))
    }

    func testStaffAndNames() {
        func step(_ s: String) -> Int? {
            guard case let .note(n) = Melody.item(s) else { return nil }
            return n.staffStep
        }
        XCTAssertEqual(step("Mi"), 0)   // primera línea
        XCTAssertEqual(step("Do"), -2)  // línea adicional abajo
        XCTAssertEqual(step("Fa5"), 8)  // quinta línea
        XCTAssertEqual(step("Fa#5"), 8)
        XCTAssertEqual(Melody.name(of: MelodyNote(pitch: 61, accidental: 1)), "Do#4")
        XCTAssertEqual(Melody.name(of: MelodyNote(pitch: 70, accidental: -1), solfege: false), "Bb4")
    }
}
