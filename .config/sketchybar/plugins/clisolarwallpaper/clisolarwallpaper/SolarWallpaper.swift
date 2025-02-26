/**
 * SolarWallpaper.swift
 * clisolarwallpaper
 *
 * Created by Nick Spreen (spreen.co) on 2/21/25.
 *
 */

import AVFoundation
import AppKit
import CoreGraphics
import Foundation

extension NSImage {
	public var cgImage: CGImage? {
		guard let imageData = self.tiffRepresentation,
			let sourceData = CGImageSourceCreateWithData(imageData as CFData, nil)
		else {
			return nil
		}

		return CGImageSourceCreateImageAtIndex(sourceData, 0, nil)
	}
}

struct Wallpaper: Codable {
	struct Image: Codable {
		let altitude: Double
		let index: Int
		let azimuth: Double

		private enum CodingKeys: String, CodingKey {
			case altitude = "a"
			case index = "i"
			case azimuth = "z"
		}
	}

	struct LightDark: Codable {
		let dark: Int
		let light: Int

		private enum CodingKeys: String, CodingKey {
			case dark = "d"
			case light = "l"
		}
	}

	let lightDark: LightDark?
	let images: [Image]
	var url: URL!

	private enum CodingKeys: String, CodingKey {
		case lightDark = "ap"
		case images = "si"
	}

	func findBestImageIndex(for position: SolarPosition, isNorthernHemisphere: Bool) -> Int {
		// Sort images by altitude
		let sortedImages = images.sorted { $0.altitude < $1.altitude }
		// Determine if sun is rising
		let isRising: Bool =
			isNorthernHemisphere ? (position.azimuth <= 180.0) : (position.azimuth > 180.0)
		// Use rising or falling order based on solar azimuth
		let phaseImages = isRising ? sortedImages : sortedImages.reversed()
		// Select the image with altitude closest to the sun's elevation
		guard
			let bestItem = phaseImages.min(by: {
				abs(Double($0.altitude) - position.elevation)
					< abs(Double($1.altitude) - position.elevation)
			})
		else {
			return 0
		}
		return bestItem.index
	}

	func findImage(for position: SolarPosition, isNorthernHemisphere: Bool) -> NSImage? {
		// Find the best image index using the existing method
		let index = findBestImageIndex(for: position, isNorthernHemisphere: isNorthernHemisphere)

		// Create an image source from the heic container at self.url
		guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
			let cgimg = CGImageSourceCreateImageAtIndex(imageSource, index, nil)
		else {
			return nil
		}
		return NSImage(cgImage: cgimg, size: NSZeroSize)
	}

	func with(url: URL) -> Self {
		var image = self
		image.url = url
		return image
	}
}

func readPlist(path: String) -> Wallpaper {
	let url = URL(fileURLWithPath: path)
	let source = CGImageSourceCreateWithURL(url as CFURL, nil)!

	let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil)!
	let tags = CGImageMetadataCopyTags(metadata) as! [CGImageMetadataTag]
	for tag in tags {
		guard let name = CGImageMetadataTagCopyName(tag) as? String,
			let value = CGImageMetadataTagCopyValue(tag) as? String
		else {
			continue
		}

		if name.hasSuffix("solar") {
			let data = Data(base64Encoded: value)!
			let propertyList =
				try! PropertyListSerialization.propertyList(
					from: data, options: [], format: nil
				) as! [String: Any]

			// Convert property list to JSON data
			let jsonData = try! JSONSerialization.data(withJSONObject: propertyList)
			// Decode JSON into Wallpaper struct
			let wallpaper = try! JSONDecoder().decode(Wallpaper.self, from: jsonData)

			return wallpaper.with(url: url)
		}
	}

	fatalError("No solar data found!")
}
