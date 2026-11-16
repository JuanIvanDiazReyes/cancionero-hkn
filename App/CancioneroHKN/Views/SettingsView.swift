import CancioneroCore
import SwiftData
import SwiftUI
import UIKit

/// Ajustes: apariencia, tema de color, lectura y copia de seguridad.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.ocean.rawValue
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system.rawValue
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("showChords") private var showChords = true
    @AppStorage("solfege") private var solfege = true
    @AppStorage("fingerDraws") private var fingerDraws = UIDevice.current.userInterfaceIdiom == .phone

    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingImport: Backup?
    @State private var message: String?
    /// El tema se aplica al cerrar Ajustes: cambiarlo redibuja toda la app.
    @State private var selectedTheme = AppTheme.current

    var body: some View {
        NavigationStack {
            Form {
                Section("Apariencia") {
                    Picker("Modo", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.name).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tema de color")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(AppTheme.allCases) { option in
                                    ThemeSwatch(theme: option, isSelected: option == selectedTheme) {
                                        selectedTheme = option
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tamaño de letra")
                            Spacer()
                            Text("\(Int((fontSize / 18 * 100).rounded())) %")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $fontSize, in: 11...44, step: 1)
                        ChordLyricLine(text: "Al estar en la presencia",
                                       chords: [PositionedChord(pos: 0, chord: "A"), PositionedChord(pos: 16, chord: "C#m")],
                                       fontSize: fontSize)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10))
                    }
                    Toggle("Mostrar acordes", isOn: $showChords)
                    Toggle("Notas de melodía en Do Re Mi", isOn: $solfege)
                    Toggle("Dibujar con el dedo", isOn: $fingerDraws)
                } header: {
                    Text("Lectura")
                } footer: {
                    Text("Con «Dibujar con el dedo» apagado, solo el Apple Pencil dibuja y el dedo desplaza la página.")
                }

                Section {
                    Button {
                        export()
                    } label: {
                        Label("Exportar copia de seguridad", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Importar copia de seguridad", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Copia de seguridad")
                } footer: {
                    Text("Guarda en un archivo tus anotaciones, dibujos, tonos, tempos, canciones editadas, favoritas y listas. Guárdalo en iCloud Drive o envíatelo para no perder nada si cambias de teléfono o reinstalas la app (sin cuenta de desarrollador, la app se reinstala cada 7 días).")
                }

                Section("Acerca de") {
                    LabeledContent("Canciones del cancionero", value: "\(LibraryStore.shared.library.songs.count)")
                    LabeledContent("Versión", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .tint(selectedTheme.accent)
            .onDisappear { theme = selectedTheme.rawValue }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json,
                          defaultFilename: BackupService.fileName()) { result in
                switch result {
                case .success: message = "Copia guardada."
                case let .failure(error): message = "No se pudo guardar: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                load(result)
            }
            .confirmationDialog("¿Reemplazar todo con esta copia?", isPresented: Binding(
                get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }
            ), titleVisibility: .visible) {
                Button("Reemplazar todo", role: .destructive) {
                    if let backup = pendingImport { restore(backup) }
                }
            } message: {
                Text("La copia tiene: \(pendingImport?.summary ?? ""). Lo que tienes ahora en la app se sustituye por la copia.")
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func export() {
        do {
            let backup = try BackupService.makeBackup(from: context)
            exportDocument = BackupDocument(data: try backup.encoded())
            showExporter = true
        } catch {
            message = "No se pudo preparar la copia: \(error.localizedDescription)"
        }
    }

    private func load(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try Backup.decode(Data(contentsOf: url))
        } catch let error as Backup.BackupError {
            message = error.localizedDescription
        } catch {
            message = "Ese archivo no es una copia del cancionero."
        }
    }

    private func restore(_ backup: Backup) {
        do {
            try BackupService.restore(backup, into: context)
            message = "Copia importada: \(backup.summary)."
        } catch {
            message = "No se pudo importar: \(error.localizedDescription)"
        }
        pendingImport = nil
    }
}

/// Muestra de un tema: color principal y de acordes.
private struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(theme.accent)
                    Circle()
                        .trim(from: 0.5, to: 1)
                        .fill(theme.chord)
                        .rotationEffect(.degrees(-45))
                }
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2.5).padding(-4))
                Text(theme.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tema \(theme.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
