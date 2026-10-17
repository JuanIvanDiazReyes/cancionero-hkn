import Foundation

/// Compás: tiempos por compás y figura que lleva el pulso (4/4, 3/4, 6/8…).
public struct TimeSignature: Hashable, Codable, Sendable, CustomStringConvertible {
    public var beats: Int
    public var unit: Int

    public init(beats: Int, unit: Int) {
        self.beats = beats
        self.unit = unit
    }

    public static let common: [TimeSignature] = [
        TimeSignature(beats: 2, unit: 4), TimeSignature(beats: 3, unit: 4),
        TimeSignature(beats: 4, unit: 4), TimeSignature(beats: 6, unit: 8),
        TimeSignature(beats: 12, unit: 8),
    ]

    public var description: String { "\(beats)/\(unit)" }

    /// Tiempos fuertes: en 6/8 y 12/8 se acentúa cada tres corcheas.
    public func isAccent(_ beat: Int) -> Bool {
        unit == 8 && beats % 3 == 0 ? beat % 3 == 0 : beat == 0
    }
}

public enum TempoRange {
    public static let bpm = 30...260
    public static func clamp(_ bpm: Int) -> Int { min(max(bpm, self.bpm.lowerBound), self.bpm.upperBound) }

    /// Nombre italiano aproximado del tempo.
    public static func marking(for bpm: Int) -> String {
        switch bpm {
        case ..<60: return "Largo"
        case ..<76: return "Adagio"
        case ..<108: return "Andante"
        case ..<120: return "Moderato"
        case ..<168: return "Allegro"
        default: return "Presto"
        }
    }
}

/// Calcula el tempo a partir de toques en pantalla.
public struct TapTempo: Sendable {
    /// Si pasa más tiempo que esto entre toques, se empieza de nuevo.
    public var resetAfter: TimeInterval = 2.0
    public var maxTaps = 8
    public private(set) var taps: [TimeInterval] = []

    public init() {}

    /// Registra un toque y devuelve el tempo cuando ya hay al menos dos.
    public mutating func tap(at time: TimeInterval) -> Int? {
        if let last = taps.last, time - last > resetAfter || time <= last { taps.removeAll() }
        taps.append(time)
        if taps.count > maxTaps { taps.removeFirst(taps.count - maxTaps) }
        guard taps.count >= 2, let first = taps.first, let last = taps.last else { return nil }
        let interval = (last - first) / Double(taps.count - 1)
        return TempoRange.clamp(Int((60 / interval).rounded()))
    }

    public mutating func reset() { taps.removeAll() }
}
