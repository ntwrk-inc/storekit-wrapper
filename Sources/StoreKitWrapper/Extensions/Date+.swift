import Foundation

extension Date {
    init?(millisecondsSince1970: String) {
        guard let millisecondsNumber = Double(millisecondsSince1970) else {
            return nil
        }
        self = Date(timeIntervalSince1970: millisecondsNumber / 1000)
    }
}
