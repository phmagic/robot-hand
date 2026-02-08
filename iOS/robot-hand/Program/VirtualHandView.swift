import SwiftUI

struct VirtualHandView: View {
    let positions: StoredFingerPositions

    private let fingerColors: [Color] = [
        .red,      // Thumb
        .orange,   // Index
        .yellow,   // Middle
        .green,    // Ring
        .blue      // Pinky
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) * 0.85
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2 + size * 0.05

            Canvas { context, canvasSize in
                let palmCenter = CGPoint(x: centerX, y: centerY)

                // Draw wrist base
                drawWrist(context: context, center: palmCenter, size: size)

                // Draw palm
                drawPalm(context: context, center: palmCenter, size: size)

                // Draw fingers
                let fingerConfigs: [(curl: Int, maxCurl: Int, baseOffsetX: CGFloat, baseAngle: Double, length: CGFloat, color: Color)] = [
                    (positions.thumb, 150, -0.18, -50, 0.22, fingerColors[0]),
                    (positions.index, 180, -0.08, -12, 0.32, fingerColors[1]),
                    (positions.middle, 180, 0.0, 0, 0.35, fingerColors[2]),
                    (positions.ring, 180, 0.08, 12, 0.32, fingerColors[3]),
                    (positions.pinky, 150, 0.15, 22, 0.26, fingerColors[4])
                ]

                for config in fingerConfigs {
                    drawFinger(
                        context: context,
                        palmCenter: palmCenter,
                        size: size,
                        curl: config.curl,
                        maxCurl: config.maxCurl,
                        baseOffsetX: config.baseOffsetX,
                        baseAngle: config.baseAngle,
                        length: config.length,
                        color: config.color
                    )
                }
            }

            // Position labels
            VStack {
                Spacer()
                HStack(spacing: 16) {
                    ForEach(fingerLabels, id: \.name) { label in
                        VStack(spacing: 2) {
                            Text(label.name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(label.value)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(label.color)
                        }
                    }
                    VStack(spacing: 2) {
                        Text("W")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(positions.wrist)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.purple)
                    }
                }
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 8)
            }
        }
    }

    private var fingerLabels: [(name: String, value: Int, color: Color)] {
        [
            ("T", positions.thumb, fingerColors[0]),
            ("I", positions.index, fingerColors[1]),
            ("M", positions.middle, fingerColors[2]),
            ("R", positions.ring, fingerColors[3]),
            ("P", positions.pinky, fingerColors[4])
        ]
    }

    private func drawWrist(context: GraphicsContext, center: CGPoint, size: CGFloat) {
        let wristY = center.y + size * 0.18
        let wristWidth = size * 0.22
        let wristHeight = size * 0.12

        // Wrist rectangle
        let wristRect = CGRect(
            x: center.x - wristWidth / 2,
            y: wristY,
            width: wristWidth,
            height: wristHeight
        )
        context.fill(
            Path(roundedRect: wristRect, cornerRadius: 4),
            with: .color(.gray.opacity(0.4))
        )

        // Wrist rotation indicator
        let indicatorCenter = CGPoint(x: center.x, y: wristY + wristHeight / 2)
        let wristAngle = Double(positions.wrist - 90) // 90 is center position
        let normalizedAngle = wristAngle / 90.0 // -1 to 1 range

        // Draw rotation arc
        let arcRadius = size * 0.06
        var arcPath = Path()
        if normalizedAngle != 0 {
            arcPath.addArc(
                center: indicatorCenter,
                radius: arcRadius,
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + wristAngle * 0.8),
                clockwise: wristAngle < 0
            )
            context.stroke(arcPath, with: .color(.purple), lineWidth: 3)
        }

        // Center dot
        let dotRect = CGRect(x: indicatorCenter.x - 3, y: indicatorCenter.y - 3, width: 6, height: 6)
        context.fill(Path(ellipseIn: dotRect), with: .color(.purple))
    }

    private func drawPalm(context: GraphicsContext, center: CGPoint, size: CGFloat) {
        let palmWidth = size * 0.28
        let palmHeight = size * 0.22

        let palmRect = CGRect(
            x: center.x - palmWidth / 2,
            y: center.y - palmHeight / 2,
            width: palmWidth,
            height: palmHeight
        )
        context.fill(
            Path(roundedRect: palmRect, cornerRadius: 10),
            with: .color(.gray.opacity(0.3))
        )
        context.stroke(
            Path(roundedRect: palmRect, cornerRadius: 10),
            with: .color(.gray.opacity(0.5)),
            lineWidth: 2
        )
    }

    private func drawFinger(
        context: GraphicsContext,
        palmCenter: CGPoint,
        size: CGFloat,
        curl: Int,
        maxCurl: Int,
        baseOffsetX: CGFloat,
        baseAngle: Double,
        length: CGFloat,
        color: Color
    ) {
        let curlFactor = Double(curl) / Double(maxCurl)
        let segmentLength = size * length / 3.0

        // Finger base position (on palm edge)
        let baseX = palmCenter.x + size * baseOffsetX
        let baseY = palmCenter.y - size * 0.11

        // Calculate curl - higher servo value = more curl
        let curlAnglePerSegment = curlFactor * 35.0

        var path = Path()
        path.move(to: CGPoint(x: baseX, y: baseY))

        var currentPoint = CGPoint(x: baseX, y: baseY)
        var currentAngle = -90.0 + baseAngle * 0.4  // Start pointing up with slight spread

        var jointPoints: [CGPoint] = [currentPoint]

        for _ in 0..<3 {
            currentAngle += curlAnglePerSegment
            let nextX = currentPoint.x + cos(Angle.degrees(currentAngle).radians) * segmentLength
            let nextY = currentPoint.y + sin(Angle.degrees(currentAngle).radians) * segmentLength
            let nextPoint = CGPoint(x: nextX, y: nextY)

            path.addLine(to: nextPoint)
            jointPoints.append(nextPoint)
            currentPoint = nextPoint
        }

        // Draw finger line
        context.stroke(path, with: .color(color), lineWidth: 4)

        // Draw joints
        for point in jointPoints {
            let jointRect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: jointRect), with: .color(color))
            context.stroke(Path(ellipseIn: jointRect), with: .color(.white.opacity(0.5)), lineWidth: 1)
        }
    }
}

#Preview {
    VirtualHandView(positions: StoredFingerPositions(
        thumb: 75,
        index: 90,
        middle: 45,
        ring: 120,
        pinky: 60,
        wrist: 110
    ))
    .frame(width: 400, height: 400)
    .background(Color(.secondarySystemBackground))
}
