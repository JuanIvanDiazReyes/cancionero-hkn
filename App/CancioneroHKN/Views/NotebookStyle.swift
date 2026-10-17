import CancioneroCore
import SwiftUI
import UIKit

/// Sistema visual de la app: colores, tipografías y piezas reutilizables.
enum Theme {
    /// Color principal de la app (botones, selección), según el tema elegido.
    static var accent: Color { AppTheme.current.accent }
    /// Acordes: color intenso, distinto de los colores de voz.
    static var chord: Color { AppTheme.current.chord }
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

/// Combinaciones de color que el usuario puede elegir en Ajustes.
enum AppTheme: String, CaseIterable, Identifiable {
    case ocean, forest, wine, violet, graphite

    static let storageKey = "theme"
    static var current: AppTheme {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppTheme.init(rawValue:)) ?? .ocean
    }

    var id: Self { self }

    var name: String {
        switch self {
        case .ocean: return "Océano"
        case .forest: return "Bosque"
        case .wine: return "Vino"
        case .violet: return "Lavanda"
        case .graphite: return "Grafito"
        }
    }

    var accent: Color {
        switch self {
        case .ocean: return Color(light: Color(hex: 0x1F4E79), dark: Color(hex: 0x7FB2E5))
        case .forest: return Color(light: Color(hex: 0x2F5D3A), dark: Color(hex: 0x8FCB9B))
        case .wine: return Color(light: Color(hex: 0x7A1F3D), dark: Color(hex: 0xE88AA8))
        case .violet: return Color(light: Color(hex: 0x4B3B8F), dark: Color(hex: 0xB3A6F0))
        case .graphite: return Color(light: Color(hex: 0x2E3440), dark: Color(hex: 0xC9CED8))
        }
    }

    var chord: Color {
        switch self {
        case .ocean: return Color(light: Color(hex: 0x0B7A75), dark: Color(hex: 0x4FD1C5))
        case .forest: return Color(light: Color(hex: 0xB5651D), dark: Color(hex: 0xF0A868))
        case .wine: return Color(light: Color(hex: 0x1F6F8B), dark: Color(hex: 0x7CC6E0))
        case .violet: return Color(light: Color(hex: 0x0E7C66), dark: Color(hex: 0x5ED6B8))
        case .graphite: return Color(light: Color(hex: 0xC2410C), dark: Color(hex: 0xFB923C))
        }
    }
}

/// Modo claro, oscuro o el del sistema.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"
    var id: Self { self }

    var name: String {
        switch self {
        case .system: return "Automático"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
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
