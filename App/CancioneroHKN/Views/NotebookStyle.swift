import CancioneroCore
import SwiftUI
import UIKit

/// Sistema visual de la app: colores, tipografías y piezas reutilizables.
enum Theme {
    /// Color principal de la app (botones, selección).
    static let accent = Color(light: Color(hex: 0x1F4E79), dark: Color(hex: 0x7FB2E5))
    /// Acordes: verde azulado intenso, distinto de los colores de voz.
    static let chord = Color(light: Color(hex: 0x0B7A75), dark: Color(hex: 0x4FD1C5))
    /// Texto de la letra.
    static let ink = Color(light: Color(hex: 0x1D1B18), dark: Color(hex: 0xF2EEE6))
    static let secondaryInk = Color(light: Color(hex: 0x6B6459), dark: Color(hex: 0xA59E92))
    /// Fondo tipo papel.
    static let paper = Color(light: Color(hex: 0xFBF8F1), dark: Color(hex: 0x1A1917))
    static let card = Color(light: .white, dark: Color(hex: 0x24221F))
    static let hairline = Color(light: Color(hex: 0xE6DFD2), dark: Color(hex: 0x34312C))
    static let note = Color(light: Color(hex: 0xFFE98A), dark: Color(hex: 0x5A4E1C))
    static let noteInk = Color(light: Color(hex: 0x4A3F10), dark: Color(hex: 0xFFF3C4))

    static func voice(_ voice: Voice) -> Color {
        switch voice {
        case .woman: return Color(hex: 0xE0457B)     // rosa
        case .man: return Color(hex: 0x3A7BD5)       // azul
        case .together: return Color(hex: 0x8E5BD6)  // morado
        }
    }

    static func lyricFont(_ size: Double) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func chordFont(_ size: Double) -> Font { .system(size: size * 0.82, weight: .bold, design: .rounded) }
    static func labelFont(_ size: Double) -> Font { .system(size: size * 0.62, weight: .bold, design: .rounded) }
}

/// Nombres anteriores, para el código que aún los usa.
enum Notebook {
    static var paper: Color { Theme.paper }
    static var note: Color { Theme.note }
    static func color(_ voice: Voice) -> Color { Theme.voice(voice) }
}

extension Color {
    /// Color que cambia con el modo claro/oscuro.
    init(light: Color, dark: Color) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// Color de los acordes.
    static var chord: Color { Theme.chord }
}

/// Fondo de la página: papel cálido y liso.
struct NotebookPaper: View {
    var body: some View {
        Theme.paper.ignoresSafeArea()
    }
}

/// Etiqueta en cápsula (tono, cejilla, tempo…).
struct Chip: View {
    let text: String
    var systemImage: String?
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).imageScale(.small)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 0.5))
        .foregroundStyle(tint)
    }
}

/// Etiqueta de sección (INTRO, SOLO, PUENTE…).
struct SectionTag: View {
    let text: String
    let fontSize: Double

    var body: some View {
        Text(text.uppercased())
            .font(Theme.labelFont(fontSize))
            .tracking(1.2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.secondaryInk.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(Theme.secondaryInk)
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
