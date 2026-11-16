import CancioneroCore
import Observation
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Estado compartido para importar un `.ctea`: desde el botón, desde Ajustes
/// o al tocar el archivo en Archivos, WhatsApp, AirDrop o Mail.
@Observable
final class ImportCenter {
    static let shared = ImportCenter()

    var showPicker = false
    var pending: CteaFile?
    /// La app no tiene canciones ni nada guardado: no hace falta preguntar cómo importar.
    var appIsEmpty = false
    var message: String?

    /// Abre el selector de archivos (después de cerrar la hoja que lo pidió, si la hay).
    func requestPicker(after delay: Double = 0) {
        if delay == 0 { showPicker = true; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.showPicker = true }
    }

    func load(_ url: URL, context: ModelContext) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let file = try CteaFile.read(Data(contentsOf: url))
            guard !file.isEmpty else {
                message = "El archivo no trae canciones."
                return
            }
            let edits = (try? context.fetchCount(FetchDescriptor<SongEditRecord>())) ?? 0
            appIsEmpty = LibraryStore.shared.isEmpty && edits == 0
            pending = file
        } catch let error as LocalizedError {
            message = error.errorDescription ?? "Ese archivo no es un cancionero de CTEA."
        } catch {
            message = "No se pudo abrir el archivo: \(error.localizedDescription)"
        }
    }

    func apply(_ mode: BackupService.ImportMode, context: ModelContext) {
        guard let file = pending else { return }
        pending = nil
        do {
            try BackupService.apply(file, mode: mode, into: context)
            message = "Listo. Se importó: \(file.summary)."
        } catch {
            message = "No se pudo importar: \(error.localizedDescription)"
        }
    }
}

/// Selector de archivos, confirmación (combinar o reemplazar) y avisos de la importación.
/// Va una sola vez en la raíz de la app.
struct CteaImportFlow: ViewModifier {
    @Environment(\.modelContext) private var context
    @Bindable private var center = ImportCenter.shared

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $center.showPicker, allowedContentTypes: [.cteaSongbook, .json]) { result in
                switch result {
                case let .success(url): center.load(url, context: context)
                case let .failure(error): center.message = "No se pudo abrir el archivo: \(error.localizedDescription)"
                }
            }
            .onOpenURL { url in center.load(url, context: context) }
            .confirmationDialog(dialogTitle, isPresented: Binding(
                get: { center.pending != nil }, set: { if !$0 { center.pending = nil } }
            ), titleVisibility: .visible) {
                if center.appIsEmpty {
                    Button("Importar") { center.apply(.combine, context: context) }
                } else {
                    Button("Combinar con lo que tengo") { center.apply(.combine, context: context) }
                    Button("Reemplazar todo", role: .destructive) { center.apply(.replace, context: context) }
                }
                Button("Cancelar", role: .cancel) { center.pending = nil }
            } message: {
                Text(dialogMessage)
            }
            .alert(center.message ?? "", isPresented: Binding(
                get: { center.message != nil }, set: { if !$0 { center.message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
    }

    private var dialogTitle: String {
        guard let file = center.pending else { return "" }
        return "Importar «\(file.name)»"
    }

    private var dialogMessage: String {
        guard let file = center.pending else { return "" }
        if center.appIsEmpty { return "Trae \(file.summary)." }
        var text = "Trae \(file.summary).\n\n"
        text += "Combinar: las canciones del archivo reemplazan a las que tienes con el mismo número y se agregan las nuevas. "
        text += "Tus anotaciones, dibujos y tonos se quedan.\n\n"
        text += "Reemplazar todo: borra lo que tienes en la app y deja exactamente lo del archivo."
        if file.songs.isEmpty { text += " (Este archivo no trae cancionero, así que tu cancionero se conserva.)" }
        return text
    }
}

extension View {
    func cteaImportFlow() -> some View { modifier(CteaImportFlow()) }
}

// MARK: Compartir

/// Archivo listo para la hoja de compartir.
struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// Hoja de compartir de iOS (WhatsApp, AirDrop, Mail, Guardar en Archivos…).
struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: Primera vez

/// Pantalla cuando la app todavía no tiene canciones.
struct WelcomeView: View {
    let onCreate: (_ title: String, _ blocks: [SongBlock]) -> Void

    @State private var creating = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 40)
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.12))
                            .frame(width: 132, height: 132)
                        Image(systemName: "music.note.list")
                            .font(.system(size: 54, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    VStack(spacing: 10) {
                        Text("Tu cancionero está vacío")
                            .font(.system(.title, design: .serif).weight(.bold))
                            .foregroundStyle(Theme.ink)
                        Text("Importa un archivo .ctea con canciones y acordes, o escribe tu primera canción.")
                            .font(.body)
                            .foregroundStyle(Theme.secondaryInk)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: 12) {
                        Button {
                            ImportCenter.shared.requestPicker()
                        } label: {
                            Label("Importar cancionero", systemImage: "square.and.arrow.down")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        Button {
                            creating = true
                        } label: {
                            Label("Crear canción", systemImage: "square.and.pencil")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: 360)
                    Text("También puedes tocar un archivo .ctea en Archivos, WhatsApp, Mail o AirDrop y se abre en CTEA.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $creating) {
            SongEditorSheet(heading: "Nueva canción", title: "", blocks: [], onSave: onCreate)
        }
    }
}
