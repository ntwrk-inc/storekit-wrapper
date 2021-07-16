import StoreKit

protocol IAPObserverDelegate: AnyObject {
    func iapObserver(
        _ observer: IAPObserver,
        paymentQueueRestoreCompletedTransactionsFinished queue: SKPaymentQueue
    )

    func iapObserver(
        _ observer: IAPObserver,
        restoreCompletedTransactionsFailedWithError error: Error
    )

    func iapObserver(
        _ observer: IAPObserver,
        transactionWasCancelled transaction: SKPaymentTransaction
    )

    func iapObserver(
        _ observer: IAPObserver,
        transactionFailed transaction: SKPaymentTransaction,
        withError error: SKError
    )

    func iapObserver(
        _ observer: IAPObserver,
        transactionWasCompletedPurchase transaction: SKPaymentTransaction
    )

    func iapObserver(
        _ observer: IAPObserver,
        transactionWasCompletedRestore transaction: SKPaymentTransaction
    )
}
