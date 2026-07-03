import Foundation
@testable import BoardlyKit

// MARK: - MockHTTPClient

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var stubbedResponse: (Data, HTTPURLResponse)?
    var stubbedError: Error?
    private(set) var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let error = stubbedError { throw error }
        guard let response = stubbedResponse else {
            throw URLError(.badServerResponse)
        }
        return (response.0, response.1)
    }

    func stub(json: String, statusCode: Int = 200, url: URL = URL(string: "https://example.com")!) {
        let data = json.data(using: .utf8) ?? Data()
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        stubbedResponse = (data, response)
    }

    func stub(data: Data, statusCode: Int = 200, url: URL = URL(string: "https://example.com")!) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        stubbedResponse = (data, response)
    }
}

// MARK: - MockKeychainStore

final class MockKeychainStore: KeychainStoring, @unchecked Sendable {
    private var store: [String: String] = [:]
    var saveCallCount = 0
    var deleteCallCount = 0

    func save(_ value: String, for key: String) throws {
        saveCallCount += 1
        store[key] = value
    }

    func load(for key: String) throws -> String? {
        store[key]
    }

    func delete(for key: String) throws {
        deleteCallCount += 1
        store.removeValue(forKey: key)
    }
}

// MARK: - Helpers

func makeProfile(
    id: UUID = UUID(),
    name: String = "Test Server",
    baseURL: URL = URL(string: "https://planka.example.com")!) -> ServerProfile
{
    ServerProfile(id: id, name: name, baseURL: baseURL)
}

func loadFixture(_ name: String) -> Data {
    let bundle = Bundle.module
    guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
          let data = try? Data(contentsOf: url)
    else {
        fatalError("Missing fixture: Fixtures/\(name).json")
    }
    return data
}
