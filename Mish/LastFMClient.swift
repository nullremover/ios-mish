import Foundation
import Security
import CommonCrypto

/// Small Last.fm API client for publishing Mish's currently playing track.
/// The API shared secret and user session key are kept in iOS Keychain.
enum LastFMClient {
    private static let endpoint = URL(string: "https://ws.audioscrobbler.com/2.0/")!
    private static let keychainService = "dev.mish.player.lastfm"
    private static let secretAccount = "api-secret"
    private static let sessionAccount = "session-key"
    private static let pendingTokenAccount = "pending-auth-token"
    private static let apiKeyDefaults = "mish.lastfm.apiKey"
    private static let usernameDefaults = "mish.lastfm.username"

    static var savedAPIKey: String {
        UserDefaults.standard.string(forKey: apiKeyDefaults) ?? ""
    }

    static var connectedUsername: String? {
        guard hasSessionKey else { return nil }
        return UserDefaults.standard.string(forKey: usernameDefaults)
    }

    static var isConnected: Bool { hasSessionKey }
    static var hasSavedSecret: Bool { (try? Keychain.value(for: secretAccount)) != nil }

    /// Saves the public API key and stores the shared secret in Keychain.
    /// Leaving the secret field blank keeps an already-saved secret intact.
    static func configure(apiKey: String, secret: String) throws {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { throw LastFMError.missingAPIKey }

        let oldKey = savedAPIKey
        let oldSecret = try? Keychain.value(for: secretAccount)
        if !cleanSecret.isEmpty {
            try Keychain.save(cleanSecret, for: secretAccount)
        } else if oldSecret == nil {
            throw LastFMError.missingAPISecret
        }

        UserDefaults.standard.set(cleanKey, forKey: apiKeyDefaults)
        if oldKey != cleanKey || (!cleanSecret.isEmpty && oldSecret != cleanSecret) {
            Keychain.delete(sessionAccount)
            Keychain.delete(pendingTokenAccount)
            UserDefaults.standard.removeObject(forKey: usernameDefaults)
        }
    }

    /// Starts Last.fm's desktop-style authorization flow. The user approves Mish
    /// in the browser, then returns to Mish and taps "Finish connection".
    static func beginAuthorization() async throws -> URL {
        let apiKey = savedAPIKey
        let secret = try requiredSecret()
        guard !apiKey.isEmpty else { throw LastFMError.missingAPIKey }

        let response = try await call(
            ["api_key": apiKey, "method": "auth.getToken"],
            secret: secret
        )
        guard let token = response["token"] as? String, !token.isEmpty else {
            throw LastFMError.invalidResponse
        }
        try Keychain.save(token, for: pendingTokenAccount)

        var components = URLComponents(string: "https://www.last.fm/api/auth/")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "token", value: token)
        ]
        guard let url = components.url else { throw LastFMError.invalidResponse }
        return url
    }

    /// Exchanges the temporary token (after browser approval) for a persistent session.
    @discardableResult
    static func finishAuthorization() async throws -> String {
        let apiKey = savedAPIKey
        let secret = try requiredSecret()
        guard !apiKey.isEmpty else { throw LastFMError.missingAPIKey }
        guard let token = try? Keychain.value(for: pendingTokenAccount) else {
            throw LastFMError.noPendingAuthorization
        }

        let response = try await call(
            ["api_key": apiKey, "method": "auth.getSession", "token": token],
            secret: secret
        )
        guard let session = response["session"] as? [String: Any],
              let key = session["key"] as? String, !key.isEmpty else {
            throw LastFMError.invalidResponse
        }
        let username = session["name"] as? String ?? "Last.fm account"
        try Keychain.save(key, for: sessionAccount)
        Keychain.delete(pendingTokenAccount)
        UserDefaults.standard.set(username, forKey: usernameDefaults)
        return username
    }

    /// Sends only a Now Playing update. This does not submit a scrobble.
    /// It is intentionally called by PlayerModel on track starts/metadata updates,
    /// not on pause, seek, or timer ticks.
    static func updateNowPlaying(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval
    ) async {
        guard let secret = try? requiredSecret(),
              let sessionKey = try? Keychain.value(for: sessionAccount),
              !savedAPIKey.isEmpty else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanArtist.isEmpty else { return }

        var parameters: [String: String] = [
            "api_key": savedAPIKey,
            "method": "track.updateNowPlaying",
            "sk": sessionKey,
            "artist": cleanArtist,
            "track": cleanTitle
        ]
        let cleanAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanAlbum.isEmpty && cleanAlbum.caseInsensitiveCompare("Unknown Album") != .orderedSame {
            parameters["album"] = cleanAlbum
        }
        if duration.isFinite && duration > 0 {
            parameters["duration"] = String(Int(duration.rounded()))
        }

        do {
            _ = try await call(parameters, secret: secret)
        } catch {
            // Network/auth failures must never interrupt local playback.
            print("Mish Last.fm Now Playing update failed: \(error.localizedDescription)")
        }
    }

    static func disconnect() {
        Keychain.delete(sessionAccount)
        Keychain.delete(pendingTokenAccount)
        UserDefaults.standard.removeObject(forKey: usernameDefaults)
    }

    private static var hasSessionKey: Bool {
        (try? Keychain.value(for: sessionAccount)) != nil
    }

    private static func requiredSecret() throws -> String {
        guard let secret = try? Keychain.value(for: secretAccount), !secret.isEmpty else {
            throw LastFMError.missingAPISecret
        }
        return secret
    }

    private static func call(_ parameters: [String: String], secret: String) async throws -> [String: Any] {
        var signedParameters = parameters
        signedParameters["api_sig"] = signature(for: parameters, secret: secret)
        signedParameters["format"] = "json"

        var components = URLComponents()
        components.queryItems = signedParameters
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let bodyString = components.percentEncodedQuery,
              let body = bodyString.data(using: .utf8) else {
            throw LastFMError.invalidRequest
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LastFMError.httpFailure
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LastFMError.invalidResponse
        }
        if let rawError = json["error"] {
            let message = json["message"] as? String ?? "Last.fm returned error \(rawError)."
            throw LastFMError.api(message)
        }
        return json
    }

    private static func signature(for parameters: [String: String], secret: String) -> String {
        let string = parameters
            .filter { $0.key != "format" && $0.key != "callback" && $0.key != "api_sig" }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)\($0.value)" }
            .joined() + secret
        return md5(string)
    }

    private static func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { inputBuffer in
            digest.withUnsafeMutableBufferPointer { digestBuffer in
                _ = CC_MD5(inputBuffer.baseAddress, CC_LONG(data.count), digestBuffer.baseAddress)
            }
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private enum Keychain {
    static func save(_ value: String, for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.mish.player.lastfm",
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw LastFMError.keychainFailure(status) }
    }

    static func value(for account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.mish.player.lastfm",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw LastFMError.keychainFailure(status)
        }
        return value
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.mish.player.lastfm",
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private enum LastFMError: LocalizedError {
    case missingAPIKey
    case missingAPISecret
    case noPendingAuthorization
    case invalidRequest
    case invalidResponse
    case httpFailure
    case keychainFailure(OSStatus)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Enter your Last.fm API key first."
        case .missingAPISecret:
            return "Enter your Last.fm API shared secret first."
        case .noPendingAuthorization:
            return "No authorization is waiting to be completed. Tap Authorize Last.fm first."
        case .invalidRequest:
            return "Mish could not prepare the Last.fm request."
        case .invalidResponse:
            return "Last.fm returned an unexpected response. Please try again."
        case .httpFailure:
            return "Last.fm could not be reached. Check your connection and try again."
        case .keychainFailure(let status):
            return "iOS Keychain error (\(status))."
        case .api(let message):
            return message
        }
    }
}
