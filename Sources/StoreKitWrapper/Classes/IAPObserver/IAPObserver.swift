import Foundation
import StoreKit

// MARK: - IAPObserver

final class IAPObserver: NSObject {
    // MARK: Internal

    weak var delegate: IAPObserverDelegate?

    // MARK: Private

    /// Sort transaction by date.
    ///
    /// - Parameter transactions: An array of the transactions that were updated.
    ///
    /// - Returns: Array of sorted transactions.
    private func sortedTransactions(_ transactions: [SKPaymentTransaction]) -> [SKPaymentTransaction] {
        transactions.sorted {
            let firstTransactionDate = $0.transactionDate ?? Date(timeIntervalSince1970: 0)
            let secondTransactionDate = $1.transactionDate ?? Date(timeIntervalSince1970: 0)

            return firstTransactionDate < secondTransactionDate
        }
    }

    private func handleTransaction(_ transaction: SKPaymentTransaction, error: Error?) {
        guard error == nil else {
            if let error = error as? SKError {
                if error.code != .paymentCancelled {
                    delegate?.iapObserver(self, transactionFailed: transaction, withError: error)
                } else {
                    delegate?.iapObserver(self, transactionWasCancelled: transaction)
                }
            }
            return
        }

        if transaction.transactionState == .purchased {
            delegate?.iapObserver(
                self,
                transactionWasCompletedPurchase: transaction
            )
        } else {
            delegate?.iapObserver(
                self,
                transactionWasCompletedRestore: transaction
            )
        }
    }
}

// MARK: SKPaymentTransactionObserver

extension IAPObserver: SKPaymentTransactionObserver {
    func paymentQueue(_: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        if transactions.count > 1,
           transactions[0].transactionState == .restored ||
           transactions[0].transactionState == .purchased
        {
            let transactions = sortedTransactions(transactions)
            let recentTransaction = transactions.last

            transactions
                .dropLast()
                .forEach { transaction in
                    SKPaymentQueue.default().finishTransaction(transaction)
                }

            if let recentTransaction = recentTransaction {
                handleTransaction(recentTransaction, error: recentTransaction.error)
            }

            return
        }

        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                break
            case .purchased:
                handleTransaction(transaction, error: nil)
            case .failed, .restored:
                handleTransaction(transaction, error: transaction.error)
            case .deferred:
                log.debug(message: "Received transaction state: deferred")
            @unknown default:
                assertionFailure("Unknown transactionState")
            }
        }
    }

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        delegate?.iapObserver(self, paymentQueueRestoreCompletedTransactionsFinished: queue)
    }

    func paymentQueue(_: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        delegate?.iapObserver(
            self,
            restoreCompletedTransactionsFailedWithError: error
        )
    }
}
