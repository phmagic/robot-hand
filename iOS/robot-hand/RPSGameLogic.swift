import Foundation

struct RPSGameLogic {

    enum Outcome: String, Identifiable {
        case playerWins = "You Win! 🎉"
        case aiWins = "AI Wins! 🤖"
        case draw = "It's a Draw! 🤝"
        case play = "Play!" // Initial state or prompt to play

        var id: String { self.rawValue }
    }

    func aiMakesChoice() -> Gesture {
        guard !Gesture.allCases.isEmpty else {
            fatalError("Gesture.allCases is empty. Ensure Gesture enum is defined and accessible.")
        }
        
        return Gesture.allCases.randomElement()!
    }
    
    func aiWinningChoice(for playerGesture: Gesture) -> Gesture {
        switch playerGesture {
        case .rock:
            return .paper
        case .paper:
            return .scissors
        case .scissors:
            return .rock
        default:
            return .none
        }
    }

    func determineOutcome(playerGesture: Gesture, aiGesture: Gesture) -> Outcome {
        if playerGesture == aiGesture {
            return .draw
        }

        switch playerGesture {
        case .rock:
            return aiGesture == .scissors ? .playerWins : .aiWins
        case .paper:
            return aiGesture == .rock ? .playerWins : .aiWins
        case .scissors:
            return aiGesture == .paper ? .playerWins : .aiWins
        default:
            return .draw
            
        }
    }
}
