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

	if cacheMinutes != -1,
		LocationDelegate.shared.lat == nil || LocationDelegate.shared.lon == nil
	{
		// live get failed, use cache, ignore stale cache data
		return getLatLon(cacheMinutes: -1)
	}

	// default to san fran
	let lat = LocationDelegate.shared.lat ?? 37.77472222222222
	let lon = LocationDelegate.shared.lon ?? -122.41822222222222
	UserDefaults.standard.set(lat, forKey: "lat")
	UserDefaults.standard.set(lon, forKey: "lon")
	UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "latLonTimestamp")

	return (lat, lon)
}

func findNextChangeTimestamp(wallpaper: Wallpaper, index: Int, lat: Double, lon: Double)
	-> Int
{
    var time = Date.now.addingTimeInterval(60)
    let isNorthernHemisphere = lat >= 0
    while
        wallpaper.findBestImageIndex(for: solarPosition(for: .init(latitude: lat, longitude: lon), at: time), isNorthernHemisphere: isNorthernHemisphere) == index,
        -time.timeIntervalSinceNow < 60 * 60 * 24
    {
        time = time.addingTimeInterval(60)
    }
    return Int(time.timeIntervalSince1970)
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
		log("lat lon: \(lat), \(lon)")
		let isNorthernHemisphere = lat >= 0

		// Read wallpaper plist from sourcePath
		let wallpaper = readPlist(path: sourcePath)
		let solarPosition = solarPosition(for: .init(latitude: lat, longitude: lon), at: .now)

		if let (image, idx) = wallpaper.findImage(
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
                    index: idx,
					lat: lat,
					lon: lon
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
