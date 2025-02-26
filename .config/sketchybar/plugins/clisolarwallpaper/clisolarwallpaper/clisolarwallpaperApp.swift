/**
 * clisolarwallpaperApp.swift
 * clisolarwallpaper
 *
 * Created by Nick Spreen (spreen.co) on 2/21/25.
 *
 */

import Cocoa
import CoreLocation
import Foundation

class LocationDelegate: NSObject, CLLocationManagerDelegate {
	static let shared = LocationDelegate()
	var lat: Double?
	var lon: Double?

	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		self.lat = locations[0].coordinate.latitude
		self.lon = locations[0].coordinate.longitude
	}
}

func log(_ message: String) {
	// Write all logs to stderr
	FileHandle.standardError.write(Data((message + "\n").utf8))
}

func getLatLon(cacheMinutes: Int = 0) -> (Double, Double) {
	if cacheMinutes != 0 {
		let lastTimestamp = UserDefaults.standard.double(forKey: "latLonTimestamp")
		if cacheMinutes == -1
			|| Date.now.timeIntervalSince1970 - lastTimestamp < 60 * Double(cacheMinutes)
		{
			log("Cache hit")
			return (
				UserDefaults.standard.double(forKey: "lat"),
				UserDefaults.standard.double(forKey: "lon")
			)
		}
	}

	// Location Setup
	let manager = CLLocationManager()
	manager.delegate = LocationDelegate.shared
	manager.requestWhenInUseAuthorization()
	manager.startUpdatingLocation()
	let start = Date.now
	while LocationDelegate.shared.lat == nil {
		RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
		if Date.now.timeIntervalSince(start) > 5 {
			break
		}
	}
	// default to san fran
	let lat = LocationDelegate.shared.lat ?? 37.77472222222222
	let lon = LocationDelegate.shared.lon ?? -122.41822222222222
	UserDefaults.standard.set(lat, forKey: "lat")
	UserDefaults.standard.set(lon, forKey: "lon")
	UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "latLonTimestamp")

	return (lat, lon)
}

func findNextChangeTimestamp(wallpaper: Wallpaper, lat: Double, lon: Double, currentTime: Date)
	-> Int
{
	let location = CLLocation(latitude: lat, longitude: lon)
	let isNorthernHemisphere = lat >= 0

	// Get current image index
	let currentPosition = solarPosition(for: location, at: currentTime)
	let currentImage = wallpaper.findBestImageIndex(
		for: currentPosition, isNorthernHemisphere: isNorthernHemisphere)

	// Step 1: Find the hour when change occurs (using 30 minute steps)
	var checkTime = currentTime
	let thirtyMinutes: TimeInterval = 30 * 60
	var lastImage = currentImage
	var changeHourTime: Date?

	// Look up to 24 hours ahead with 30-minute intervals
	for _ in 0..<48 {
		checkTime = checkTime.addingTimeInterval(thirtyMinutes)
		let checkPosition = solarPosition(for: location, at: checkTime)
		let nextImage = wallpaper.findBestImageIndex(
			for: checkPosition, isNorthernHemisphere: isNorthernHemisphere)

		if nextImage != lastImage {
			changeHourTime = checkTime.addingTimeInterval(-thirtyMinutes)  // Go back to the previous 30-min mark
			break
		}

		lastImage = nextImage
	}

	// If no change detected in 24 hours, return tomorrow at this time as a fallback
	guard let hourChangeTime = changeHourTime else {
		return Int(currentTime.timeIntervalSince1970) + (24 * 60 * 60)
	}

	// Step 2: Find the minute when change occurs (using 1 minute steps)
	checkTime = hourChangeTime
	lastImage = currentImage
	var changeMinuteTime: Date?
	let oneMinute: TimeInterval = 60

	// Search within a one-hour window with 1-minute intervals
	for _ in 0..<60 {
		checkTime = checkTime.addingTimeInterval(oneMinute)
		let checkPosition = solarPosition(for: location, at: checkTime)
		let nextImage = wallpaper.findBestImageIndex(
			for: checkPosition, isNorthernHemisphere: isNorthernHemisphere)

		if nextImage != lastImage {
			changeMinuteTime = checkTime.addingTimeInterval(-oneMinute)  // Go back to the previous minute
			break
		}

		lastImage = nextImage
	}

	guard let minuteChangeTime = changeMinuteTime else {
		// If no change found at the minute level, use the hour we found + 60 min
		return Int(ceil(hourChangeTime.timeIntervalSince1970 + 60 * 60))
	}

	// Step 3: Find the exact second when change occurs
	checkTime = minuteChangeTime
	lastImage = currentImage
	let oneSecond: TimeInterval = 1

	// Search within a one-minute window with 1-second intervals
	for _ in 0..<60 {
		checkTime = checkTime.addingTimeInterval(oneSecond)
		let checkPosition = solarPosition(for: location, at: checkTime)
		let nextImage = wallpaper.findBestImageIndex(
			for: checkPosition, isNorthernHemisphere: isNorthernHemisphere)

		if nextImage != lastImage {
			log("Found the exact second")
			// Found the exact second of change, return the timestamp
			return Int(ceil(checkTime.timeIntervalSince1970))
		}

		lastImage = nextImage
	}

	// If we couldn't find the exact second, use the minute we found + 60 sec
	return Int(ceil(minuteChangeTime.timeIntervalSince1970 + 60))
}

@main
struct clisolarwallpaperApp {
	static func main() {
		// CLI Argument Parsing
		let args = CommandLine.arguments
		guard args.count >= 2 else {
			log("Usage: \(args[0]) <sourceImagePath> [destinationPath] [cacheMinutes]")
			exit(1)
		}
		var sourcePath = args[1]
		var destinationPath = args.count > 2 ? args[2] : "/tmp/img.jpg"
		var cacheMinutes = args.count > 3 ? (Int(args[3]) ?? 60) : 60

		if sourcePath == "-NSDocumentRevisionsDebugMode" {
			// running in xcode
			sourcePath =
				"\(NSHomeDirectory())/Library/Application Support/com.apple.mobileAssetDesktop/Solar Gradients.heic"
			destinationPath = "/tmp/img.jpg"
			cacheMinutes = 60
		}

		log("Source: \(sourcePath)")
		log("Destination: \(destinationPath)")
		log("Cache Minutes: \(cacheMinutes)")

		let (lat, lon) = getLatLon(cacheMinutes: cacheMinutes)
		let isNorthernHemisphere = lat >= 0

		// Read wallpaper plist from sourcePath
		let wallpaper = readPlist(path: sourcePath)
		let solarPosition = solarPosition(for: .init(latitude: lat, longitude: lon), at: .now)

		if let image = wallpaper.findImage(
			for: solarPosition, isNorthernHemisphere: isNorthernHemisphere)
		{
			// For demonstration, write image to destinationPath
			if let tiffData = image.tiffRepresentation,
				let bitmap = NSBitmapImageRep(data: tiffData),
				let jpgData = bitmap.representation(using: .jpeg, properties: [:])
			{
				try? jpgData.write(to: URL(fileURLWithPath: destinationPath))
				log("Wrote image to: \(destinationPath)")

				// Calculate the next change time
				let nextChangeTimestamp = findNextChangeTimestamp(
					wallpaper: wallpaper,
					lat: lat,
					lon: lon,
					currentTime: .now
				)

				// Print only the timestamp to stdout
				print("\(nextChangeTimestamp)")
			}
		} else {
			log("No image found for the current solar position.")
			// Output fallback timestamp (1 hour from now)
			let fallbackTimestamp = Int(Date.now.timeIntervalSince1970) + 3600
			print("\(fallbackTimestamp)")
		}
	}
}
