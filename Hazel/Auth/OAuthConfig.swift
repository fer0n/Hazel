//
//  OAuthConfig.swift
//  Hazel
//

enum OAuthConfig {
    static let callbackScheme = "hazel"
    static let ynabRedirectURI = "hazel://oauth/ynab"
    static let splitwiseRedirectURI = "hazel://oauth/splitwise"

    /// The hazel-auth Cloudflare Worker (see ../../oauth-relay/README.md)
    /// that holds YNAB's/Splitwise's client_secret so the app doesn't have
    /// to — required for distributing the app beyond a single device.
    static let oauthRelayBaseURL = "https://hazel-auth.octabits.net"
}
