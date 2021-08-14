import StoreKit

private var userInfo: [SKError.Code: Any] = [
    .unknown: "Unknown error",
    .paymentCancelled: "Payment cancelled",
    .paymentNotAllowed: "Payment not allowed",
    .storeProductNotAvailable: "Products not available",
]

private func infoDescription(code: SKError.Code, description: String? = nil) -> String? {
    if let info = userInfo[code] as? String {
        if let description = description {
            return "\(info). Description: \(description)"
        }
        return info
    }
    return nil
}

private func userInfo(code: SKError.Code, description: String? = nil) -> [String: Any]? {
    if let info = infoDescription(code: code, description: description) {
        return [NSLocalizedDescriptionKey: info]
    }
    return nil
}

/// Create a new instance `SKError` based on code type of the error.
///
/// - Parameters:
///   - code: The error code.
///   - description: Additional description of the error.
///
/// - Returns: The new instance of the `SKError`.
internal func error(code: SKError.Code, description: String? = nil) -> SKError {
    let info = userInfo(code: code, description: description)
    let error = NSError(domain: SKErrorDomain, code: code.rawValue, userInfo: info)
    return SKError(_nsError: error)
}
