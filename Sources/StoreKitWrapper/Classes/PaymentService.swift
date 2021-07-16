import FoundationExtensions
import StoreKit

///
public final class PaymentService {
    // MARK: Lifecycle

    private init() {
        storeKit.onOngoingTransaction = handleOngoingTransaction
    }

    // MARK: Public

    /// Return the shared PaymentService object.
    public static let shared = PaymentService()

    /// Upload products with specific identifiers from the App Store and cache them.
    ///
    /// - Parameter identifiers: A set of the products identifiers.
    public func refreshProductsAfterStart(identifiers: Set<String>) {
        refreshProducts(identifiers: identifiers)
    }

    /// Fetch products with specific identifiers.
    ///
    /// - Parameters:
    ///   - identifiers: A set of the products identifiers.
    ///   - completion: A closure that receives two parameters: the `[SKProduct]`, and an `SKError` that indicates an error occured while receiving the products.
    public func refreshProducts(
        identifiers: Set<String>,
        completion: ResultClosure<[SKProduct]>? = nil
    ) {
        onBackground {
            self.storeKit.fetchProducts(
                identifiers: identifiers
            ) { result in
                switch result {
                case let .success(products):
                    onMain {
                        completion?(.success(products))
                    }
                case let .failure(error):
                    onMain {
                        completion?(.failure(error))
                    }
                }
            }
        }
    }

    /// Purchase specific product.
    ///
    /// - Parameters:
    ///   - product: A product identifier.
    ///   - completion: A closure that receives two parameters: the `String` that contains receipt data , and an `SKError` that indicates an error occured while purchasing the product.
    public func buy(
        _ product: String,
        completion: @escaping ResultClosure<String>
    ) {
        onBackground {
            self.storeKit.purchase(
                productId: product
            ) { [weak self] result in
                guard let self = self else {
                    return
                }

                switch result {
                case .success:
                    onMain {
                        self.finishOngoingTransaction { result in
                            switch result {
                            case let .success(receipt):
                                completion(.success(receipt))
                            case let .failure(error):
                                completion(.failure(error))
                            }
                        }
                    }
                case let .failure(error):
                    onMain {
                        guard error.code != .paymentCancelled else {
                            self.storeKit.finishPurchase()
                            completion(.failure(error))
                            return
                        }

                        self.finishOngoingTransaction(
                            canRefreshReceipt: true,
                            completion: completion
                        )
                    }
                }
            }
        }
    }

    /// Restore all transactions from the App Store.
    ///
    /// - Parameters:
    ///   - completion: A closure that receives two parameters: the `String` that contains receipt data , and an `SKError` that indicates an error occured while restoring the transaction.
    public func restoreTransaction(
        completion: @escaping ResultClosure<String>
    ) {
        onBackground {
            log.debug(message: "Restore transaction")

            self.storeKit.restorePurchase { _ in
                self.finishOngoingTransaction(
                    canRefreshReceipt: true,
                    completion: completion
                )
            }
        }
    }

    /// Refresh receipt from the App Store.
    public func refreshReceipt() {
        storeKit.refreshReceipt { [weak self] _ in
            self?.finishOngoingTransaction(completion: { _ in })
        }
    }

    /// Start observing payment queue.
    public func startObservingPayments() {
        storeKit.startObservingPayments()
    }

    /// Stop observing payment queue.
    public func stopObservingPayments() {
        storeKit.stopObservingPayments()
    }

    // MARK: Internal

    /// Cancel ongoing transaction.
    func cancelTransaction() {
        onBackground {
            log.debug(message: "Cancel transaction")
            self.storeKit.finishPurchase()
        }
    }

    // MARK: Private

    private var storeKit: StoreKitWraperProtocol = StoreKitWrapper.shared

    /// Default handler for all ongoing transactions.
    private func handleOngoingTransaction() {
        onMain {
            self.finishOngoingTransaction(
                canRefreshReceipt: true,
                completion: { result in
                    switch result {
                    case .success:
                        log.debug(message: "handleOngoingTransaction: Ongoing transaction succeeded")
                    case let .failure(error):
                        log.debug(message: "handleOngoingTransaction: Finishing ongoing transaction failed: \(error)")
                    }
                }
            )
        }
    }

    /// Finish ongoing transaction.
    ///
    /// - Parameters:
    ///   - canRefreshReceipt: A boolean value that indicates receipt will be refreshed.
    ///   - completion: A closure that receives two parameters: the `String` that contains receipt data , and an `SKError` that indicates an errort.
    private func finishOngoingTransaction(
        canRefreshReceipt: Bool = false,
        completion: @escaping ResultClosure<String>
    ) {
        guard let receipt = storeKit.getReceipt() else {
            if canRefreshReceipt {
                log.debug(message: "No receipt, attempting to refresh")

                storeKit.refreshReceipt { result in
                    switch result {
                    case .success:
                        self.finishOngoingTransaction(
                            canRefreshReceipt: false,
                            completion: completion
                        )
                    case let .failure(error):
                        self.storeKit.finishPurchase()
                        onMain {
                            completion(.failure(error))
                        }
                    }
                }
            } else {
                storeKit.finishPurchase()

                onMain {
                    completion(
                        .failure(
                            error(
                                code: .unknown,
                                description: "Receipt not found"
                            )
                        )
                    )
                }
            }
            return
        }

        storeKit.finishPurchase()

        onMain {
            completion(.success(receipt))
        }
    }
}
