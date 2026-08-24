import CoreLocation
import Foundation
import Observation

struct DemoLocation: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    var coordinateDescription: String {
        "\(latitude.formatted(.number.precision(.fractionLength(3)))), \(longitude.formatted(.number.precision(.fractionLength(3))))"
    }
}

/// A small, reusable one-shot location provider for demo features that need coordinates.
/// It requests permission only in response to a user action and never continuously tracks.
@MainActor
@Observable
final class DemoLocationProvider: NSObject, CLLocationManagerDelegate {
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var location: DemoLocation?
    private(set) var isRequesting = false
    private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private var requestAfterAuthorization = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var authorizationDescription: String {
        switch authorizationStatus {
        case .notDetermined: "Location access has not been requested"
        case .restricted: "Location access is restricted"
        case .denied: "Location access is turned off"
        case .authorizedAlways, .authorizedWhenInUse: location == nil ? "Ready to find your location" : "Using your current location"
        @unknown default: "Location status is unavailable"
        }
    }

    var requiresSettings: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func requestCurrentLocation() {
        errorMessage = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            requestAfterAuthorization = true
            isRequesting = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestOneLocation()
        case .denied:
            isRequesting = false
            errorMessage = "Allow location access in Settings, or enter coordinates manually."
        case .restricted:
            isRequesting = false
            errorMessage = "Location access is restricted on this device. Enter coordinates manually."
        @unknown default:
            isRequesting = false
            errorMessage = "Location is unavailable. Enter coordinates manually."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        guard requestAfterAuthorization else { return }
        requestAfterAuthorization = false

        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            requestOneLocation()
        } else {
            isRequesting = false
            if authorizationStatus == .denied {
                errorMessage = "Allow location access in Settings, or enter coordinates manually."
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            didFinishWithError("Your current location could not be determined. Enter coordinates manually.")
            return
        }

        location = DemoLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        isRequesting = false
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        didFinishWithError("Your current location could not be determined. Enter coordinates manually.")
    }

    private func requestOneLocation() {
        isRequesting = true
        manager.requestLocation()
    }

    private func didFinishWithError(_ message: String) {
        isRequesting = false
        errorMessage = message
    }
}
