import Foundation
import StoreKit

public protocol StoreKitWraperProtocol {
    var onOngoingTransaction: () -> Void { get set }

    /// Fetch products with specific identifiers.
    ///
    /// Pass the product identifiers and handle response:
    ///
    ///      StoreKitWrapper.shared.fetchProducts(
    ///            identifiers: identifiers,
    ///            completion: { result in
    ///                switch result {
    ///                case let .success(products):
    ///                     // Handle fetched products
    ///                case let .failed(error):
    ///                     // Handle error
    ///            }
    ///      )
    ///
    /// - Parameters:
    ///   - identifiers: A set of the products identifiers.
    ///   - completion: A closure that receives two parameters: the `[SKProduct]`, and an `SKError` that indicates an error occured while receiving the products.
    func fetchProducts(
        identifiers: Set<String>,
        completion: @escaping ResultClosure<[SKProduct]>
    )

    /// Purchase specific product.
    ///
    /// Pass product identifier and handle response:
    ///
    ///      StoreKitWrapper.shared.purchase(
    ///            productId: identifier,
    ///            completion: { result in
    ///                switch result {
    ///                case .success:
    ///                    // Product successfully purchased
    ///                case let .failure(error):
    ///                    // Handle recieved error
    ///                }
    ///           }
    ///      )
    ///
    /// - Parameters:
    ///   - productId: A product identifier.
    ///   - completion: A closure that receives two parameters: the `Void` that indicates purchased was completed, and an `SKError` that indicates an error occured while purchasing the product.
    func purchase(
        productId: String,
        completion: @escaping ResultClosure<Void>
    )

    /// FInish all ongoing transactions.
    func finishPurchase()

    /// Check if exists ongoing transactions.
    ///
    /// - Returns: true if exists ongoing purchase, otherwise false.
    func hasOngoingPurchase() -> Bool

    /// Return App Store receipt if exists.
    ///
    /// - Returns: Receipt data.
    func getReceipt() -> String?

    /// Refresh receipt from the App Store.
    ///
    /// - Parameters:
    ///   - completion: A closure that receives two parameters: the `Void` that indicates receipt refresh was completed, and an `SKError` that indicates an error occured while refreshing the receipt.
    func refreshReceipt(completion: @escaping ResultClosure<Void>)

    /// Start observing payment queue.
    func startObservingPayments()

    /// Stop observing payment queue.
    func stopObservingPayments()

    /// Restore all purchases.
    ///
    /// Asks the payment queue to restore previously completed purchases.
    ///
    /// - Parameter completion: A closure that receives two parameters: the `Void` that indicates restore was completed, and an `SKError` that indicates an error occured while restoring the receipt.
    func restorePurchase(completion: @escaping ResultClosure<Void>)
}
