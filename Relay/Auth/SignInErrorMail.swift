//
//  SignInErrorMail.swift
//  Relay
//

import Foundation

/// Builds the "Report Error" mailto: link shown alongside a sign-in error
/// alert, pre-filled with enough detail (service, friendly message, and the
/// raw underlying error) to act on without back-and-forth.
enum SignInErrorMail {
    static func reportURL(service: String, message: String, detail: String?) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "octabits@icloud.com"

        var body = "Ran into this error connecting to \(service) in Relay:\n\n\(message)"
        if let detail {
            body += "\n\nDetails:\n\(detail)"
        }
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Relay – \(service) sign-in error"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url!
    }
}
