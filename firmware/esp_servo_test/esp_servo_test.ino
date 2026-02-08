#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>

// Called this way, it uses the default I2C address 0x40
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver();

// Define I2C pins for ESP32 (default pins are GPIO21 for SDA, GPIO22 for SCL)
#define SDA_PIN 21
#define SCL_PIN 22

// These pulse lengths are for a 50Hz frequency.
// Min pulse: 0.5ms (102/4096 * 20000us)
// Max pulse: 2.5ms (512/4096 * 20000us)
// This typically corresponds to 0-180 degrees for many servos.
// You may need to adjust these values for your specific servos.
#define SERVOMIN  102  // Minimum pulse length count (out of 4096)
#define SERVOMAX  512  // Maximum pulse length count (out of 4096)
#define SERVO_FREQ 50  // Analog servos run at ~50 Hz updates

// You can choose which channel (0-15) on the PCA9685 to connect your servo to
uint8_t servoChannel = 0;
uint8_t servoChannel2 = 15;

void setup() {
  Serial.begin(9600); // You can increase this baud rate for ESP32, e.g., 115200
  Serial.println("ESP32 PCA9685 Servo Test Initializing...");

  // Initialize I2C communication for ESP32
  Wire.begin(SDA_PIN, SCL_PIN);

  pwm.begin();
  /*
   * In theory the internal oscillator (clock) is 25MHz but it can vary slightly.
   * You can calibrate this setting to get more accurate PWM pulses.
   * This line changes the prescale value to match the desired frequency using a specific oscillator frequency.
   * 27000000 is a common value used for calibration if the default 25MHz is not precise.
   * If you have issues, you can try commenting this line out or using a different value.
   */
  pwm.setOscillatorFrequency(27000000); // Calibrate oscillator
  pwm.setPWMFreq(SERVO_FREQ);  // Set PWM frequency to 50Hz

  Serial.println("Initialization complete. PCA9685 Ready.");
  delay(10);
}

void setServoAngle(uint8_t channel, int angle) {
    // The map function translates 0-180 degrees to the SERVOMIN-SERVOMAX pulse range
  int pulse = map(angle, 0, 180, SERVOMIN, SERVOMAX);
  pwm.setPWM(channel, 0, pulse);
}

void loop() {
  // Set servos to 90 degrees
  Serial.print("Setting servo on channel ");
  Serial.print(servoChannel);
  Serial.println(" to 90 degrees");
  setServoAngle(servoChannel, 90);

  Serial.print("Setting servo on channel ");
  Serial.print(servoChannel2);
  Serial.println(" to 90 degrees");
  setServoAngle(servoChannel2, 90);
  delay(1000);

  // Set servos to 0 degrees
  Serial.print("Setting servo on channel ");
  Serial.print(servoChannel);
  Serial.println(" to 0 degrees");
  setServoAngle(servoChannel, 0);

  Serial.print("Setting servo on channel ");
  Serial.print(servoChannel2);
  Serial.println(" to 0 degrees");
  setServoAngle(servoChannel2, 0);
  delay(1000);
}
