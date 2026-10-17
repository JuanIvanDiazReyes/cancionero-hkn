import CancioneroCore
import SwiftData
import SwiftUI

/// Qué canciones muestra la lista.
enum LibraryFilter: Hashable {
    case all, favorites, setList(UUID)
}

/// Lista de canciones por álbum, favoritas o listas propias, con búsqueda por número, título o letra.
/// En iPad se ve como barra lateral + canción; en iPhone como navegación normal.
struct SongListView: View {
    let library: SongLibrary

    @Environment(\.modelContext) private var context
    @Query(sort: \FavoriteRecord.createdAt) private var favorites: [FavoriteRecord]
    @Query(sort: \SetListRecord.createdAt) private var setLists: [SetListRecord]
    @State private var query = ""
    @State private var selectedID: Song.ID?
    @State private var filter: LibraryFilter = .all
    @State private var creating = false
    @State private var showSettings = false
    @State private var namingList: ListNaming?
    @State private var listName = ""
    @State private var addingSongsTo: SetListRecord?
    @State private var confirmDeleteList = false

    private var favoriteIDs: Set<String> { Set(favorites.map(\.songID)) }

    private var currentList: SetListRecord? {
        guard case let .setList(id) = filter else { return nil }
        return setLists.first { $0.id == id }
    }

    /// Canciones visibles en orden (para la lista y para anterior/siguiente).
    private var visibleSongs: [Song] {
        if !query.isEmpty { return library.search(query) }
        switch filter {
        case .all: return library.songs
        case .favorites: return favorites.compactMap { library.song(id: $0.songID) }
        case .setList: return currentList?.songIDs.compactMap { library.song(id: $0) } ?? []
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                if !query.isEmpty {
                    let results = library.search(query)
                    if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                    ForEach(results) { row($0) }
                } else {
                    switch filter {
                    case .all: albumSections
                    case .favorites: favoritesSection
                    case .setList: setListSection
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .safeAreaInset(edge: .top, spacing: 0) {
                if query.isEmpty { filterBar }
            }
            .navigationTitle("Cancionero HKN")
            .searchable(text: $query, prompt: "Título, número o letra")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { creating = true } label: {
                        Label("Nueva canción", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $creating) {
                SongEditorSheet(heading: "Nueva canción", title: "", blocks: [], onSave: create)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $addingSongsTo) { list in
                AddSongsSheet(library: library, listName: list.name, existing: Set(list.songIDs)) { ids in
                    list.songIDs += ids
                    try? context.save()
                }
            }
            .alert(namingList?.title ?? "", isPresented: Binding(
                get: { namingList != nil }, set: { if !$0 { namingList = nil } }
            )) {
                TextField("Nombre (p. ej. Misa del domingo)", text: $listName)
                Button("Cancelar", role: .cancel) {}
                Button("Guardar", action: saveListName)
            }
            .confirmationDialog("¿Eliminar la lista «\(currentList?.name ?? "")»?", isPresented: $confirmDeleteList,
                                titleVisibility: .visible) {
                Button("Eliminar lista", role: .destructive, action: deleteCurrentList)
            } message: {
                Text("Las canciones no se borran, solo la lista.")
            }
        } detail: {
            if let id = selectedID, let song = library.song(id: id) {
                SongDetailView(song: song, queue: queue(for: song), onOpen: { selectedID = $0 },
                               onClose: { selectedID = nil })
                    .id(song.id)
            } else {
                ContentUnavailableView("Elige una canción", systemImage: "music.note.list",
                                       description: Text("\(library.songs.count) canciones con acordes y tus anotaciones."))
                    .background(Theme.paper)
            }
        }
    }

    // MARK: Secciones

    @ViewBuilder
    private var albumSections: some View {
        ForEach(library.albums) { album in
            Section {
                ForEach(album.songs) { row($0) }
            } header: {
                sectionHeader(album.name, count: album.songs.count)
            }
        }
    }

    @ViewBuilder
    private var favoritesSection: some View {
        let songs = visibleSongs
        if songs.isEmpty {
            ContentUnavailableView("Sin favoritas", systemImage: "star",
                                   description: Text("Desliza una canción a la derecha o toca la estrella dentro de ella."))
                .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(songs) { row($0) }
                    .onMove { source, destination in
                        let ids = favorites.map(\.songID).moving(from: source, to: destination)
                        // El orden de favoritas es el de su fecha; se reescribe en el nuevo orden.
                        let base = Date.now
                        for (i, id) in ids.enumerated() {
                            favorites.first { $0.songID == id }?.createdAt = base.addingTimeInterval(Double(i))
                        }
                        try? context.save()
                    }
            } header: {
                sectionHeader("Favoritas", count: songs.count)
            }
        }
    }

    @ViewBuilder
    private var setListSection: some View {
        if let list = currentList {
            let songs = visibleSongs
            Section {
                ForEach(Array(songs.enumerated()), id: \.offset) { index, song in
                    row(song, position: index + 1)
                }
                .onMove { source, destination in
                    list.songIDs = list.songIDs.moving(from: source, to: destination)
                    try? context.save()
                }
                .onDelete { offsets in
                    list.songIDs.remove(atOffsets: offsets)
                    try? context.save()
                }
                Button { addingSongsTo = list } label: {
                    Label("Añadir canciones", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                }
            } header: {
                HStack {
                    sectionHeader(list.name, count: songs.count)
                    Menu {
                        Button { startNaming(.rename(list.id)) } label: {
                            Label("Cambiar nombre", systemImage: "pencil")
                        }
                        Button(role: .destructive) { confirmDeleteList = true } label: {
                            Label("Eliminar lista", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                    }
                    .textCase(nil)
                }
            } footer: {
                if !songs.isEmpty {
                    Text("Mantén pulsada y arrastra para cambiar el orden; desliza a la izquierda para quitar.")
                }
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)").monospacedDigit()
        }
        .font(.caption.weight(.bold))
        .tracking(0.8)
        .foregroundStyle(Theme.secondaryInk)
    }

    // MARK: Filtros

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Todas", systemImage: "music.note.list", isSelected: filter == .all) {
                    filter = .all
                }
                FilterChip(title: "Favoritas", systemImage: "star.fill", isSelected: filter == .favorites,
                           count: favorites.count) {
                    filter = .favorites
                }
                ForEach(setLists) { list in
                    FilterChip(title: list.name, systemImage: "list.number", isSelected: filter == .setList(list.id),
                               count: list.songIDs.count) {
                        filter = .setList(list.id)
                    }
                }
                Button { startNaming(.new(songID: nil)) } label: {
                    Label("Nueva lista", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .overlay(Capsule().strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        .foregroundStyle(Theme.secondaryInk)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.paper)
    }

    // MARK: Filas

    private func row(_ song: Song, position: Int? = nil) -> some View {
        let isFavorite = favoriteIDs.contains(song.id)
        return SongRow(song: song, isFavorite: isFavorite, position: position)
            .swipeActions(edge: .leading) {
                Button { toggleFavorite(song.id) } label: {
                    Label(isFavorite ? "Quitar de favoritas" : "Favorita", systemImage: isFavorite ? "star.slash" : "star.fill")
                }
                .tint(.yellow)
            }
            .contextMenu {
                Button { toggleFavorite(song.id) } label: {
                    Label(isFavorite ? "Quitar de favoritas" : "Añadir a favoritas",
                          systemImage: isFavorite ? "star.slash" : "star")
                }
                Menu {
                    ForEach(setLists) { list in
                        Button(list.name) { add(song.id, to: list) }
                    }
                    Button { startNaming(.new(songID: song.id)) } label: {
                        Label("Nueva lista…", systemImage: "plus")
                    }
                } label: {
                    Label("Añadir a una lista", systemImage: "text.badge.plus")
                }
            }
    }

    // MARK: Acciones

    private func queue(for song: Song) -> SongQueue? {
        guard query.isEmpty, filter != .all else { return nil }
        let songs = visibleSongs
        guard let index = songs.firstIndex(where: { $0.id == song.id }) else { return nil }
        let name: String
        switch filter {
        case .favorites: name = "Favoritas"
        default: name = currentList?.name ?? "Lista"
        }
        return SongQueue(name: name, index: index, count: songs.count,
                         previous: index > 0 ? songs[index - 1] : nil,
                         next: index + 1 < songs.count ? songs[index + 1] : nil)
    }

    private func toggleFavorite(_ id: String) {
        if let existing = favorites.first(where: { $0.songID == id }) {
            context.delete(existing)
        } else {
            context.insert(FavoriteRecord(songID: id))
        }
        try? context.save()
    }

    private func add(_ songID: String, to list: SetListRecord) {
        list.songIDs.append(songID)
        try? context.save()
    }

    private func startNaming(_ naming: ListNaming) {
        if case let .rename(id) = naming {
            listName = setLists.first { $0.id == id }?.name ?? ""
        } else {
            listName = ""
        }
        namingList = naming
    }

    private func saveListName() {
        let name = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let naming = namingList else { return }
        switch naming {
        case let .new(songID):
            let list = SetListRecord(name: name, songIDs: songID.map { [$0] } ?? [])
            context.insert(list)
            filter = .setList(list.id)
            if songID == nil {
                // Espera a que se cierre el aviso del nombre antes de abrir la hoja.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { addingSongsTo = list }
            }
        case let .rename(id):
            setLists.first { $0.id == id }?.name = name
        }
        try? context.save()
        namingList = nil
    }

    private func deleteCurrentList() {
        if let list = currentList { context.delete(list) }
        try? context.save()
        filter = .all
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

/// Crear una lista nueva (opcionalmente con una canción) o cambiarle el nombre.
private enum ListNaming {
    case new(songID: String?)
    case rename(UUID)

    var title: String {
        switch self {
        case .new: return "Nueva lista"
        case .rename: return "Cambiar nombre"
        }
    }
}

/// Dónde está la canción dentro de la lista que se está recorriendo.
struct SongQueue {
    let name: String
    let index: Int
    let count: Int
    let previous: Song?
    let next: Song?
}

private struct FilterChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    var count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).imageScale(.small)
                Text(title).lineLimit(1)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.25) : Theme.accent.opacity(0.12), in: Capsule())
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Theme.accent : Theme.card, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? .clear : Theme.hairline))
            .foregroundStyle(isSelected ? Color.white : Theme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SongRow: View {
    let song: Song
    var isFavorite = false
    var position: Int?

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
            Text(position.map { "\($0)." } ?? "\(song.number)")
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(position == nil ? Theme.accent : Color.white)
                .frame(width: 34, height: 34)
                .background(position == nil ? Theme.accent.opacity(0.10) : Theme.accent,
                            in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(song.displayTitle)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(position == nil ? firstLine : "\(song.number) · \(firstLine)")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorita")
            }
        }
        .padding(.vertical, 2)
        .tag(song.id)
    }
}

/// Elegir varias canciones para añadir a una lista.
private struct AddSongsSheet: View {
    let library: SongLibrary
    let listName: String
    let existing: Set<String>
    let onAdd: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var picked: [String] = []

    var body: some View {
        NavigationStack {
            List(library.search(query)) { song in
                Button {
                    if let i = picked.firstIndex(of: song.id) { picked.remove(at: i) } else { picked.append(song.id) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: picked.contains(song.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(picked.contains(song.id) ? Theme.accent : Theme.hairline)
                        Text("\(song.number)")
                            .font(.footnote.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.accent)
                            .frame(width: 34, alignment: .leading)
                        Text(song.displayTitle)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if existing.contains(song.id) {
                            Text("Ya está")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Título, número o letra")
            .navigationTitle("Añadir a «\(listName)»")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(picked.isEmpty ? "Añadir" : "Añadir \(picked.count)") {
                        onAdd(picked)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(picked.isEmpty)
                }
            }
        }
    }
}
