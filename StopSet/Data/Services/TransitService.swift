import Foundation
import MapKit

enum TransitError: LocalizedError {
    case invalidResponse
    case apiKeyRejected
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The transport service returned data StopSet could not read."
        case .apiKeyRejected: "AT rejected this API key. Check that it is active and subscribed to the Realtime and GTFS APIs."
        case .serviceUnavailable: "The transport service is unavailable right now. Try again shortly."
        }
    }
}

struct TransitService {
    private let arcGIS = "https://services2.arcgis.com/JkPEgZJGxhSjYOo0/arcgis/rest/services/BusService/FeatureServer"

    func nearbyStops(at coordinate: CLLocationCoordinate2D) async throws -> [BusStop] {
        let data = try await arcGISQuery(layer: 0, coordinate: coordinate, distance: 650,
                                         fields: "STOPID,STOPCODE,STOPNAME,STOPLAT,STOPLON,MODE")
        return try decodeStops(data)
            .sorted { CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) <
                CLLocation(latitude: $1.latitude, longitude: $1.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) }
    }

    func stops(numberPrefix: String) async throws -> [BusStop] {
        guard !numberPrefix.isEmpty, numberPrefix.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return [] }
        var results: [BusStop] = []
        var offset = 0
        while true {
            try Task.checkCancellation()
            let data = try await arcGISQuery(layer: 0,
                                             fields: "STOPID,STOPCODE,STOPNAME,STOPLAT,STOPLON,MODE",
                                             whereClause: "CAST(STOPCODE AS VARCHAR(10)) LIKE '\(numberPrefix)%' AND MODE='Bus'",
                                             offset: offset, orderBy: "STOPCODE,STOPID")
            results += try decodeStops(data)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = object["features"] as? [[String: Any]] else { throw TransitError.invalidResponse }
            if object["exceededTransferLimit"] as? Bool != true { return results }
            guard !features.isEmpty else { throw TransitError.invalidResponse }
            offset += features.count
        }
    }

    func nearbyRoutes(at coordinate: CLLocationCoordinate2D) async throws -> [String] {
        let data = try await arcGISQuery(layer: 2, coordinate: coordinate, distance: 25,
                                         fields: "ROUTENUMBER,MODE", distinct: true)
        let features = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["features"] as? [[String: Any]] ?? []
        return Array(Set(features.compactMap { feature -> String? in
            guard let attributes = feature["attributes"] as? [String: Any],
                  (attributes["MODE"] as? String ?? "").lowercased().contains("bus"),
                  let number = attributes["ROUTENUMBER"] as? String else { return nil }
            return number
        })).sorted()
    }

    func departures(for stops: [BusStop], key: String) async throws -> [Departure] {
        async let schedulesRequest = scheduledTrips(for: stops, key: key)
        async let liveRequest = liveUpdates(for: stops, key: key)
        async let routeNamesRequest = routeNames(key: key)
        let schedules = try await schedulesRequest
        let live = (try? await liveRequest) ?? LiveUpdates()
        let names = (try? await routeNamesRequest) ?? [:]
        let now = Date()
        return schedules.compactMap { trip -> Departure? in
            let prediction = live.exact[trip.id] ?? live.estimate(for: trip)
            let date = prediction?.date ?? trip.scheduledDate
            guard date >= now.addingTimeInterval(-60), date <= now.addingTimeInterval(7200) else { return nil }
            return Departure(id: trip.id, route: names[trip.routeID] ?? trip.routeID,
                             destination: trip.destination, stop: trip.stop,
                             scheduledDate: trip.scheduledDate, predictedDate: prediction?.date,
                             tripID: trip.tripID, vehicleID: prediction?.vehicleID)
        }.sorted { $0.date < $1.date }
    }

    func vehicleLocation(tripID: String, vehicleID: String?, key: String) async throws -> VehicleLocation? {
        let data = try await authenticatedData(path: "/realtime/legacy/vehiclelocations", key: key)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw TransitError.invalidResponse }
        let feed = root["response"] as? [String: Any] ?? root
        guard let entities = feed["entity"] as? [[String: Any]] else { throw TransitError.invalidResponse }
        for entity in entities {
            guard let vehicle = entity["vehicle"] as? [String: Any],
                  let trip = vehicle["trip"] as? [String: Any],
                  trip["trip_id"] as? String == tripID,
                  vehicleID == nil || (vehicle["vehicle"] as? [String: Any])?["id"] as? String == vehicleID,
                  let position = vehicle["position"] as? [String: Any],
                  let lat = Self.number(position["latitude"]),
                  let lon = Self.number(position["longitude"]) else { continue }
            let timestamp = Self.number(vehicle["timestamp"]).map(Date.init(timeIntervalSince1970:))
            return VehicleLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), timestamp: timestamp)
        }
        return nil
    }

    private func decodeStops(_ data: Data) throws -> [BusStop] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = object["features"] as? [[String: Any]] else { throw TransitError.invalidResponse }
        return features.compactMap { feature -> BusStop? in
            guard let attributes = feature["attributes"] as? [String: Any],
                  let id = attributes["STOPID"] as? String,
                  let name = attributes["STOPNAME"] as? String,
                  let lat = attributes["STOPLAT"] as? Double,
                  let lon = attributes["STOPLON"] as? Double else { return nil }
            let mode = (attributes["MODE"] as? String ?? "").lowercased()
            guard mode.contains("bus") else { return nil }
            let code = (attributes["STOPCODE"] as? NSNumber)?.stringValue ?? id
            return BusStop(id: id, code: code, name: name, latitude: lat, longitude: lon)
        }
    }

    private func arcGISQuery(layer: Int, coordinate: CLLocationCoordinate2D? = nil, distance: Int? = nil,
                             fields: String, distinct: Bool = false, whereClause: String = "1=1",
                             offset: Int? = nil, orderBy: String? = nil) async throws -> Data {
        var components = URLComponents(string: "\(arcGIS)/\(layer)/query")!
        components.queryItems = [
            URLQueryItem(name: "where", value: whereClause),
            URLQueryItem(name: "outFields", value: fields),
            URLQueryItem(name: "returnGeometry", value: "false"),
            URLQueryItem(name: "returnDistinctValues", value: distinct ? "true" : "false"),
            URLQueryItem(name: "resultRecordCount", value: "200"),
            URLQueryItem(name: "f", value: "json")
        ]
        if let offset { components.queryItems!.append(URLQueryItem(name: "resultOffset", value: String(offset))) }
        if let orderBy { components.queryItems!.append(URLQueryItem(name: "orderByFields", value: orderBy)) }
        if let coordinate, let distance {
            components.queryItems! += [
                URLQueryItem(name: "geometry", value: "\(coordinate.longitude),\(coordinate.latitude)"),
                URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
                URLQueryItem(name: "inSR", value: "4326"),
                URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
                URLQueryItem(name: "distance", value: String(distance)),
                URLQueryItem(name: "units", value: "esriSRUnit_Meter")
            ]
        }
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw TransitError.serviceUnavailable }
        if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], object["error"] != nil {
            throw TransitError.invalidResponse
        }
        return data
    }

    private func scheduledTrips(for stops: [BusStop], key: String) async throws -> [ScheduledTrip] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        let hourStart = calendar.dateInterval(of: .hour, for: .now)!.start
        let requests = stops.flatMap { stop in
            (0...2).compactMap { offset -> (BusStop, Date)? in
                guard let date = calendar.date(byAdding: .hour, value: offset, to: hourStart) else { return nil }
                return (stop, date)
            }
        }
        var successfulRequests = 0
        var allTrips: [ScheduledTrip] = []
        await withTaskGroup(of: [ScheduledTrip]?.self) { group in
            for (stop, hour) in requests {
                group.addTask { try? await stopTrips(at: stop, hour: hour, key: key) }
            }
            for await trips in group {
                if let trips {
                    successfulRequests += 1
                    allTrips.append(contentsOf: trips)
                }
            }
        }
        guard successfulRequests > 0 else { throw TransitError.serviceUnavailable }
        return Array(Dictionary(allTrips.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values)
    }

    private func stopTrips(at stop: BusStop, hour: Date, key: String) async throws -> [ScheduledTrip] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        let date = DateFormatter()
        date.timeZone = calendar.timeZone
        date.dateFormat = "yyyy-MM-dd"
        let serviceDate = date.string(from: hour)
        let serviceHour = String(calendar.component(.hour, from: hour))
        let cacheKey = "\(stop.id)|\(serviceDate)|\(serviceHour)"
        if let cached = await StopTripsCache.shared.get(cacheKey) { return cached }
        let encodedID = stop.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? stop.id
        var components = URLComponents(string: "https://api.at.govt.nz/gtfs/v3/stops/\(encodedID)/stoptrips")!
        components.queryItems = [
            URLQueryItem(name: "filter[date]", value: serviceDate),
            URLQueryItem(name: "filter[start_hour]", value: serviceHour)
        ]
        let data = try await authenticatedData(url: components.url!, key: key, timeout: 12)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resources = root["data"] as? [[String: Any]] else { throw TransitError.invalidResponse }
        let trips = resources.compactMap { resource -> ScheduledTrip? in
            guard let attributes = resource["attributes"] as? [String: Any],
                  let tripID = attributes["trip_id"] as? String,
                  let routeID = attributes["route_id"] as? String,
                  let day = attributes["service_date"] as? String,
                  let time = attributes["departure_time"] as? String,
                  let stopSequence = Self.number(attributes["stop_sequence"]).map(Int.init),
                  Self.number(attributes["pickup_type"]) != 1,
                  let scheduledDate = Self.localDate(day: day, time: time, calendar: calendar) else { return nil }
            let destination = (attributes["stop_headsign"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? attributes["trip_headsign"] as? String ?? ""
            return ScheduledTrip(tripID: tripID, routeID: routeID, destination: destination.capitalized,
                                 stop: stop, stopSequence: stopSequence, scheduledDate: scheduledDate)
        }
        await StopTripsCache.shared.set(trips, for: cacheKey)
        return trips
    }

    private func liveUpdates(for stops: [BusStop], key: String) async throws -> LiveUpdates {
        let data = try await authenticatedData(path: "/realtime/legacy/tripupdates", key: key)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw TransitError.invalidResponse }
        let feed = root["response"] as? [String: Any] ?? root
        guard let entities = feed["entity"] as? [[String: Any]] else { throw TransitError.invalidResponse }
        let stopIDs = Set(stops.map(\.id))
        var results = LiveUpdates()
        for entity in entities {
            guard let update = entity["trip_update"] as? [String: Any],
                  let trip = update["trip"] as? [String: Any],
                  let tripID = trip["trip_id"] as? String,
                  Self.number(trip["schedule_relationship"]) != 3 else { continue }
            let vehicleID = (update["vehicle"] as? [String: Any])?["id"] as? String
            let timestamp = Self.number(update["timestamp"]).map(Date.init(timeIntervalSince1970:))
            let stopTimes = (update["stop_time_update"] as? [[String: Any]]) ??
                (update["stop_time_update"] as? [String: Any]).map { [$0] } ?? []
            for stopTime in stopTimes {
                let event = (stopTime["departure"] as? [String: Any]) ?? (stopTime["arrival"] as? [String: Any])
                if let sequence = Self.number(stopTime["stop_sequence"]).map(Int.init),
                   let delay = Self.number(event?["delay"]) {
                    let progress = TripProgress(sequence: sequence, delay: delay,
                                                vehicleID: vehicleID, timestamp: timestamp)
                    if sequence >= (results.byTrip[tripID]?.sequence ?? -1) {
                        results.byTrip[tripID] = progress
                    }
                }
                guard let stopID = stopTime["stop_id"] as? String,
                      stopIDs.contains(stopID),
                      Self.number(stopTime["schedule_relationship"]) != 3,
                      let event,
                      let predictedTime = Self.number(event["time"]) else { continue }
                results.exact["\(tripID)-\(stopID)"] = Prediction(date: Date(timeIntervalSince1970: predictedTime),
                                                                    vehicleID: vehicleID)
            }
        }
        return results
    }

    private static func localDate(day: String, time: String, calendar: Calendar) -> Date? {
        let dayParts = day.split(separator: "-").compactMap { Int($0) }
        let timeParts = time.split(separator: ":").compactMap { Int($0) }
        guard dayParts.count == 3, timeParts.count == 3 else { return nil }
        let components = DateComponents(timeZone: calendar.timeZone, year: dayParts[0], month: dayParts[1],
                                        day: dayParts[2], hour: timeParts[0], minute: timeParts[1], second: timeParts[2])
        return calendar.date(from: components)
    }

    private func routeNames(key: String) async throws -> [String: String] {
        if let cached = await RouteNameCache.shared.get() { return cached }
        let data = try await authenticatedData(path: "/gtfs/v3/routes", key: key, timeout: 8)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resources = root["data"] as? [[String: Any]] else { throw TransitError.invalidResponse }
        let names = Dictionary(uniqueKeysWithValues: resources.compactMap { resource -> (String, String)? in
            guard let attributes = resource["attributes"] as? [String: Any],
                  let id = attributes["route_id"] as? String,
                  let shortName = attributes["route_short_name"] as? String else { return nil }
            return (id, shortName)
        })
        await RouteNameCache.shared.set(names)
        return names
    }

    private func authenticatedData(path: String, key: String, timeout: TimeInterval = 25) async throws -> Data {
        try await authenticatedData(url: URL(string: "https://api.at.govt.nz\(path)")!, key: key, timeout: timeout)
    }

    private func authenticatedData(url: URL, key: String, timeout: TimeInterval = 25) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw TransitError.invalidResponse }
        if status == 401 || status == 403 { throw TransitError.apiKeyRejected }
        guard status == 200 else { throw TransitError.serviceUnavailable }
        return data
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
}

private actor RouteNameCache {
    static let shared = RouteNameCache()

    private var names: [String: String]?
    private var timestamp: Date?

    func get() -> [String: String]? {
        guard let timestamp, Date().timeIntervalSince(timestamp) < 12 * 3600 else { return nil }
        return names
    }

    func set(_ names: [String: String]) {
        self.names = names
        timestamp = .now
    }
}

private struct ScheduledTrip {
    let tripID: String
    let routeID: String
    let destination: String
    let stop: BusStop
    let stopSequence: Int
    let scheduledDate: Date

    var id: String { "\(tripID)-\(stop.id)" }
}

private struct Prediction {
    let date: Date
    let vehicleID: String?
}

private struct TripProgress {
    let sequence: Int
    let delay: Double
    let vehicleID: String?
    let timestamp: Date?
}

private struct LiveUpdates {
    var exact: [String: Prediction] = [:]
    var byTrip: [String: TripProgress] = [:]

    func estimate(for trip: ScheduledTrip) -> Prediction? {
        guard let progress = byTrip[trip.tripID],
              progress.sequence <= trip.stopSequence,
              let timestamp = progress.timestamp,
              abs(Date().timeIntervalSince(timestamp)) < 600 else { return nil }
        return Prediction(date: trip.scheduledDate.addingTimeInterval(progress.delay),
                          vehicleID: progress.vehicleID)
    }
}

private actor StopTripsCache {
    static let shared = StopTripsCache()

    private var values: [String: [ScheduledTrip]] = [:]

    func get(_ key: String) -> [ScheduledTrip]? { values[key] }

    func set(_ trips: [ScheduledTrip], for key: String) { values[key] = trips }
}
