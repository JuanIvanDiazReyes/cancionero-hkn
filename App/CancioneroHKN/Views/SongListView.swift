import CancioneroCore
import SwiftData
import SwiftUI

/// Lista de canciones por álbum, con búsqueda por número, título o letra.
/// En iPad se ve como barra lateral + canción; en iPhone como navegación normal.
struct SongListView: View {
    let library: SongLibrary

    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var selectedID: Song.ID?
    @State private var creating = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                if query.isEmpty {
                    ForEach(library.albums) { album in
                        Section {
                            ForEach(album.songs) { SongRow(song: $0) }
                        } header: {
                            HStack {
                                Text(album.name)
                                Spacer()
                                Text("\(album.songs.count)")
                                    .monospacedDigit()
                            }
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.secondaryInk)
                        }
                    }
                } else {
                    let results = library.search(query)
                    if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                    ForEach(results) { SongRow(song: $0) }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Cancionero HKN")
            .searchable(text: $query, prompt: "Título, número o letra")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { creating = true } label: {
                        Label("Nueva canción", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $creating) {
                SongEditorSheet(heading: "Nueva canción", title: "", blocks: [], onSave: create)
            }
        } detail: {
            if let id = selectedID, let song = library.song(id: id) {
                SongDetailView(song: song, onOpen: { selectedID = $0 }, onClose: { selectedID = nil })
                    .id(song.id)
            } else {
                ContentUnavailableView("Elige una canción", systemImage: "music.note.list",
                                       description: Text("\(library.songs.count) canciones con acordes y tus anotaciones."))
                    .background(Theme.paper)
            }
        }
    }

    /// Guarda una canción escrita por el usuario en «Mis canciones» y la abre.
    private func create(title: String, blocks: [SongBlock]) {
        let customs = ((try? context.fetch(FetchDescriptor<SongEditRecord>())) ?? []).filter(\.isCustom)
        let number = max(SongEditRecord.firstCustomNumber - 1, customs.compactMap { $0.song?.number }.max() ?? 0) + 1
        let song = Song(id: "mi-" + UUID().uuidString.prefix(8).lowercased(), number: number, title: title,
                        album: Song.customAlbum, blocks: blocks)
        context.insert(SongEditRecord(song: song, isCustom: true))
        try? context.save()
        selectedID = song.id
    }
}

private struct SongRow: View {
    let song: Song

    private var firstLine: String {
        for block in song.blocks {
            for line in block.lines {
                if case let .lyric(text, _) = line { return text }
            }
        }
        return ""
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(song.number)")
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(song.displayTitle)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(firstLine)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .tag(song.id)
    }
}
