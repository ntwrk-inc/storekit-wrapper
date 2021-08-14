import FoundationExtensions
import StoreKit

// MARK: - StoreKitWrapper

final class StoreKitWrapper: NSObject, StoreKitWraperProtocol {
    // MARK: Internal

    typealias RequestProductResult = Result<[SKProduct], Error>

    /// Return the shared `StoreKitWrapper` object.
    static let shared: StoreKitWraperProtocol = StoreKitWrapper()

    var onOngoingTransaction = {}

    func fetchProducts(
        identifiers: Set<String>,
        completion: @escaping ResultClosure<[SKProduct]>
    ) {
        requestProduct(identifiers: identifiers, completion: completion)
    }

    func purchase(
        productId: String,
        completion: @escaping ResultClosure<Void>
    ) {
        onBackground {
            guard self.onPurchaseHandler.value == nil else {
                self.onPurchaseHandler.value = completion
                return
            }

            guard let product = self.products.first(where: { $0.productIdentifier == productId }) else {
                log.error(message: "Payment: product with id \(productId) not found")

                completion(
                    .failure(
                        error(
                            code: .storeProductNotAvailable,
                            description: "product with identifier: \(productId) not found"
                        )
                    )
                )
                return
            }

            self.onPurchaseHandler.value = completion

            let payment = SKMutablePayment(product: product)
            SKPaymentQueue.default().add(payment)

            log.debug(message: "Added \(product.productIdentifier) to queue")
        }
    }

    func finishPurchase() {
        onBackground {
            guard let value = self.ongoingTransaction.value else {
                log.error(message: "Tried finish transaction, but nothing ongoing")
                return
            }

            self.ongoingTransaction.value = nil
            SKPaymentQueue.default().finishTransaction(value)

            log.debug(message: "finishPurchase: called StoreKit")
        }
    }

    func hasOngoingPurchase() -> Bool {
        ongoingTransaction.value != nil
    }

    func getReceipt() -> String? {
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: appStoreReceiptURL.path)
        {
            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
                let receiptString = receiptData.base64EncodedString(options: [])
                return receiptString
            } catch {
                log.error(message: "Could not read receipt: \(error)")
                return nil
            }
        } else {
            log.error(message: "Did not find receipt on storage")
            return nil
        }
    }

    func refreshReceipt(completion: @escaping ResultClosure<Void>) {
        guard onRefreshReceiptHandler.value == nil else {
            onRefreshReceiptHandler.value = completion
            return
        }

        onRefreshReceiptHandler.value = completion

        let request = SKReceiptRefreshRequest()
        request.delegate = self
        request.start()
    }

    func startObservingPayments() {
        SKPaymentQueue.default().add(paymentObserver)
    }

    func stopObservingPayments() {
        SKPaymentQueue.default().remove(paymentObserver)
    }

    func restorePurchase(completion: @escaping ResultClosure<Void>) {
        onBackground {
            guard self.onRestoreHandler.value == nil else {
                self.onRestoreHandler.value = completion
                return
            }

            self.onRestoreHandler.value = completion
            SKPaymentQueue.default().restoreCompletedTransactions()
        }
    }

    // MARK: Private

    private lazy var paymentObserver: IAPObserver = {
        let paymentObserver = IAPObserver()
        paymentObserver.delegate = self
        return paymentObserver
    }()

    /// A `[SKProduct]` value that contains recived products.
    private var products: [SKProduct] = []

    /// A `SKProductsRequest` value that contains the current product request.
    private var productRequest: SKProductsRequest?

    /// Current transaction handler.
    private var ongoingTransaction = Atomic<SKPaymentTransaction?>(nil)

    /// Products handler.
    private var onReciveProductsHandler = Atomic<ResultClosure<[SKProduct]>?>(nil)

    /// Restored product handler.
    private var onRestoreHandler = Atomic<ResultClosure<Void>?>(nil)

    /// Purchased product handler.
    private var onPurchaseHandler = Atomic<ResultClosure<Void>?>(nil)

    /// Refreshed products handler.
    private var onRefreshReceiptHandler = Atomic<ResultClosure<Void>?>(nil)

    // MARK: Private Methods

    /// Request product with specific identifiers.
    ///
    /// - Parameters:
    ///   - identifiers: A set of the products identifiers.
    ///   - completion: A block object to be executed when the products recieved. This block has no return value and takes a single `[SKProduct]`
    ///   argument that contains all fetched products.
    ///   - fail: A block object to be executed when error occured. This block has no return value and takes a single `Error` argument that contains the error.
    private func requestProduct(
        identifiers: Set<String>,
        completion: @escaping ResultClosure<[SKProduct]>
    ) {
        onBackground {
            guard SKPaymentQueue.canMakePayments() else {
                completion(.failure(error(code: .paymentNotAllowed)))
                return
            }

            guard self.onReciveProductsHandler.value == nil else {
                self.onReciveProductsHandler.value = completion
                return
            }

            guard self.products.isEmpty else {
                log.debug(message: "Returning cached products")
                return completion(.success(self.products))
            }

            self.onReciveProductsHandler.value = completion

            let productRequest = SKProductsRequest(productIdentifiers: identifiers)
            productRequest.delegate = self
            productRequest.start()

            self.productRequest = productRequest
        }
    }

    private func handleTransaction(_ transaction: SKPaymentTransaction) {
        let closure = onPurchaseHandler.value

        guard let completion = closure else {
            let previous = ongoingTransaction.value
            let previousTransactionDate = previous?.date() ?? Date(timeIntervalSince1970: 0)

            if previousTransactionDate < transaction.date() {
                ongoingTransaction.value = transaction

                if let older = previous {
                    SKPaymentQueue.default().finishTransaction(older)
                }

                if onRestoreHandler.value == nil {
                    onOngoingTransaction()
                }
            } else {
                SKPaymentQueue.default().finishTransaction(transaction)
            }
            return
        }

        ongoingTransaction.value = transaction
        onPurchaseHandler.value = nil

        if let transactionError = transaction.error {
            guard let skError = transactionError as? SKError else {
                completion(.failure(error(code: .unknown)))
                return
            }

            completion(.failure(skError))
        } else {
            completion(.success(()))
        }
    }
}

// MARK: SKProductsRequestDelegate

extension StoreKitWrapper: SKProductsRequestDelegate {
    func productsRequest(_: SKProductsRequest, didReceive response: SKProductsResponse) {
        products = response.products

        let onReciveProductHandler = onReciveProductsHandler.value

        guard let reciveProductHandler = onReciveProductHandler else {
            log.error(message: "No waiting callback")
            return
        }

        onReciveProductsHandler.value = nil

        if products.isEmpty {
            log.error(message: "Product request returned no products")

            reciveProductHandler(
                .failure(
                    error(
                        code: .storeProductNotAvailable,
                        description: "product request returned no products"
                    )
                )
            )
        } else {
            log.debug(message: "Products received")
            reciveProductHandler(.success(products))
        }
    }
}

// MARK: SKRequestDelegate

extension StoreKitWrapper: SKRequestDelegate {
    func requestDidFinish(_: SKRequest) {
        onBackground {
            log.debug(message: "Receipt refreshed")

            guard let handler = self.onRefreshReceiptHandler.value else {
                log.debug(message: "No callback waiting for the receipt, calling the default callback")
                self.onOngoingTransaction()
                return
            }

            self.onRefreshReceiptHandler.value = nil

            handler(.success(()))
        }
    }

    func request(_: SKRequest, didFailWithError error: Error) {
        onBackground {
            guard let productsHandler = self.onReciveProductsHandler.value else {
                guard let refreshReceiptHandler = self.onRefreshReceiptHandler.value else {
                    return
                }

                self.onRefreshReceiptHandler.value = nil
                refreshReceiptHandler(.failure(SKError(_nsError: error as NSError)))
                return
            }

            self.onReciveProductsHandler.value = nil
            productsHandler(.failure(SKError(_nsError: error as NSError)))
        }
    }

    func paymentQueue(_: SKPaymentQueue, removedTransactions _: [SKPaymentTransaction]) {}
}

// MARK: IAPObserverDelegate

extension StoreKitWrapper: IAPObserverDelegate {
    func iapObserver(
        _: IAPObserver,
        paymentQueueRestoreCompletedTransactionsFinished _: SKPaymentQueue
    ) {
        guard let restoreHandler = onRestoreHandler.value else {
            return
        }

        onRestoreHandler.value = nil

        if ongoingTransaction.value == nil {
            restoreHandler(
                .failure(
                    error(
                        code: .unknown,
                        description: "Found no payment to be restore"
                    )
                )
            )
        } else {
            restoreHandler(.success(()))
        }
    }

    func iapObserver(
        _: IAPObserver,
        restoreCompletedTransactionsFailedWithError error: Error
    ) {
        guard let restoreHandler = onRestoreHandler.value else {
            log.error(message: "No restore callback, but restore operation failed: \(error)")
            return
        }

        log.error(message: "Restore operation failed: \(error)")
        onRestoreHandler.value = nil
        restoreHandler(.failure(SKError(_nsError: error as NSError)))
    }

    func iapObserver(
        _: IAPObserver,
        transactionWasCancelled transaction: SKPaymentTransaction
    ) {
        handleTransaction(transaction)
    }

    func iapObserver(
        _: IAPObserver,
        transactionFailed transaction: SKPaymentTransaction,
        withError error: SKError
    ) {
        onPurchaseHandler.value?(.failure(error))
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    func iapObserver(
        _: IAPObserver,
        transactionWasCompletedPurchase transaction: SKPaymentTransaction
    ) {
        handleTransaction(transaction)
    }

    func iapObserver(
        _: IAPObserver,
        transactionWasCompletedRestore transaction: SKPaymentTransaction
    ) {
        guard let restoreHandler = onRestoreHandler.value else {
            return
        }

        restoreHandler(.success(()))
        SKPaymentQueue.default().finishTransaction(transaction)
    }
}
