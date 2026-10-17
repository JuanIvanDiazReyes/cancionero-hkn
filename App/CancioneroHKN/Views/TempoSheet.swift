import CancioneroCore
import SwiftUI

/// Tempo, compás, metrónomo y notas de arreglo de una canción.
struct TempoSheet: View {
    @Binding var bpm: Int?
    @Binding var signature: TimeSignature
    @Binding var arrangement: String
    @ObservedObject var metronome: Metronome

    @Environment(\.dismiss) private var dismiss
    @State private var tapTempo = TapTempo()
    @State private var tapFlash = false

    private var value: Int { bpm ?? 90 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    tempoCard
                    section("Compás") {
                        Picker("Compás", selection: $signature) {
                            ForEach(TimeSignature.common, id: \.self) { Text($0.description).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    section("Metrónomo") { metronomeCard }
                    section("Arreglo") {
                        TextField("Ej.: Intro solo piano. 1.ª estrofa voz mujer. En el coro entra la batería…",
                                  text: $arrangement, axis: .vertical)
                            .lineLimit(4...12)
                            .padding(12)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline))
                        Text("Aparece en la cabecera de la canción.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tempo y arreglo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
                if bpm != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Quitar tempo", role: .destructive) {
                            metronome.stop()
                            bpm = nil
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: bpm) { syncMetronome() }
        .onChange(of: signature) { syncMetronome() }
    }

    private var tempoCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(bpm.map(String.init) ?? "—")
                    .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(bpm == nil ? Theme.secondaryInk : Theme.ink)
                    .contentTransition(.numericText())
                Text("BPM")
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            Text(bpm == nil ? "Sin tempo: toca el ritmo o elige uno" : TempoRange.marking(for: value))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryInk)

            HStack(spacing: 16) {
                stepButton("minus", delta: -1)
                Slider(value: Binding(get: { Double(value) }, set: { bpm = Int($0) }),
                       in: Double(TempoRange.bpm.lowerBound)...Double(TempoRange.bpm.upperBound), step: 1)
                stepButton("plus", delta: 1)
            }

            Button {
                if let measured = tapTempo.tap(at: Date().timeIntervalSinceReferenceDate) {
                    withAnimation { bpm = measured }
                }
                tapFlash.toggle()
            } label: {
                Label("Tocar al ritmo", systemImage: "hand.tap.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: tapFlash)
            Text("Toca 4 veces o más siguiendo el pulso de la canción.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline))
    }

    private func stepButton(_ symbol: String, delta: Int) -> some View {
        Button {
            withAnimation { bpm = TempoRange.clamp(value + delta) }
        } label: {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 40, height: 40)
                .background(Theme.accent.opacity(0.10), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .buttonRepeatBehavior(.enabled)
    }

    private var metronomeCard: some View {
        HStack(spacing: 16) {
            Button {
                if bpm == nil { bpm = value }
                syncMetronome()
                metronome.toggle()
            } label: {
                Image(systemName: metronome.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(metronome.isPlaying ? Color.red : Theme.accent, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(metronome.isPlaying ? "Parar metrónomo" : "Iniciar metrónomo")
            BeatDots(beats: signature.beats, current: metronome.isPlaying ? metronome.beat : nil,
                     signature: signature)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline))
    }

    private func syncMetronome() {
        metronome.configure(bpm: value, signature: signature)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

/// Un punto por tiempo; se ilumina el que suena y el primero es más grande.
struct BeatDots: View {
    let beats: Int
    let current: Int?
    let signature: TimeSignature
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: size * 0.5) {
            ForEach(0..<beats, id: \.self) { beat in
                let accent = signature.isAccent(beat)
                Circle()
                    .fill(current == beat ? (accent ? Color.orange : Theme.accent) : Theme.hairline)
                    .frame(width: accent ? size * 1.25 : size, height: accent ? size * 1.25 : size)
                    .scaleEffect(current == beat ? 1.15 : 1)
                    .animation(.easeOut(duration: 0.08), value: current)
            }
        }
    }
}
