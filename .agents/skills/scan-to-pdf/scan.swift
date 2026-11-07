import AppKit
import CoreImage
import CoreText
import Vision

let args = CommandLine.arguments
let input = CIImage(contentsOf: URL(fileURLWithPath: args[1]))!
let out = URL(fileURLWithPath: args[2])
let size = input.extent.size

// Detect page outline and flatten perspective.
let seg = VNDetectDocumentSegmentationRequest()
try VNImageRequestHandler(ciImage: input).perform([seg])
var page = input
if let quad = seg.results?.first {
    func pt(_ p: CGPoint) -> CIVector { CIVector(x: p.x * size.width, y: p.y * size.height) }
    page = input.applyingFilter("CIPerspectiveCorrection", parameters: [
        "inputTopLeft": pt(quad.topLeft), "inputTopRight": pt(quad.topRight),
        "inputBottomLeft": pt(quad.bottomLeft), "inputBottomRight": pt(quad.bottomRight),
    ])
}
page = page.applyingFilter("CIDocumentEnhancer", parameters: ["inputAmount": 1.0])
// Kill bleed-through (light grays -> white), darken ink.
page = page.applyingFilter("CIToneCurve", parameters: [
    "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 0.4, y: 0.12),
    "inputPoint2": CIVector(x: 0.62, y: 0.4), "inputPoint3": CIVector(x: 0.8, y: 1),
    "inputPoint4": CIVector(x: 1, y: 1),
])
let ctx = CIContext()
let cg = ctx.createCGImage(page, from: page.extent)!

// OCR for searchable text layer.
let ocr = VNRecognizeTextRequest()
ocr.recognitionLanguages = ["ja-JP", "en-US"]
ocr.recognitionLevel = .accurate
try VNImageRequestHandler(cgImage: cg).perform([ocr])

// A4 width, height follows page aspect.
let w: CGFloat = 595, h = w * CGFloat(cg.height) / CGFloat(cg.width)
var box = CGRect(x: 0, y: 0, width: w, height: h)
let pdf = CGContext(out as CFURL, mediaBox: &box, [kCGPDFContextCreator: "scan.swift"] as CFDictionary)!
pdf.beginPDFPage(nil)
// Quantize to 8 colors: white paper, black print, blue ink compress far better than JPEG.
let tmp = NSTemporaryDirectory() + "scan_page.png"
try NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: tmp))
let magick = Process()
magick.executableURL = URL(fileURLWithPath: "/usr/bin/env")
magick.arguments = ["magick", tmp, "-alpha", "off", "+dither", "-colors", "8", "-type", "Palette", tmp]
try magick.run(); magick.waitUntilExit()
let png = CGImage(pngDataProviderSource: CGDataProvider(filename: tmp)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
pdf.interpolationQuality = .high
pdf.draw(png, in: box)
pdf.setTextDrawingMode(.invisible)
for obs in ocr.results ?? [] {
    guard let text = obs.topCandidates(1).first?.string else { continue }
    let r = VNImageRectForNormalizedRect(obs.boundingBox, Int(w), Int(h))
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: CTFontCreateWithName("HiraginoSans-W3" as CFString, r.height, nil)]))
    let lw = CTLineGetTypographicBounds(line, nil, nil, nil)
    pdf.saveGState()
    pdf.translateBy(x: r.minX, y: r.minY)
    pdf.scaleBy(x: lw > 0 ? r.width / lw : 1, y: 1)
    pdf.textPosition = .zero
    CTLineDraw(line, pdf)
    pdf.restoreGState()
}
pdf.endPDFPage()
pdf.closePDF()
print("OCR lines:", ocr.results?.count ?? 0)
