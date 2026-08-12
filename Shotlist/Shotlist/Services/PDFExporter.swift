import Foundation
import UIKit

enum PDFExporter {
    static func generatePDF(for project: ShotListProject, routePlan: RoutePlan?) -> Data? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            var y = margin

            func newPageIfNeeded(_ needed: CGFloat) {
                if y + needed > pageHeight - margin {
                    context.beginPage()
                    y = margin
                }
            }

            func drawLine(_ text: String, font: UIFont, spacing: CGFloat = 18) {
                newPageIfNeeded(spacing)
                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                text.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
                y += spacing
            }

            context.beginPage()
            drawLine(project.title, font: .boldSystemFont(ofSize: 20), spacing: 28)

            if !project.brief.isEmpty {
                drawLine(project.brief, font: .systemFont(ofSize: 11), spacing: 32)
            }

            drawLine("Progress: \(project.completedCount)/\(project.totalCount) shots", font: .systemFont(ofSize: 12))

            if let routePlan {
                drawLine("Route: \(routePlan.totalHoursFormatted) total (\(routePlan.totalWalkMinutes)m walk + \(routePlan.totalShootMinutes)m shoot)", font: .boldSystemFont(ofSize: 12), spacing: 22)
                for stop in routePlan.stops {
                    newPageIfNeeded(20)
                    drawLine("\(stop.order). \(stop.location.name) — \(stop.shootMinutes)m shoot, +\(stop.walkMinutesFromPrevious)m walk", font: .systemFont(ofSize: 11))
                }
                y += 8
            }

            for category in project.categories.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                newPageIfNeeded(24)
                drawLine(category.name, font: .boldSystemFont(ofSize: 14), spacing: 22)

                for shot in project.shots(in: category) {
                    let check = shot.isCompleted ? "☑" : "☐"
                    let size = shot.shotSize == .unknown ? "" : " [\(shot.shotSize.rawValue)]"
                    let angle = shot.cameraAngle == .unknown ? "" : " · \(shot.cameraAngle.rawValue)"
                    let variant = shot.isVariant ? "  ↳ " : ""
                    drawLine("\(variant)\(check) \(shot.title)\(size)\(angle)", font: .systemFont(ofSize: 10), spacing: 14)
                }
            }
        }
    }
}
