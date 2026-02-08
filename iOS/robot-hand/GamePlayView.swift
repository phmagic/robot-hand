//
//  GamePlayView.swift
//  rps-robot-hand
//
//  Created by Phu Nguyen on 6/9/25.
//

import SwiftUI

struct GamePlayControlsView: View {
    @Binding var playerMove: Gesture?
    @Binding var aiMove: Gesture?
    @Binding var gameOutcome: RPSGameLogic.Outcome
    let phase: GamePhase
    var onTapPlay: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            phaseTitle

            HStack {
                VStack {
                    Text("You")
                        .font(.caption)
                    Text(playerMove?.emoji ?? "❓")
                        .font(.largeTitle)
                }
                Spacer()
                phaseCenter
                Spacer()
                VStack {
                    Text("AI")
                        .font(.caption)
                    Text(aiMove?.emoji ?? "❓")
                        .font(.largeTitle)
                }
            }
            .padding(.horizontal, 30)

            if case .idle = phase {
                Button(action: onTapPlay) {
                    Text("Tap to Play")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 8)
            }
        }
    }

    @ViewBuilder
    private var phaseTitle: some View {
        switch phase {
        case .idle:
            Text("Rock Paper Scissors")
                .font(.title3).bold()
        case .waitingForHand:
            Text("Show your hand...")
                .font(.title3).bold()
                .foregroundColor(.yellow)
        case .countdown:
            Text("Hold still!")
                .font(.title3).bold()
                .foregroundColor(.red)
        case .capturing:
            Text("Capturing...")
                .font(.title3).bold()
        case .result:
            EmptyView()
        case .waitingForRemoval:
            Text("Remove your hand...")
                .font(.title3).bold()
                .foregroundColor(.orange)
        }
    }

    @ViewBuilder
    private var phaseCenter: some View {
        switch phase {
        case .countdown(let n):
            Text("\(n)")
                .font(.system(size: 48, weight: .heavy))
                .foregroundColor(.red)
                .id(n)
        case .result:
            Text(gameOutcome.rawValue)
                .font(.title2.bold())
                .foregroundColor(outcomeColor)
        case .waitingForHand:
            ProgressView()
                .tint(.white)
        default:
            EmptyView()
        }
    }

    private var outcomeColor: Color {
        switch gameOutcome {
        case .playerWins: return .green
        case .aiWins: return .red
        case .draw: return .orange
        case .play: return .primary
        }
    }
}
