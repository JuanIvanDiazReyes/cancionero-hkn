import PencilKit
import SwiftUI
import UIKit

/// Herramienta de dibujo elegida en la paleta.
enum DrawingTool: Hashable {
    case pen(Color)
    case marker
    case eraser

    static let penColors: [Color] = [.black, .red, .blue, Color(red: 0.1, green: 0.6, blue: 0.2)]

    var pkTool: PKTool {
        switch self {
        case let .pen(color): return PKInkingTool(.pen, color: UIColor(color), width: 3)
        case .marker: return PKInkingTool(.marker, color: UIColor.systemYellow.withAlphaComponent(0.6), width: 18)
        case .eraser: return PKEraserTool(.vector)
        }
    }
}

/// Lienzo transparente de PencilKit encima de un bloque de la canción.
struct BlockCanvas: UIViewRepresentable {
    let initialData: Data?
    let isEditable: Bool
    let tool: DrawingTool
    let fingerDraws: Bool
    let onChange: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.clipsToBounds = false
        if let data = initialData, let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.onChange = onChange
        canvas.isUserInteractionEnabled = isEditable
        canvas.drawingPolicy = fingerDraws ? .anyInput : .pencilOnly
        canvas.tool = tool.pkTool
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onChange: (Data) -> Void

        init(onChange: @escaping (Data) -> Void) {
            self.onChange = onChange
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onChange(canvasView.drawing.dataRepresentation())
        }
    }
}

/// Barra con lápices de colores, marcador, borrador y si el dedo dibuja.
struct DrawingPalette: View {
    @Binding var tool: DrawingTool
    @Binding var fingerDraws: Bool
    let onClearAll: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ForEach(DrawingTool.penColors, id: \.self) { color in
                Button { tool = .pen(color) } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.primary, lineWidth: tool == .pen(color) ? 2.5 : 0).padding(-4))
                }
                .accessibilityLabel("Lápiz")
            }
            Divider().frame(height: 24)
            toolButton(.marker, "highlighter", "Marcador")
            toolButton(.eraser, "eraser", "Borrador")
            Divider().frame(height: 24)
            Button { fingerDraws.toggle() } label: {
                Image(systemName: fingerDraws ? "hand.draw.fill" : "applepencil")
                    .font(.title3)
            }
            .accessibilityLabel(fingerDraws ? "El dedo dibuja" : "Solo Apple Pencil")
            Menu {
                Button("Borrar todos los dibujos de esta canción", role: .destructive, action: onClearAll)
            } label: {
                Image(systemName: "trash").font(.title3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
    }

    private func toolButton(_ value: DrawingTool, _ symbol: String, _ label: String) -> some View {
        Button { tool = value } label: {
            Image(systemName: symbol)
                .font(.title3)
                .padding(4)
                .background(tool == value ? Color.accentColor.opacity(0.2) : .clear, in: Circle())
        }
        .accessibilityLabel(label)
    }
}
