#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h> // For BLE notifications/indications descriptor

// PCA9685 I2C Servo Driver Setup
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver(); // Default I2C address 0x40

// Define I2C pins for ESP32-C3
#define SDA_PIN 8
#define SCL_PIN 9

// Servo calibration (from esp_servo_test.ino)
#define SERVOMIN  102  // Minimum pulse length count for 0 degrees (out of 4096)
#define SERVOMAX  512  // Maximum pulse length count for 180 degrees (out of 4096)
#define SERVO_FREQ 50  // Analog servos run at ~50 Hz updates

// Define servo channels on PCA9685 (0-15)
#define SERVO_CHANNEL_THUMB  0
#define SERVO_CHANNEL_INDEX  1
#define SERVO_CHANNEL_MIDDLE 2
#define SERVO_CHANNEL_RING   3
#define SERVO_CHANNEL_PINKY  4
#define SERVO_CHANNEL_WRIST  5

// BLE Service and Characteristic UUIDs (Must match iOS app)
#define SERVICE_UUID        "183a1cf5-6e25-4c0c-a386-d854e1305b3b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;

// Helper function to set a single servo's angle (0-180 degrees)
void setServoAngle(uint8_t channel, int angle) {
  angle = constrain(angle, 0, 180);
  int pulse = map(angle, 0, 180, SERVOMIN, SERVOMAX);
  pwm.setPWM(channel, 0, pulse);
}

// Function to set all finger positions (all servos are 180-degree)
void setFingerPositions(int thumb, int index, int middle, int ring, int pinky) {
  Serial.printf("Setting positions: T:%d, I:%d, M:%d, R:%d, P:%d\n", thumb, index, middle, ring, pinky);
  setServoAngle(SERVO_CHANNEL_THUMB, thumb);
  setServoAngle(SERVO_CHANNEL_INDEX, index);
  setServoAngle(SERVO_CHANNEL_MIDDLE, middle);
  setServoAngle(SERVO_CHANNEL_RING, ring);
  setServoAngle(SERVO_CHANNEL_PINKY, pinky);
}

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("BLE Client Connected");
      // You could send an initial state or confirmation here if needed
    }

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("BLE Client Disconnected");
      // Restart advertising so it can be reconnected
      // BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
      // pAdvertising->start(); // More robust way to restart advertising
      BLEDevice::startAdvertising(); 
      Serial.println("Restarting advertising...");
    }
};

// Helper to find a key like 'T' in the command string "T:90,I:90..." and return its integer value.
int getValueFromCommand(String& command, char key) {
  String keyStr = String(key) + ":";
  int keyIndex = command.indexOf(keyStr);
  if (keyIndex == -1) {
    return -1; // Key not found, return an invalid value
  }

  int startIndex = keyIndex + keyStr.length();
  int endIndex = command.indexOf(',', startIndex);
  if (endIndex == -1) { // This handles the last value in the string, which has no trailing comma
    endIndex = command.length();
  }

  String valueStr = command.substring(startIndex, endIndex);
  return valueStr.toInt();
}

class MyCharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      // Get the data as a char array first
      uint8_t* data = pCharacteristic->getData();
      size_t length = pCharacteristic->getLength();
      
      // Only log the command once, not every byte
      if (length > 0) {
        char tempBuf[32]; // Safe fixed-size buffer
        size_t copyLen = length < 31 ? length : 31;
        memcpy(tempBuf, data, copyLen);
        tempBuf[copyLen] = '\0';
        Serial.print("Received BLE command: ");
        Serial.println(tempBuf);
      }
      
      if (length > 0 && length < 64) { // Prevent buffer overflow
        // Create a temporary buffer to ensure null termination
        char buffer[64]; // Fixed size buffer
        size_t copyLen = length < 63 ? length : 63;
        memcpy(buffer, data, copyLen);
        buffer[copyLen] = '\0';
        
        // Convert to Arduino String and process
        String command = String(buffer);
        
        Serial.print("Received BLE Value: ");
        Serial.println(command);

        processCommand(command);
      }
    }
};

void processCommand(String command) {
  command.trim();
  if (command.length() == 0) return;

  Serial.print("Processing command: ");
  Serial.println(command);

  // Multi-servo command: P-T:angle,I:angle,M:angle,R:angle,P:angle
  if (command.startsWith("P-")) {
    // Remove 'P-' prefix
    String payload = command.substring(2);
    int thumbPos = getValueFromCommand(payload, 'T');
    int indexPos = getValueFromCommand(payload, 'I');
    int middlePos = getValueFromCommand(payload, 'M');
    int ringPos = getValueFromCommand(payload, 'R');
    int pinkyPos = getValueFromCommand(payload, 'P');
    int wristPos = getValueFromCommand(payload, 'W');

    Serial.printf("Parsed values - T:%d, I:%d, M:%d, R:%d, P:%d, W:%d\n", thumbPos, indexPos, middlePos, ringPos, pinkyPos, wristPos);

    // Validate that required finger values are present
    if (thumbPos != -1 && indexPos != -1 && middlePos != -1 && ringPos != -1 && pinkyPos != -1) {
      setFingerPositions(thumbPos, indexPos, middlePos, ringPos, pinkyPos);
      // Handle wrist if provided
      if (wristPos >= 0 && wristPos <= 180) {
        setServoAngle(SERVO_CHANNEL_WRIST, wristPos);
      }
    } else {
      Serial.println("Error: One or more finger values missing or out of range.");
    }
  } else if (command.startsWith("S-")) {
    // Single-servo command: S-X:angle (e.g., S-T:90)
    if (command.length() >= 5) { // S- + X:YYY
      char servoId = command.charAt(2); // Get the servo identifier (T, I, M, R, P, W)
      if (command.charAt(3) != ':') {
        Serial.println("Error: Invalid single-servo command format. Expected S-X:angle");
        return;
      }
      String angleStr = command.substring(4);
      int angle = angleStr.toInt();
      Serial.printf("Single servo command: %c to %d\n", servoId, angle);

      if (angle < 0 || angle > 180) {
        Serial.println("Error: Angle out of range (0-180).");
        return;
      }

      switch (servoId) {
        case 'T': setServoAngle(SERVO_CHANNEL_THUMB, angle); break;
        case 'I': setServoAngle(SERVO_CHANNEL_INDEX, angle); break;
        case 'M': setServoAngle(SERVO_CHANNEL_MIDDLE, angle); break;
        case 'R': setServoAngle(SERVO_CHANNEL_RING, angle); break;
        case 'P': setServoAngle(SERVO_CHANNEL_PINKY, angle); break;
        case 'W': setServoAngle(SERVO_CHANNEL_WRIST, angle); break;
        default:
          Serial.printf("Error: Unknown servo ID '%c'. Use T, I, M, R, P, or W.\n", servoId);
          break;
      }
    } else {
      Serial.println("Error: Invalid S- command format or length. Expected 'S-X:angle'.");
    }
  } else {
    Serial.print("Error: Unknown command format: ");
    Serial.println(command);
  }
}

void setup() {
  Serial.begin(115200);
  delay(2000); // Wait for USB CDC serial on ESP32-C3
  Serial.println();
  Serial.println("=================================");
  Serial.println("Starting ESP32-C3 BLE Robot Hand");
  Serial.println("=================================");

  // Initialize I2C for PCA9685
  Serial.printf("Initializing I2C on SDA=%d, SCL=%d\n", SDA_PIN, SCL_PIN);
  Wire.begin(SDA_PIN, SCL_PIN);

  // Scan I2C bus to find devices
  Serial.println("Scanning I2C bus...");
  byte deviceCount = 0;
  for (byte addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.printf("  Found device at 0x%02X\n", addr);
      deviceCount++;
    }
  }
  if (deviceCount == 0) {
    Serial.println("  ERROR: No I2C devices found! Check wiring.");
  } else {
    Serial.printf("  Found %d device(s)\n", deviceCount);
  }

  Serial.println("Initializing PCA9685...");
  pwm.begin();
  pwm.setPWMFreq(SERVO_FREQ);  // Set PWM frequency to 50Hz
  Serial.println("PCA9685 Initialized.");

  // Test servo movement at startup
  Serial.println("Testing servo on channel 1...");
  setServoAngle(SERVO_CHANNEL_THUMB, 0);
  delay(500);
  setServoAngle(SERVO_CHANNEL_THUMB, 90);
  delay(500);
  setServoAngle(SERVO_CHANNEL_THUMB, 0);
  Serial.println("Servo test complete.");

  // Set initial finger positions to 0 degrees (open)
  setFingerPositions(0, 0, 0, 0, 0);
  Serial.println("All fingers initialized to 0 degrees.");

  // Create the BLE Device
  BLEDevice::init("ESP32_RPS_Hand"); // Set a unique name for your BLE device

  // Create the BLE Server
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_WRITE | // Allow writing from client
                      BLECharacteristic::PROPERTY_READ    // Optional: Allow reading current state
                      // BLECharacteristic::PROPERTY_NOTIFY // Optional: For sending data to client
                    );
  
  // pCharacteristic->addDescriptor(new BLE2902()); // Add if using NOTIFY or INDICATE
  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  // pCharacteristic->setValue("Initial Hand State"); // Optional: set initial readable value

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  // Helps with iPhone connection issues (may or may not be needed)
  // pAdvertising->setMinPreferred(0x06);  
  // pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("BLE Service started. Advertising...");
}

void loop() {
  // The main work is done in BLE callbacks.
  // You could add other tasks here if needed, like reading sensors.
  delay(100); // Small delay to keep the loop from spinning too fast and starving other tasks
}