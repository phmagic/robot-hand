import Foundation

enum Gesture: String, CaseIterable, Identifiable {
    case rock = "Rock"
    case paper = "Paper"
    case scissors = "Scissors"
    case none = "None"

    var id: String { self.rawValue }

    var emoji: String {
        switch self {
        case .rock:     return "✊"
        case .paper:    return "✋"
        case .scissors: return "✌️"
        case .none:     return "❓"
        }
    }

    // Helper to convert from a prediction string (e.g., from Core ML)
    static func fromPredictionString(_ prediction: String) -> Gesture? {
        return Gesture(rawValue: prediction)
    }
    
    
}
