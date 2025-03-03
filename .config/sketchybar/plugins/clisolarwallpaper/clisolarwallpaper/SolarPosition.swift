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

// New precise solar position calculation using improved astronomical algorithms
public func solarPosition(
	for location: CLLocation, at time: Date, with calendar: Calendar = .current
) -> SolarPosition {
	// Calculate Julian Day
	let jd = time.timeIntervalSince1970 / 86400.0 + 2440587.5
	let T = (jd - 2451545.0) / 36525.0

	// Geometric Mean Longitude of the Sun
	let L0 = fmod(280.46646 + T * (36000.76983 + T * 0.0003032), 360.0)
	// Geometric Mean Anomaly
	let M = 357.52911 + T * (35999.05029 - 0.0001537 * T)

	let M_rad = radians(degrees: M)
	// Sun's equation of center
	let C =
		sin(M_rad) * (1.914602 - T * (0.004817 + 0.000014 * T))
		+ sin(2 * M_rad) * (0.019993 - 0.000101 * T)
		+ sin(3 * M_rad) * 0.000289
	// Sun True Longitude
	let trueLong = L0 + C

	// Sun Apparent Longitude
	let Omega = 125.04 - 1934.136 * T
	let lambda = trueLong - 0.00569 - 0.00478 * sin(radians(degrees: Omega))

	// Mean Obliquity of the Ecliptic and true obliquity
	var epsilon0 = 23.0 + (26.0 / 60.0) + (21.448 / 3600.0)
	epsilon0 -= T * (46.8150 + T * (0.00059 - T * 0.001813)) / 3600.0
	let epsilon = epsilon0 + 0.00256 * cos(radians(degrees: Omega))

	let lambda_rad = radians(degrees: lambda)
	let epsilon_rad = radians(degrees: epsilon)
	// Right Ascension
	var RA = degrees(radians: atan2(cos(epsilon_rad) * sin(lambda_rad), cos(lambda_rad)))
	RA = fmod(RA + 360.0, 360.0)
	// Declination
	let decl = degrees(radians: asin(sin(epsilon_rad) * sin(lambda_rad)))

	// Local Sidereal Time
	let longitude = location.coordinate.longitude
	let D = jd - 2451545.0
	let GMST = fmod(
		280.46061837 + 360.98564736629 * D + 0.000387933 * T * T - T * T * T / 38710000.0, 360.0)
	let LST = GMST + longitude
	// Hour angle in radians
	let HA = radians(degrees: fmod(LST - RA + 360.0, 360.0))

	// Convert latitude to radians
	let lat_rad = radians(degrees: location.coordinate.latitude)
	let decl_rad = radians(degrees: decl)

	// Elevation calculation
	let elevation_rad = asin(sin(lat_rad) * sin(decl_rad) + cos(lat_rad) * cos(decl_rad) * cos(HA))
	let elevation = degrees(radians: elevation_rad)

	// Apply atmospheric refraction correction (approximate)
	let refractionCorrection: Double
	if elevation > 85 {
		refractionCorrection = 0
	} else {
		refractionCorrection =
			1.02 / tan(radians(degrees: elevation + 10.3 / (elevation + 5))) / 60.0
	}
	let correctedElevation = elevation + refractionCorrection

	// Azimuth calculation (adjusted for quadrant)
	let azimuth_rad = acos(
		(sin(decl_rad) - sin(elevation_rad) * sin(lat_rad)) / (cos(elevation_rad) * cos(lat_rad)))
	var azimuth = degrees(radians: azimuth_rad)
	if sin(HA) > 0 {
		azimuth = 360 - azimuth
	}

	return (correctedElevation, azimuth)
}
