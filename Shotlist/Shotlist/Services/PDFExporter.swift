import Foundation
import UIKit

enum PDFExporter {
    static func generatePDF(for project: ShotListProject, routePlan: RoutePlan?) -> Data? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - (margin * 2)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            var y = margin

            func newPageIfNeeded(_ needed: CGFloat) {
                if y + needed > pageHeight - margin {
                    context.beginPage()
                    y = margin
                }
            }

            func drawWrapped(_ text: String, font: UIFont, color: UIColor = .black, spacingAfter: CGFloat = 8) {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph,
                ]
                let attributed = NSAttributedString(string: text, attributes: attrs)
                let bounding = attributed.boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let height = ceil(bounding.height)
                newPageIfNeeded(height + spacingAfter)
                attributed.draw(with: CGRect(x: margin, y: y, width: contentWidth, height: height), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                y += height + spacingAfter
            }

            context.beginPage()
            drawWrapped(project.title, font: .boldSystemFont(ofSize: 20), spacingAfter: 12)

            if !project.brief.isEmpty {
                drawWrapped(project.brief, font: .systemFont(ofSize: 11), color: .darkGray, spacingAfter: 14)
            }

            drawWrapped(
                "Progress: \(project.completedCount)/\(project.totalCount) shots",
                font: .systemFont(ofSize: 12),
                spacingAfter: 10
            )

            if let routePlan {
                drawWrapped(
                    "Route: \(routePlan.totalHoursFormatted) total (\(routePlan.totalWalkMinutes)m walk + \(routePlan.totalShootMinutes)m shoot)",
                    font: .boldSystemFont(ofSize: 12),
                    spacingAfter: 8
                )
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                for stop in routePlan.stops {
                    let arrival = stop.estimatedArrival.map { formatter.string(from: $0) } ?? "—"
                    let prefix = stop.location.isUnmapped ? "⚠︎ " : ""
                    drawWrapped(
                        "\(stop.order). \(prefix)\(stop.location.name) — \(stop.shootMinutes)m shoot, +\(stop.walkMinutesFromPrevious)m walk · arrive \(arrival)",
                        font: .systemFont(ofSize: 11),
                        spacingAfter: 4
                    )
                }
                y += 8
            }

            for category in project.categories.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                drawWrapped(category.name, font: .boldSystemFont(ofSize: 14), spacingAfter: 8)

                for shot in project.shots(in: category) {
                    let check = shot.isCompleted ? "☑" : "☐"
                    let size = shot.shotSize == .unknown ? "" : " [\(shot.shotSize.rawValue)]"
                    let angle = shot.cameraAngle == .unknown ? "" : " · \(shot.cameraAngle.rawValue)"
                    let location: String
                    if let key = shot.locationKey, let loc = ShootLocation.lookup(key: key) {
                        location = loc.isUnmapped ? " · needs location" : " · \(loc.name)"
                    } else {
                        location = ""
                    }
                    let variant = shot.isVariant ? "  ↳ " : ""
                    var line = "\(variant)\(check) \(shot.title)\(size)\(angle)\(location)"
                    if !shot.notes.isEmpty {
                        line += " — \(shot.notes)"
                    }
                    drawWrapped(line, font: .systemFont(ofSize: 10), spacingAfter: 4)
                }
                y += 6
            }
        }
    }

    static func writeTemporaryPDF(_ data: Data, projectTitle: String) -> URL? {
        let safeTitle = projectTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = String(safeTitle.prefix(40)).isEmpty ? "Shotlist" : String(safeTitle.prefix(40))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let name = "\(trimmed)-\(formatter.string(from: Date())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
