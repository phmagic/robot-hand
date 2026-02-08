import Foundation
import SwiftData

// MARK: - Command Type

enum CommandType: String, Codable, CaseIterable {
    case move = "Move"
    case wait = "Wait"

    var iconName: String {
        switch self {
        case .move: return "hand.raised.fill"
        case .wait: return "clock.fill"
        }
    }
}

// MARK: - Stored Finger Positions

struct StoredFingerPositions: Codable, Equatable {
    var thumb: Int
    var index: Int
    var middle: Int
    var ring: Int
    var pinky: Int
    var wrist: Int

    init(thumb: Int = 0, index: Int = 0, middle: Int = 0,
         ring: Int = 0, pinky: Int = 0, wrist: Int = 90) {
        self.thumb = min(max(0, thumb), 150)
        self.index = min(max(0, index), 180)
        self.middle = min(max(0, middle), 180)
        self.ring = min(max(0, ring), 180)
        self.pinky = min(max(0, pinky), 150)
        self.wrist = min(max(0, wrist), 180)
    }

    func toFingerServoPositions() -> FingerServoPositions {
        FingerServoPositions(thumb: thumb, index: index,
                             middle: middle, ring: ring, pinky: pinky)
    }

    static let openHand = StoredFingerPositions(
        thumb: 0, index: 0, middle: 0, ring: 0, pinky: 0, wrist: 90
    )

    static let closedFist = StoredFingerPositions(
        thumb: 150, index: 180, middle: 180, ring: 180, pinky: 150, wrist: 90
    )
}

// MARK: - Program Command Model

@Model
final class ProgramCommand {
    var id: UUID
    var typeRaw: String
    var orderIndex: Int
    var fingerPositionsData: Data?
    var waitDuration: Double
    var program: RobotProgram?

    // Cache for decoded finger positions
    @Transient private var _cachedFingerPositions: StoredFingerPositions?

    var type: CommandType {
        get { CommandType(rawValue: typeRaw) ?? .move }
        set { typeRaw = newValue.rawValue }
    }

    init(type: CommandType, orderIndex: Int = 0,
         fingerPositions: StoredFingerPositions? = nil,
         waitDuration: Double = 1.0) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.orderIndex = orderIndex
        self.waitDuration = waitDuration
        if let positions = fingerPositions {
            self.fingerPositionsData = try? JSONEncoder().encode(positions)
            self._cachedFingerPositions = positions
        }
    }

    var fingerPositions: StoredFingerPositions {
        get {
            if let cached = _cachedFingerPositions {
                return cached
            }
            guard let data = fingerPositionsData,
                  let positions = try? JSONDecoder().decode(StoredFingerPositions.self, from: data)
            else { return .openHand }
            _cachedFingerPositions = positions
            return positions
        }
        set {
            fingerPositionsData = try? JSONEncoder().encode(newValue)
            _cachedFingerPositions = newValue
        }
    }
}

// MARK: - Robot Program Model

@Model
final class RobotProgram {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ProgramCommand.program)
    var commands: [ProgramCommand]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.commands = []
    }

    var sortedCommands: [ProgramCommand] {
        commands.sorted { $0.orderIndex < $1.orderIndex }
    }

    func addCommand(_ command: ProgramCommand) {
        command.orderIndex = commands.count
        command.program = self
        commands.append(command)
    }

    func removeCommand(_ command: ProgramCommand) {
        commands.removeAll { $0.id == command.id }
        reorderCommands()
    }

    func markUpdated() {
        updatedAt = Date()
    }

    func reorderCommands() {
        for (index, command) in sortedCommands.enumerated() {
            command.orderIndex = index
        }
    }
}
