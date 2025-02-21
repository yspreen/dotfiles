/**
 * SolarPosition.swift
 * clisolarwallpaper
 *
 * Created by Nick Spreen (spreen.co) on 2/21/25.
 *
 */

import CoreLocation
import Foundation

func radians(degrees: CLLocationDegrees) -> Double {
	return .pi * degrees / 180.0
}

func degrees(radians: Double) -> CLLocationDegrees {
	return 180 * radians / .pi
}

public typealias SolarPosition = (elevation: CLLocationDegrees, azimuth: CLLocationDegrees)

public func solarPosition(
	for location: CLLocation,
	at time: Date,
	with calendar: Calendar = .current
) -> SolarPosition {
	let elapsedJulianDays = time.timeIntervalSince(.J2000) / numberOfSecondsPerDay

	let ω = 2.1429 - 0.0010394594 * elapsedJulianDays
	let meanLongitude = 4.8950630 + 0.017202791698 * elapsedJulianDays
	let meanAnomaly = 6.2400600 + 0.0172019699 * elapsedJulianDays

	let eclipticLongitude =
		meanLongitude + 0.03341607 * sin(meanAnomaly) + 0.00034894 * sin(2 * meanAnomaly)
		- 0.0001134 - 0.0000203 * sin(ω)

	let eclipticObliquity = 0.4090928 - 6.2140e-9 * elapsedJulianDays + 0.0000396 * cos(ω)

	var rightAscension = atan2(
		cos(eclipticObliquity) * sin(eclipticLongitude), cos(eclipticLongitude))
	if rightAscension < 0 {
		rightAscension += (2.0 * .pi)
	}

	let declination = asin(sin(eclipticObliquity) * sin(eclipticLongitude))

	let latitude = radians(degrees: location.coordinate.latitude)
	let longitude = radians(degrees: location.coordinate.longitude)

	let greenwichMeanSiderealTime =
		6.6974243242 + 0.0657098283 * elapsedJulianDays + calendar.fractionalHours(for: time)
	let localMeanSiderealTime = (greenwichMeanSiderealTime * 15 + longitude) * (.pi / 180.0)
	let hourAngle = localMeanSiderealTime - rightAscension

	let elevation = asin(
		cos(latitude) * cos(hourAngle) * cos(declination) + sin(declination) * sin(latitude))

	var azimuth = atan2(
		-sin(hourAngle), tan(declination) * cos(latitude) - sin(latitude) * cos(hourAngle))
	if azimuth < 0 {
		azimuth += (.pi * 2.0)
	}

	return (degrees(radians: elevation), degrees(radians: azimuth))
}

@available(macOS 13, *)
extension DateInterval {
	public func striding(by timeInterval: TimeInterval) -> StrideTo<Date> {
		return stride(from: self.start, to: self.end, by: timeInterval)
	}
}

// Equal to January 1, 2000, 11:58:55.816 UTC
let _J2000: Date = {
	let gregorian = Calendar(identifier: .gregorian)
	let utc = TimeZone(secondsFromGMT: 0)
	let dateComponents = DateComponents(
		calendar: gregorian,
		timeZone: utc,
		year: 2000,
		month: 1,
		day: 1,
		hour: 11,
		minute: 58,
		second: 55,
		nanosecond: 816_000_000)
	return gregorian.date(from: dateComponents)!
}()

extension Date {
	/// The J2000.0 epoch, 2000-01-01T12:00:00Z
	/// https://en.wikipedia.org/wiki/Epoch_(astronomy)#Julian_years_and_J2000
	public static var J2000: Date {
		return _J2000
	}
}

public let numberOfSecondsPerDay: TimeInterval = 60 * 60 * 24
let numberOfSecondsPerMinute: TimeInterval = 60
let numberOfSecondsPerHour: TimeInterval = numberOfSecondsPerMinute * 60

extension Calendar {
	public func fractionalHours(for date: Date) -> Double {
		let dateComponents = self.dateComponents([.hour, .minute, .second], from: date)

		let hours = dateComponents.hour ?? 0
		let minutes = dateComponents.minute ?? 0
		let seconds = dateComponents.second ?? 0
		return Double(hours) + Double(minutes) / numberOfSecondsPerMinute + Double(seconds)
			/ numberOfSecondsPerHour
	}
}
