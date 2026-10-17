import CancioneroCore
import SwiftUI
import UIKit

/// Colores y fondo de libreta.
enum Notebook {
    static let paper = Color(light: Color(red: 0.99, green: 0.97, blue: 0.91),
                             dark: Color(red: 0.13, green: 0.12, blue: 0.11))
    static let margin = Color(red: 0.90, green: 0.45, blue: 0.45).opacity(0.55)
    static let note = Color(red: 1.0, green: 0.93, blue: 0.55)

    static func color(_ voice: Voice) -> Color {
        switch voice {
        case .woman: return Color(red: 0.93, green: 0.36, blue: 0.62)    // rosa
        case .man: return Color(red: 0.22, green: 0.50, blue: 0.93)      // azul
        case .together: return Color(red: 0.55, green: 0.38, blue: 0.85) // morado
        }
    }
}

extension Color {
    /// Color que cambia con el modo claro/oscuro.
    init(light: Color, dark: Color) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}

/// Hoja de libreta: papel crema con la línea roja del margen.
struct NotebookPaper: View {
    var marginX: CGFloat = 14

    var body: some View {
        Notebook.paper
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Notebook.margin)
                    .frame(width: 1.5)
                    .padding(.leading, marginX)
            }
            .ignoresSafeArea()
    }
}

/// Muestra un icono musical (símbolo o texto).
struct StickerGlyph: View {
    let sticker: Sticker
    var size: CGFloat = 16

    var body: some View {
        switch sticker.look {
        case let .symbol(name):
            Image(systemName: name)
                .font(.system(size: size, weight: .semibold))
        case let .text(text):
            Text(text)
                .font(.system(size: size, weight: .heavy, design: .serif).italic())
        }
    }
}
