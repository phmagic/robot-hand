# Robot Hand

An iOS app that plays Rock Paper Scissors against a 3D-printed robot hand. The app uses the front camera with Core ML to classify hand gestures and Apple Vision for real-time hand tracking, then commands a servo-driven robotic hand over BLE to play its move.

Read more about the project on my blog: [https://www.phun.me/blog/robot-hand/](https://www.phun.me/blog/robot-hand/)

## Building the Robot Hand

The mechanical hand is based on the [InMoov hand](https://inmoov.fr/inmoov-hand/) -- an open-source 3D-printed robot design. Follow the instructions there to print and assemble the hand.

## Project Structure

- **iOS/** -- SwiftUI app with two modes:
  - **Play** -- Rock Paper Scissors game with hand detection, countdown, and automatic game loop
  - **Mimic** -- Real-time hand tracking that mirrors your finger movements onto the robot hand
  - **Program** -- Program a series of hand positions and have the programs loop or bounce to make the hand dance.
- **firmware/** -- Arduino/ESP32 firmware for BLE servo control
- **ML/** -- Create ML project for training the Rock Paper Scissors gesture classifier
