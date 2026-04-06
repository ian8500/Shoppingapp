import Foundation

struct APIError: Error, LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func healthCheck() async throws -> Bool {
        _ = try await request(path: "/api/v1/health", method: "GET", authToken: nil, requestBody: Optional<String>.none) as HealthResponse
        return true
    }

    func createHousehold(name: String, accessToken: String) async throws -> HouseholdCreateResponse {
        try await request(
            path: "/api/v1/households",
            method: "POST",
            authToken: accessToken,
            requestBody: HouseholdCreateRequest(name: name)
        )
    }

    func listMemberships(accessToken: String) async throws -> HouseholdMembershipListResponse {
        try await request(path: "/api/v1/households/memberships", method: "GET", authToken: accessToken, requestBody: Optional<String>.none)
    }

    func listShoppingItems(householdID: UUID, accessToken: String) async throws -> ShoppingListResponse {
        try await request(
            path: "/api/v1/households/\(householdID.uuidString)/shopping-items",
            method: "GET",
            authToken: accessToken,
            requestBody: Optional<String>.none
        )
    }

    func createShoppingItem(householdID: UUID, accessToken: String, draft: ShoppingListItemDraft) async throws -> ShoppingListItem {
        try await request(
            path: "/api/v1/households/\(householdID.uuidString)/shopping-items",
            method: "POST",
            authToken: accessToken,
            requestBody: ShoppingItemUpsertRequest.fromDraft(draft)
        )
    }

    func updateShoppingItem(householdID: UUID, accessToken: String, itemID: UUID, draft: ShoppingListItemDraft) async throws -> ShoppingListItem {
        try await request(
            path: "/api/v1/households/\(householdID.uuidString)/shopping-items/\(itemID.uuidString)",
            method: "PATCH",
            authToken: accessToken,
            requestBody: ShoppingItemUpsertRequest.fromDraft(draft)
        )
    }

    func markShoppingItemBought(householdID: UUID, accessToken: String, itemID: UUID) async throws -> ShoppingListItem {
        try await request(
            path: "/api/v1/households/\(householdID.uuidString)/shopping-items/\(itemID.uuidString)/mark-bought",
            method: "POST",
            authToken: accessToken,
            requestBody: Optional<String>.none
        )
    }

    func archiveShoppingItem(householdID: UUID, accessToken: String, itemID: UUID) async throws {
        _ = try await request(
            path: "/api/v1/households/\(householdID.uuidString)/shopping-items/\(itemID.uuidString)",
            method: "DELETE",
            authToken: accessToken,
            requestBody: Optional<String>.none
        ) as EmptyAPIResponse
    }

    private func request<T: Decodable, B: Encodable>(
        path: String,
        method: String,
        authToken: String?,
        requestBody: B?
    ) async throws -> T {
        let endpoint = baseURL.appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if let requestBody {
            request.httpBody = try encoder.encode(requestBody)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid server response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorPayload = try? decoder.decode(APIErrorPayload.self, from: data) {
                throw APIError(message: errorPayload.detail)
            }
            throw APIError(message: "Server error \(httpResponse.statusCode)")
        }

        if T.self == EmptyAPIResponse.self {
            return EmptyAPIResponse() as! T
        }

        return try decoder.decode(T.self, from: data)
    }
}

private struct APIErrorPayload: Decodable {
    let detail: String
}

private struct HealthResponse: Decodable {
    let status: String
}

private struct HouseholdCreateRequest: Encodable {
    let name: String
}

private struct ShoppingItemUpsertRequest: Encodable {
    let rawName: String
    let quantity: Double?
    let unit: String?
    let category: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case rawName = "raw_name"
        case quantity
        case unit
        case category
        case notes
    }

    static func fromDraft(_ draft: ShoppingListItemDraft) -> ShoppingItemUpsertRequest {
        ShoppingItemUpsertRequest(
            rawName: draft.rawName,
            quantity: draft.quantity,
            unit: draft.unit,
            category: draft.category,
            notes: draft.notes
        )
    }
}

private struct EmptyAPIResponse: Decodable {}

struct HouseholdCreateResponse: Decodable {
    let household: HouseholdAPIModel
    let membership: HouseholdMembership
}

struct HouseholdMembershipListResponse: Decodable {
    let memberships: [HouseholdMembership]
}

struct ShoppingListResponse: Decodable {
    let items: [ShoppingListItem]
}

struct HouseholdAPIModel: Decodable {
    let id: UUID
    let name: String
    let createdBy: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
    }

    var asDomain: Household {
        Household(id: id, name: name, createdBy: createdBy, createdAt: createdAt)
    }
}
