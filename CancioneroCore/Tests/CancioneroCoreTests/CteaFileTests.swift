import XCTest
@testable import CancioneroCore

final class CteaFileTests: XCTestCase {
    private func song(_ id: String, _ number: Int, _ title: String, album: String = "HAKUNA") -> Song {
        Song(id: id, number: number, title: title, album: album,
             blocks: [SongBlock(lines: [.lyric(text: title.lowercased(), chords: [PositionedChord(pos: 0, chord: "G")])])])
    }

    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    func testRoundTrip() throws {
        let file = CteaFile(name: "Prueba", exportedAt: date, songs: [song("001-a", 1, "A")],
                            notebook: Backup(exportedAt: date, favorites: ["001-a"]))
        let read = try CteaFile.read(file.encoded())
        XCTAssertEqual(read, file)
        XCTAssertTrue(read.hasNotebookData)
    }

    func testReadsMinimalFileWithoutNotebook() throws {
        let json = """
        {"format":"ctea","version":1,"name":"HKN","songs":[{"id":"001-a","number":1,"title":"A","album":"HAKUNA",
        "capo":null,"chordDefinitions":{},"blocks":[{"label":null,"lines":[{"type":"directive","text":"x"}]}]}]}
        """
        let file = try CteaFile.read(Data(json.utf8))
        XCTAssertEqual(file.name, "HKN")
        XCTAssertEqual(file.songs.count, 1)
        XCTAssertTrue(file.notebook.isEmpty)
        XCTAssertFalse(file.hasNotebookData)
    }

    func testReadsLegacyBackupAndSongbook() throws {
        let backup = Backup(exportedAt: date, favorites: ["x"])
        let fromBackup = try CteaFile.read(backup.encoded())
        XCTAssertTrue(fromBackup.songs.isEmpty)
        XCTAssertEqual(fromBackup.notebook.favorites, ["x"])

        let songbook = try JSONEncoder().encode(Songbook(songs: [song("001-a", 1, "A")]))
        XCTAssertEqual(try CteaFile.read(songbook).songs.count, 1)
    }

    func testRejectsNewerVersionAndGarbage() {
        XCTAssertThrowsError(try CteaFile.read(Data(#"{"format":"ctea","version":99}"#.utf8))) {
            XCTAssertEqual($0 as? CteaFile.FileError, .newerVersion(99))
        }
        XCTAssertThrowsError(try CteaFile.read(Data("hola".utf8)))
        XCTAssertThrowsError(try CteaFile.read(Data(#"{"foo":1}"#.utf8)))
    }

    func testReplaceKeepsBaseWhenFileHasNone() {
        let current = CteaFile(name: "Mío", songs: [song("001-a", 1, "A")], notebook: Backup(favorites: ["001-a"]))
        let legacy = CteaFile(name: "Copia", songs: [], notebook: Backup(favorites: ["002-b"]))
        let result = legacy.replacing(current)
        XCTAssertEqual(result.songs.map(\.id), ["001-a"])
        XCTAssertEqual(result.notebook.favorites, ["002-b"])
    }

    func testCombineReplacesSameIDAndAddsNew() {
        var updatedA = song("001-a", 1, "A")
        updatedA.title = "A nueva"
        let current = CteaFile(name: "Mío", songs: [song("001-a", 1, "A"), song("002-b", 2, "B")])
        let incoming = CteaFile(name: "Otro", songs: [updatedA, song("003-c", 3, "C")])
        let result = incoming.combined(into: current)
        XCTAssertEqual(result.songs.map(\.id), ["001-a", "002-b", "003-c"])
        XCTAssertEqual(result.songs.first?.title, "A nueva")
        XCTAssertEqual(result.name, "Mío")
    }

    func testCombineEditsAndCustomNumbering() {
        let mine = song("mi-aaaa", 1001, "Mía", album: Song.customAlbum)
        let theirs = song("mi-bbbb", 1001, "Suya", album: Song.customAlbum)
        var myEdit = song("001-a", 1, "A")
        myEdit.title = "A (mía)"
        var theirEdit = song("001-a", 1, "A")
        theirEdit.title = "A (suya)"
        let current = CteaFile(name: "Mío", songs: [song("001-a", 1, "A")], notebook: Backup(
            songs: [.init(song: mine, isCustom: true), .init(song: myEdit, isCustom: false)]))
        let incoming = CteaFile(name: "Otro", songs: [], notebook: Backup(
            songs: [.init(song: theirs, isCustom: true), .init(song: theirEdit, isCustom: false)]))

        let result = incoming.combined(into: current)
        let byID = Dictionary(uniqueKeysWithValues: result.notebook.songs.map { ($0.song.id, $0) })
        XCTAssertEqual(byID["001-a"]?.song.title, "A (suya)")
        XCTAssertEqual(byID["mi-aaaa"]?.song.number, 1001)
        XCTAssertEqual(byID["mi-bbbb"]?.song.number, 1002)
    }

    func testCombineKeepsMyNotebookAndAddsTheirs() {
        let a1 = Backup.Annotation(songID: "001-a", block: 0, line: 0, kind: "dynamic", value: "f", detail: nil, createdAt: date)
        let a2 = Backup.Annotation(songID: "001-a", block: 0, line: 0, kind: "dynamic", value: "p", detail: nil, createdAt: date)
        let a3 = Backup.Annotation(songID: "002-b", block: 0, line: 0, kind: "dynamic", value: "mf", detail: nil, createdAt: date)
        let list = Backup.SetList(id: UUID(), name: "Misa", songIDs: ["001-a"], createdAt: date)
        let current = CteaFile(name: "Mío", songs: [], notebook: Backup(annotations: [a1], favorites: ["001-a"]))
        let incoming = CteaFile(name: "Otro", songs: [], notebook: Backup(
            annotations: [a2, a3], favorites: ["001-a", "002-b"], setLists: [list],
            links: [.init(songID: "001-a", url: "https://example.com", title: "Video", createdAt: date)]))

        let result = incoming.combined(into: current)
        XCTAssertEqual(result.notebook.annotations.map(\.value), ["f", "mf"])
        XCTAssertEqual(result.notebook.favorites, ["001-a", "002-b"])
        XCTAssertEqual(result.notebook.setLists, [list])
        XCTAssertEqual(result.notebook.links.count, 1)

        // Importar dos veces no duplica.
        let twice = incoming.combined(into: result)
        XCTAssertEqual(twice.notebook.favorites, ["001-a", "002-b"])
        XCTAssertEqual(twice.notebook.setLists.count, 1)
        XCTAssertEqual(twice.notebook.links.count, 1)
    }
}
