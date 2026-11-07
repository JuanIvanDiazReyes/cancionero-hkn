import CancioneroCore
import SwiftUI
import UIKit

extension LinkKind {
    var systemImage: String {
        switch self {
        case .spotify: return "waveform.circle.fill"
        case .youtube: return "play.rectangle.fill"
        case .drive: return "folder.fill"
        case .appleMusic: return "music.note"
        case .other: return "link"
        }
    }

    var tint: Color {
        switch self {
        case .spotify: return Color(hex: 0x1DB954)
        case .youtube: return Color(hex: 0xE62117)
        case .drive: return Color(hex: 0x1A73E8)
        case .appleMusic: return Color(hex: 0xFA2D48)
        case .other: return Theme.accent
        }
    }
}

/// Links de una canción: pegar, ver y abrir en Spotify, YouTube o Drive.
struct LinksSheet: View {
    let songTitle: String
    let links: [SongLinkRecord]
    let onAdd: (URL, String) -> Void
    let onDelete: (SongLinkRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var text = ""
    @State private var title = ""
    @FocusState private var focused: Bool

    private var parsed: URL? { SongLinks.url(from: text) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    addCard
                    if !links.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("GUARDADOS")
                                .font(.caption.weight(.bold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            VStack(spacing: 0) {
                                ForEach(links) { link in
                                    row(link)
                                    if link.id != links.last?.id { Divider().padding(.leading, 56) }
                                }
                            }
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.hairline))
                            Text("Mantén pulsado un link para copiarlo o quitarlo.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Links")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: parsed.map(LinkKind.detect)?.systemImage ?? "link")
                    .font(.title3)
                    .foregroundStyle(parsed.map(LinkKind.detect)?.tint ?? Theme.secondaryInk)
                    .frame(width: 28)
                TextField("Pega un link de Spotify, YouTube o Drive", text: $text, axis: .vertical)
                    .lineLimit(1...3)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first { text = first }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.capsule)
                .tint(Theme.accent)
            }
            TextField("Nombre (opcional), p. ej. «Versión en vivo»", text: $title)
                .padding(.leading, 38)
                .font(.subheadline)
            if !text.isEmpty && parsed == nil {
                Text("Eso no parece un link.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.leading, 38)
            }
            Button(action: add) {
                Label("Añadir link", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background((parsed == nil ? Theme.secondaryInk : Theme.accent).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(parsed == nil ? Theme.secondaryInk : Theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(parsed == nil)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline))
    }

    private func row(_ link: SongLinkRecord) -> some View {
        Button {
            if let url = link.link { openURL(url) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: link.kind.systemImage)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(link.kind.tint, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(link.link?.host ?? link.url)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondaryInk)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                UIPasteboard.general.string = link.url
            } label: {
                Label("Copiar link", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) { onDelete(link) } label: {
                Label("Quitar", systemImage: "trash")
            }
        }
    }

    private func add() {
        guard let url = parsed else { return }
        let name = title.trimmingCharacters(in: .whitespaces)
        onAdd(url, name.isEmpty ? LinkKind.detect(url).defaultTitle : name)
        text = ""
        title = ""
        focused = false
    }
}
