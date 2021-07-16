import StoreKit

extension SKPaymentTransaction {
    func date() -> Date {
        transactionDate ?? Date(timeIntervalSince1970: 0)
    }
}
