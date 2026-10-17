import CancioneroCore
import SwiftUI

/// Lista de canciones por álbum, con búsqueda por número, título o letra.
/// En iPad se ve como barra lateral + canción; en iPhone como navegación normal.
struct SongListView: View {
    let library: SongLibrary

    @State private var query = ""
    @State private var selectedID: Song.ID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                if query.isEmpty {
                    ForEach(library.albums) { album in
                        Section(album.name) {
                            ForEach(album.songs) { SongRow(song: $0) }
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
            .navigationTitle("Cancionero HKN")
            .searchable(text: $query, prompt: "Título, número o letra")
        } detail: {
            if let id = selectedID, let song = library.song(id: id) {
                SongDetailView(song: song)
                    .id(song.id)
            } else {
                ContentUnavailableView("Elige una canción", systemImage: "music.note.list")
            }
        }
    }
}

private struct SongRow: View {
    let song: Song

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(song.number)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 28, alignment: .trailing)
            Text(song.title.capitalized(with: Locale(identifier: "es")))
        }
        .tag(song.id)
    }
}
