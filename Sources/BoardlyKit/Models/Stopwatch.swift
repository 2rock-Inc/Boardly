import Foundation

public struct Stopwatch: Codable, Sendable {
    /// When the stopwatch was (re)started; nil means it is stopped.
    public let startedAt: Date?
    /// Accumulated seconds while stopped.
    public let total: Int

    public var isRunning: Bool { startedAt != nil }

    /// Elapsed seconds as of `now` (adds the current run when running).
    public func elapsed(now: Date = Date()) -> Int {
        guard let startedAt else { return total }
        return total + max(0, Int(now.timeIntervalSince(startedAt)))
    }
}

extension Card {
    /// Decode the card's stopwatch (`AnyCodable`) into a typed value.
    public var stopwatchValue: Stopwatch? {
        guard let stopwatch,
              let data = try? JSONEncoder().encode(stopwatch)
        else { return nil }
        return try? JSONDecoder.planka.decode(Stopwatch.self, from: data)
    }
}
