//
//  ContentView.swift
//  rps-robot-hand
//
//  Created by Phu Nguyen on 6/6/25.
//

import SwiftUI
import AudioToolbox
import Vision

enum GamePhase: Equatable {
    case idle
    case waitingForHand
    case countdown(Int)
    case capturing
    case result
    case waitingForRemoval
}

struct GameRound: Identifiable {
    let id = UUID()
    let playerGesture: Gesture
    let aiGesture: Gesture
    let outcome: RPSGameLogic.Outcome
}

struct GameView: View {
    @EnvironmentObject private var cameraManager: CameraManager
    @EnvironmentObject private var imageClassifier: ImageClassifier
    @EnvironmentObject private var bleManager: BLERobotArmViewModel

    @StateObject private var handPoseDetector = HandPoseDetector()

    private let gameLogic = RPSGameLogic()
    private let confidenceThreshold: Float = 0.80

    // Game state
    @State private var phase: GamePhase = .idle
    @State private var playerGestureForGame: Gesture? = nil
    @State private var aiGestureForGame: Gesture? = nil
    @State private var gameOutcome: RPSGameLogic.Outcome = .play

    // Timers & effects
    @State private var phaseTimer: Timer? = nil
    @State private var flashOpacity: Double = 0.0

    // Hand detection debounce
    @State private var consecutiveHandFrames: Int = 0
    private let requiredConsecutiveFrames = 3

    // Hand removal debounce
    @State private var consecutiveNoHandFrames: Int = 0
    private let requiredConsecutiveNoHandFrames = 5

    // History
    @State private var roundHistory: [GameRound] = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PredictionCameraView(frameHeight: nil,
                                     cornerRadius: 0,
                                     horizontalPadding: 0,
                                     bottomPadding: 0,
                                     showsOverlay: false,
                                     autoClassify: true,
                                     contentMode: .fill,
                                     isClipped: true,
                                     overlayAlignment: .top)
                .environmentObject(cameraManager)
                .environmentObject(imageClassifier)

                // Hand skeleton overlay
                HandPoseOverlayView(
                    points: handPoseDetector.recognizedPoints,
                    imageSize: cameraManager.currentFrame.map {
                        CGSize(width: $0.width, height: $0.height)
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .allowsHitTesting(false)

                Color.white
                    .opacity(flashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Top-left: history overlay
                if !roundHistory.isEmpty {
                    historyOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                // Bottom: controls panel
                VStack(spacing: 12) {
                    GamePlayControlsView(
                        playerMove: $playerGestureForGame,
                        aiMove: $aiGestureForGame,
                        gameOutcome: $gameOutcome,
                        phase: phase,
                        onTapPlay: { startGame() }
                    )
                }
                .frame(maxWidth: max(0, proxy.size.width - 32), alignment: .center)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .contentShape(Rectangle())
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            OrientationLock.lockLandscape()
            cameraManager.refreshVideoOrientation()
        }
        .onDisappear {
            phaseTimer?.invalidate()
            phaseTimer = nil
            phase = .idle
            OrientationLock.unlock()
            cameraManager.refreshVideoOrientation()
        }
        .onChange(of: cameraManager.currentPixelBuffer) { newPixelBuffer in
            if let pixelBuffer = newPixelBuffer {
                handPoseDetector.process(pixelBuffer: pixelBuffer)
            }
        }
        .onChange(of: handPoseDetector.recognizedPoints) { _ in
            handleHandDetectionUpdate()
        }
    }

    // MARK: - History Overlay

    private var historyOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(roundHistory.suffix(3)) { round in
                HStack(spacing: 4) {
                    Text(round.playerGesture.emoji)
                    Text(round.outcome == .playerWins ? ">" :
                         round.outcome == .aiWins ? "<" : "=")
                        .font(.caption.bold())
                        .foregroundColor(
                            round.outcome == .playerWins ? .green :
                            round.outcome == .aiWins ? .red : .orange
                        )
                    Text(round.aiGesture.emoji)
                }
                .font(.title2)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.55))
        .foregroundColor(.white)
        .cornerRadius(10)
        .padding()
    }

    // MARK: - State Machine

    private func handleHandDetectionUpdate() {
        switch phase {
        case .waitingForHand:
            if handPoseDetector.hasHand {
                consecutiveHandFrames += 1
                consecutiveNoHandFrames = 0
                if consecutiveHandFrames >= requiredConsecutiveFrames {
                    consecutiveHandFrames = 0
                    beginCountdown()
                }
            } else {
                consecutiveHandFrames = 0
            }

        case .waitingForRemoval:
            if !handPoseDetector.hasHand {
                consecutiveNoHandFrames += 1
                if consecutiveNoHandFrames >= requiredConsecutiveNoHandFrames {
                    consecutiveNoHandFrames = 0
                    phase = .waitingForHand
                }
            } else {
                consecutiveNoHandFrames = 0
            }

        default:
            break
        }
    }

    private func startGame() {
        playerGestureForGame = nil
        aiGestureForGame = nil
        gameOutcome = .play
        consecutiveHandFrames = 0
        consecutiveNoHandFrames = 0
        phase = .waitingForHand
    }

    private func beginCountdown() {
        phase = .countdown(3)
        playCountdownSound()

        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            switch phase {
            case .countdown(let n) where n > 1:
                phase = .countdown(n - 1)
                playCountdownSound()
            case .countdown:
                timer.invalidate()
                phaseTimer = nil
                performCapture()
            default:
                timer.invalidate()
                phaseTimer = nil
            }
        }
    }

    private func performCapture() {
        phase = .capturing
        flashCapture()

        guard let prediction = imageClassifier.currentPrediction,
              prediction.confidence >= confidenceThreshold,
              let playerGesture = Gesture.fromPredictionString(prediction.label),
              playerGesture != .none else {
            // Failed to detect valid gesture — retry
            phase = .waitingForHand
            return
        }

        playerGestureForGame = playerGesture
        let aiGesture = gameLogic.aiWinningChoice(for: playerGesture)
        aiGestureForGame = aiGesture
        let outcome = gameLogic.determineOutcome(playerGesture: playerGesture, aiGesture: aiGesture)
        gameOutcome = outcome

        // Command robot arm
        let servoPositions = getServoPositions(for: aiGesture)
        bleManager.setFingerPositions(servoPositions)

        // Record history
        roundHistory.append(GameRound(playerGesture: playerGesture, aiGesture: aiGesture, outcome: outcome))

        // Show result, then transition
        phase = .result
        playResultSound(outcome: outcome)

        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            phase = .waitingForRemoval
        }
    }

    // MARK: - Effects

    private func flashCapture() {
        flashOpacity = 0.8
        withAnimation(.easeOut(duration: 0.3)) {
            flashOpacity = 0.0
        }
    }

    // MARK: - Sound

    private func playCountdownSound() {
        AudioServicesPlaySystemSound(1057)
    }

    private func playResultSound(outcome: RPSGameLogic.Outcome) {
        switch outcome {
        case .playerWins:
            AudioServicesPlaySystemSound(1025)
        case .aiWins:
            AudioServicesPlaySystemSound(1073)
        case .draw:
            AudioServicesPlaySystemSound(1057)
        case .play:
            break
        }
    }

    // MARK: - Robot Arm

    private func getServoPositions(for gesture: Gesture?) -> FingerServoPositions {
        switch gesture {
        case .rock:
            return FingerServoPositions(thumb: 150, index: 170, middle: 180, ring: 180, pinky: 150)
        case .paper:
            return FingerServoPositions(thumb: 0, index: 0, middle: 0, ring: 0, pinky: 0)
        case .scissors:
            return FingerServoPositions(thumb: 150, index: 0, middle: 0, ring: 180, pinky: 150)
        case .none, nil:
            return FingerServoPositions(thumb: 0, index: 0, middle: 0, ring: 0, pinky: 0)
        case .some(.none):
            return FingerServoPositions(thumb: 0, index: 0, middle: 0, ring: 0, pinky: 0)
        }
    }
}
