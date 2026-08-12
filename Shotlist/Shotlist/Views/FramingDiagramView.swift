import SwiftUI

struct FramingDiagramView: View {
    let suggestion: FramingSuggestion
    var aspectRatio: AspectRatio = .sixteenByNine

    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let containerHeight = geometry.size.height
            let frameSize = fittedFrameSize(in: geometry.size)

            ZStack {
                Color.black.opacity(0.15)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: backgroundColors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    gridAndOverlays(width: frameSize.width, height: frameSize.height)
                }
                .frame(width: frameSize.width, height: frameSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                )

                VStack {
                    HStack {
                        Label(suggestion.framingStyle.displayName, systemImage: "camera.viewfinder")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                        Text(aspectRatio.rawValue)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Spacer()
                    HStack {
                        Text(suggestion.effectiveFocalLength)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                        Text(suggestion.aperture)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(12)
                .frame(width: containerWidth, height: containerHeight)
                .foregroundStyle(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func fittedFrameSize(in container: CGSize) -> CGSize {
        let targetRatio = aspectRatio.widthRatio / aspectRatio.heightRatio
        let containerRatio = container.width / container.height
        if containerRatio > targetRatio {
            let height = container.height * 0.85
            return CGSize(width: height * targetRatio, height: height)
        }
        let width = container.width * 0.92
        return CGSize(width: width, height: width / targetRatio)
    }

    @ViewBuilder
    private func gridAndOverlays(width: CGFloat, height: CGFloat) -> some View {
        let size = CGSize(width: width, height: height)
        ZStack {
            Path { path in
                let thirdW = width / 3
                let thirdH = height / 3
                path.move(to: CGPoint(x: thirdW, y: 0))
                path.addLine(to: CGPoint(x: thirdW, y: height))
                path.move(to: CGPoint(x: thirdW * 2, y: 0))
                path.addLine(to: CGPoint(x: thirdW * 2, y: height))
                path.move(to: CGPoint(x: 0, y: thirdH))
                path.addLine(to: CGPoint(x: width, y: thirdH))
                path.move(to: CGPoint(x: 0, y: thirdH * 2))
                path.addLine(to: CGPoint(x: width, y: thirdH * 2))
            }
            .stroke(.white.opacity(0.25), lineWidth: 1)

            horizonLine(in: size)
            subjectMarker(in: size)
            framingOverlay(in: size)
        }
    }

    private var backgroundColors: [Color] {
        switch suggestion.framingStyle {
        case .wide:
            return [Color(red: 0.15, green: 0.22, blue: 0.35), Color(red: 0.35, green: 0.42, blue: 0.55)]
        case .medium:
            return [Color(red: 0.2, green: 0.25, blue: 0.3), Color(red: 0.4, green: 0.38, blue: 0.35)]
        case .tight:
            return [Color(red: 0.25, green: 0.2, blue: 0.22), Color(red: 0.45, green: 0.35, blue: 0.32)]
        case .detail:
            return [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.28, green: 0.26, blue: 0.24)]
        }
    }

    @ViewBuilder
    private func horizonLine(in size: CGSize) -> some View {
        if suggestion.horizonPlacement != .none {
            let y: CGFloat = switch suggestion.horizonPlacement {
            case .low: size.height * 0.66
            case .center: size.height * 0.5
            case .high: size.height * 0.33
            case .none: size.height * 0.5
            }
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(width: size.width, height: 2)
                .position(x: size.width / 2, y: y)
        }
    }

    @ViewBuilder
    private func subjectMarker(in size: CGSize) -> some View {
        let point = subjectPoint(in: size)
        ZStack {
            Circle()
                .stroke(.orange, lineWidth: 2)
                .frame(width: markerSize, height: markerSize)
            Circle()
                .fill(.orange.opacity(0.35))
                .frame(width: markerSize * 0.55, height: markerSize * 0.55)
        }
        .position(point)
    }

    @ViewBuilder
    private func framingOverlay(in size: CGSize) -> some View {
        switch suggestion.framingStyle {
        case .wide:
            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: size.width * 0.85, height: size.height * 0.7)
        case .medium:
            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.5), lineWidth: 2)
                .frame(width: size.width * 0.55, height: size.height * 0.5)
        case .tight:
            RoundedRectangle(cornerRadius: 4)
                .stroke(.orange.opacity(0.8), lineWidth: 2)
                .frame(width: size.width * 0.35, height: size.height * 0.4)
        case .detail:
            RoundedRectangle(cornerRadius: 2)
                .stroke(.orange, lineWidth: 3)
                .frame(width: size.width * 0.25, height: size.height * 0.3)
        }
    }

    private var markerSize: CGFloat {
        switch suggestion.framingStyle {
        case .wide: return 44
        case .medium: return 36
        case .tight: return 28
        case .detail: return 22
        }
    }

    private func subjectPoint(in size: CGSize) -> CGPoint {
        let thirdW = size.width / 3
        let thirdH = size.height / 3
        switch suggestion.subjectPlacement {
        case .center:
            return CGPoint(x: size.width / 2, y: size.height / 2)
        case .ruleOfThirdsLeft:
            return CGPoint(x: thirdW, y: thirdH * 2)
        case .ruleOfThirdsRight:
            return CGPoint(x: thirdW * 2, y: thirdH * 2)
        case .foregroundLeft:
            return CGPoint(x: thirdW * 0.7, y: thirdH * 2.3)
        case .foregroundRight:
            return CGPoint(x: thirdW * 2.3, y: thirdH * 2.3)
        case .leadingLines:
            return CGPoint(x: thirdW * 1.5, y: thirdH * 1.8)
        }
    }
}

#Preview {
    FramingDiagramView(
        suggestion: FramingGenerator.suggest(
            for: Shot(title: "Töölöntori drone ylhäältä", categoryID: UUID()),
            settings: .default
        ),
        aspectRatio: .sixteenByNine
    )
    .frame(height: 220)
    .padding()
}
