import Foundation
import CoreBluetooth
import Combine
import os.log

// Structure to hold servo positions for each finger
struct FingerServoPositions {
    let thumb: Int
    let index: Int
    let middle: Int
    let ring: Int
    let pinky: Int

    init(thumb: Int, index: Int, middle: Int, ring: Int, pinky: Int) {
        // Clamp values to the 0-180 range
        self.thumb = min(max(0, thumb), 180)
        self.index = min(max(0, index), 180)
        self.middle = min(max(0, middle), 180)
        self.ring = min(max(0, ring), 180)
        self.pinky = min(max(0, pinky), 180)
    }
}

class BLERobotArmViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isBluetoothOn: Bool = false
    private var shouldScanWhenPoweredOn = false
    private var shouldAutoReconnect = false
    private var lastConnectedPeripheralIdentifier: UUID?
    private var isReconnectPending = false
    @Published var isConnected = false
    @Published var errorMessage: String?
    @Published var connectedDeviceName: String? = nil


    @Published var discoveredDevices: [CBPeripheral] = []
    
    private var centralManager: CBCentralManager!
    @Published var robotPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    
    private let serviceUUID = CBUUID(string: "183a1cf5-6e25-4c0c-a386-d854e1305b3b")
    private let characteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    
    override init() {
        super.init()
        // Initialize with showPowerAlert to prompt user to turn on Bluetooth if needed
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        
        // Check initial state immediately
        if centralManager.state == .poweredOn {
            isBluetoothOn = true
        }
    }
    
    func scanAndConnect() {
        errorMessage = nil
        discoveredDevices.removeAll()
        switch centralManager.state {
        case .poweredOn:
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        case .unauthorized, .unknown:
            // Prompt for permission by re-initializing CBCentralManager
            centralManager = CBCentralManager(delegate: self, queue: nil)
            shouldScanWhenPoweredOn = true
        case .poweredOff:
            errorMessage = "Bluetooth is powered off. Please turn on Bluetooth."
        case .unsupported:
            errorMessage = "Bluetooth not supported on this device."
        default:
            errorMessage = "Bluetooth is not available."
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        robotPeripheral = peripheral
        robotPeripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Debug state
        print("Bluetooth state: \(central.state.rawValue)")
        
        isBluetoothOn = (central.state == .poweredOn)
        
        if isBluetoothOn {
            print("Bluetooth is powered on")
            errorMessage = nil
            if shouldScanWhenPoweredOn {
                shouldScanWhenPoweredOn = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.scanAndConnect()
                }
            }
        } else if central.state == .poweredOff {
            errorMessage = "Bluetooth is powered off."
        } else if central.state == .unauthorized {
            errorMessage = "Bluetooth permission denied."
        } else if central.state == .unsupported {
            errorMessage = "Bluetooth not supported on this device."
        } else {
            errorMessage = "Bluetooth state: \(central.state.rawValue)"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("🔍 Discovered peripheral: \(peripheral.identifier.uuidString)")
        print("   Name: \(peripheral.name ?? "Unknown")")
        print("   RSSI: \(RSSI) dBm")
        print("   Advertisement data: \(advertisementData)")
        
        // Only add unique devices
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
            print("   ✅ Added to discovered devices list")
        } else {
            print("   ℹ️ Already in discovered devices list")
        }

        if shouldAutoReconnect, let lastId = lastConnectedPeripheralIdentifier, lastId == peripheral.identifier, !isConnected {
            connect(to: peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to peripheral: \(peripheral.identifier.uuidString)")
        isConnected = true
        errorMessage = nil
        connectedDeviceName = peripheral.name ?? "Unknown Device"
        shouldAutoReconnect = true
        lastConnectedPeripheralIdentifier = peripheral.identifier
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔌 Peripheral disconnected: \(peripheral.identifier.uuidString) error: \(error?.localizedDescription ?? "none")")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isConnected = false
            self.commandCharacteristic = nil // Clear characteristic on disconnect
            self.connectedDeviceName = nil
            if self.robotPeripheral?.identifier == peripheral.identifier {
                peripheral.delegate = nil // Important: Nil out delegate before releasing peripheral
                self.robotPeripheral = nil // Clear our reference
            }
            // Optionally, you might want to set an error message or attempt to rescan/reconnect here
            // For now, just update state.
            if let error = error {
                self.errorMessage = "Disconnected with error: \(error.localizedDescription)"
            } else {
                self.errorMessage = nil // Clear error on successful disconnect
            }

            if self.shouldAutoReconnect {
                self.attemptAutoReconnect(to: peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ FAILED TO CONNECT to peripheral: \(peripheral.identifier.uuidString)")
        print("   Error: \(error?.localizedDescription ?? "Unknown error")")
        errorMessage = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        isConnected = false
        connectedDeviceName = nil
        if shouldAutoReconnect {
            attemptAutoReconnect(to: peripheral)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ ERROR discovering services: \(error.localizedDescription)")
            errorMessage = "Error discovering services"
            return
        }
        
        print("📡 Services discovered: \(peripheral.services?.count ?? 0)")
        if let services = peripheral.services {
            for service in services {
                print("   Service: \(service.uuid)")
            }
        }
        
        if let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) {
            print("✅ Found target service: \(service.uuid)")
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        } else {
            print("❌ Target service not found")
            errorMessage = "Required service not found on device"
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("❌ ERROR discovering characteristics: \(error.localizedDescription)")
            errorMessage = "Error discovering characteristics"
            return
        }
        
        print("📡 Characteristics discovered for service \(service.uuid): \(service.characteristics?.count ?? 0)")
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                print("   Characteristic: \(characteristic.uuid)")
            }
        }
        
        if let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID }) {
            print("✅ Found target characteristic: \(characteristic.uuid)")
            commandCharacteristic = characteristic
        } else {
            print("❌ Target characteristic not found")
            errorMessage = "Required characteristic not found on device"
        }
    }
    
    // Command throttling properties
    private var lastCommandTime: Date = Date.distantPast
    private var commandQueue: [(prefix: String, value: Int)] = []
    private var commandTimer: Timer?
    private let commandInterval: TimeInterval = 0.5 // 2 commands per second
    
    func sendCommand(prefix: String, value: Int) {
        // Add command to queue
        commandQueue.append((prefix: prefix, value: value))
        
        // If no timer is running, start one
        if commandTimer == nil {
            processNextCommand()
            commandTimer = Timer.scheduledTimer(withTimeInterval: commandInterval, repeats: true) { [weak self] _ in
                self?.processNextCommand()
            }
        }
    }
    
    private func processNextCommand() {
        // If no commands in queue or not enough time has passed, do nothing
        guard !commandQueue.isEmpty else {
            // Stop timer if queue is empty
            commandTimer?.invalidate()
            commandTimer = nil
            return
        }
        
        let now = Date()
        let timeSinceLastCommand = now.timeIntervalSince(lastCommandTime)
        
        // Only send if enough time has passed
        if timeSinceLastCommand >= commandInterval {
            // Get the most recent command for each prefix (to avoid sending outdated positions)
            let prefixes = Set(commandQueue.map { $0.prefix })
            var commandsToSend: [(prefix: String, value: Int)] = []
            
            for prefix in prefixes {
                if let lastCommand = commandQueue.last(where: { $0.prefix == prefix }) {
                    commandsToSend.append(lastCommand)
                }
            }
            
            // Clear the queue
            commandQueue.removeAll()
            
            // Send each command
            for command in commandsToSend {
                sendCommandImmediate(prefix: command.prefix, value: command.value)
            }
            
            lastCommandTime = now
        }
    }
    
    private func sendCommandImmediate(prefix: String, value: Int) {
        guard let peripheral = robotPeripheral, let characteristic = commandCharacteristic else {
            print("⚠️ Cannot send command: No peripheral or characteristic")
            return 
        }
        // Use new protocol: S-X:angle (e.g., S-T:090)
        let cmd = "S-\(prefix):\(value)"
        print("📤 Sending command: \(cmd)")
        if let data = cmd.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
    
    // Public method to set finger positions
    func setFingerPositions(_ positions: FingerServoPositions) {
        // Use new protocol: P-T:angle,I:angle,M:angle,R:angle,P:angle,W:angle
        let commandString = String(format: "P-T:%d,I:%d,M:%d,R:%d,P:%d",
                                 positions.thumb,
                                 positions.index,
                                 positions.middle,
                                 positions.ring,
                                 positions.pinky)
        sendRawCommand(commandString)
    }

    // Send a raw command string (for commands that don't follow the prefix+value pattern)
    private func sendRawCommand(_ command: String) {
        guard let peripheral = robotPeripheral, let characteristic = commandCharacteristic else {
            print("⚠️ Cannot send command: No peripheral or characteristic")
            return 
        }
        print("📤 Sending raw command: \(command)")
        if let data = command.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
    
    func disconnect() {
        if let peripheral = robotPeripheral {
            print("🔌 Attempting to disconnect from peripheral: \(peripheral.identifier.uuidString)")
            shouldAutoReconnect = false
            lastConnectedPeripheralIdentifier = nil
            centralManager.cancelPeripheralConnection(peripheral)
            // State updates (isConnected, robotPeripheral = nil, etc.) 
            // will be handled by centralManager(_:didDisconnectPeripheral:error:)
        } else {
            print("⚠️ Disconnect called but no peripheral is currently connected or being connected to.")
            // If no peripheral, ensure states are consistent for a disconnected state
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                self?.robotPeripheral = nil
                self?.commandCharacteristic = nil
                self?.connectedDeviceName = nil
                self?.errorMessage = nil
            }
        }
    }

    private func attemptAutoReconnect(to peripheral: CBPeripheral) {
        guard !isReconnectPending else { return }
        isReconnectPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.isReconnectPending = false
            if self.centralManager.state == .poweredOn {
                self.centralManager.connect(peripheral, options: nil)
                self.centralManager.scanForPeripherals(withServices: [self.serviceUUID], options: nil)
            } else {
                self.shouldScanWhenPoweredOn = true
            }
        }
    }
}
