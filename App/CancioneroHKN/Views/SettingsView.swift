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

    @State private var choosingExport = false
    @State private var sharing: SharedFile?
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
                        choosingExport = true
                    } label: {
                        Label("Exportar cancionero", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        dismiss()
                        ImportCenter.shared.requestPicker(after: 0.6)
                    } label: {
                        Label("Importar cancionero", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Cancionero y copia de seguridad")
                } footer: {
                    Text("Exporta un archivo .ctea para compartir tus canciones con tus cambios, o para respaldar todo (anotaciones, dibujos, tonos, favoritas y listas). Guárdalo en iCloud Drive para no perder nada si cambias de dispositivo o reinstalas la app.")
                }

                Section("Acerca de") {
                    LabeledContent("Cancionero", value: LibraryStore.shared.isEmpty ? "Ninguno" : LibraryStore.shared.name)
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
            .confirmationDialog("¿Qué quieres exportar?", isPresented: $choosingExport, titleVisibility: .visible) {
                Button("Solo canciones (para compartir)") { export(.songs) }
                Button("Todo (respaldo personal)") { export(.everything) }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Solo canciones: letras y acordes con tus ediciones y tus canciones propias.\nTodo: además tus anotaciones, dibujos, tonos, tempos, favoritas, listas y links.")
            }
            .sheet(item: $sharing) { file in
                ActivityView(url: file.url)
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func export(_ content: BackupService.ExportContent) {
        do {
            let file = try BackupService.makeFile(content, from: context)
            guard !file.isEmpty else {
                message = "Todavía no hay canciones para exportar."
                return
            }
            sharing = SharedFile(url: try BackupService.temporaryURL(for: file, content: content))
        } catch {
            message = "No se pudo preparar el archivo: \(error.localizedDescription)"
        }
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
