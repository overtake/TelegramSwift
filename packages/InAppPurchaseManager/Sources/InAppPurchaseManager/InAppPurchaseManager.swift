import Foundation
import CoreLocation
import SwiftSignalKit
import StoreKit
import Postbox
import TelegramCore
import CurrencyFormat



private let productIdentifiers = [
    "org.telegram.telegramPremium.annual",
    "org.telegram.telegramPremium.semiannual",
    "org.telegram.telegramPremium.monthly",
    "org.telegram.telegramPremium.twelveMonths",
    "org.telegram.telegramPremium.sixMonths",
    "org.telegram.telegramPremium.threeMonths"
]

private func isSubscriptionProductId(_ id: String) -> Bool {
    return id.hasSuffix(".monthly") || id.hasSuffix(".annual") || id.hasSuffix(".semiannual")
}


private extension NSDecimalNumber {
    func round(_ decimals: Int) -> NSDecimalNumber {
        return self.rounding(accordingToBehavior:
                            NSDecimalNumberHandler(roundingMode: .down,
                                   scale: Int16(decimals),
                                   raiseOnExactness: false,
                                   raiseOnOverflow: false,
                                   raiseOnUnderflow: false,
                                   raiseOnDivideByZero: false))
    }
}



public final class InAppPurchaseManager: NSObject {
    public final class Product : NSObject {
        let skProduct: SKProduct
        private lazy var numberFormatter: NumberFormatter = {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .currency
            numberFormatter.locale = self.skProduct.priceLocale
            return numberFormatter
        }()

        
        init(skProduct: SKProduct) {
            self.skProduct = skProduct
        }
//
//        var subscriptionInfo: String {
//            return skProduct.
//        }
        
        public var id: String {
            return self.skProduct.productIdentifier
        }

        
        public var isSubscription: Bool {
            
            if #available(macOS 10.14, *) {
                return self.skProduct.subscriptionGroupIdentifier != nil
            } else if #available(macOS 10.13.2, *) {
                return self.skProduct.subscriptionPeriod != nil
            } else {
                return self.id.contains(".monthly")
            }
        }

        public func pricePerMonth(_ monthsCount: Int) -> String {
            let price = self.skProduct.price.dividing(by: NSDecimalNumber(value: monthsCount)).round(2)
            return numberFormatter.string(from: price) ?? ""
        }
        
        public var priceValue: NSDecimalNumber {
            return self.skProduct.price
        }
        
        public var priceCurrencyAndAmount: (currency: String, amount: Int64) {
            if let currencyCode = self.numberFormatter.currencyCode,
                let amount = fractionalToCurrencyAmount(value: self.priceValue.doubleValue, currency: currencyCode) {
                return (currencyCode, amount)
            } else {
                return ("", 0)
            }
        }
        
        public var price: String {
            return numberFormatter.string(from: self.skProduct.price) ?? ""
        }
    }
    
    public enum PurchaseState {
        case purchased(transactionId: String)
    }
    
    public enum PurchaseError {
        case generic
        case cancelled
        case network
        case notAllowed
        case cantMakePayments
        case assignFailed
    }

    
    private final class PaymentTransactionContext {
        var state: TransactionState?
        var subscriber: ((TransactionState) -> Void)?
        var targetPeerId: PeerId?
        init(targetPeerId: PeerId?, subscriber: ((TransactionState) -> Void)? = nil) {
            self.targetPeerId = targetPeerId
            self.subscriber = subscriber
        }
    }
    
    private enum TransactionState {
        case purchased(transactionId: String?)
        case restored(transactionId: String?)
        case purchasing
        case failed(error: SKError?)
        case assignFailed
        case deferred
    }

    
    public enum RestoreState {
        case succeed
        case failed
    }

    
    private let premiumProductId: String
    
    private var products: [Product] = []
    private var productsPromise = Promise<[Product]>()
    private var productRequest: SKProductsRequest?
    
    private let stateQueue = Queue()
    private var paymentContexts: [String: PaymentTransactionContext] = [:]
    
    private var onRestoreCompletion: ((RestoreState) -> Void)?


    
    public init(premiumProductId: String) {
        self.premiumProductId = premiumProductId
        
        super.init()
        
        SKPaymentQueue.default().add(self)
        self.requestProducts()
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    private func requestProducts() {
        Logger.shared.log("InAppPurchaseManager", "Requesting products")
        let productRequest = SKProductsRequest(productIdentifiers: Set(productIdentifiers))
        productRequest.delegate = self
        productRequest.start()
        
        self.productRequest = productRequest
    }

    
    public func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    public var availableProducts: Signal<[Product], NoError> {
        if self.products.isEmpty && self.productRequest == nil {
            self.requestProducts()
        }
        return self.productsPromise.get()
    }
    
    public func finishTransaction(_ transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    public func finishAllTransactions() {
        for transaction in SKPaymentQueue.default().transactions {
            SKPaymentQueue.default().finishTransaction(transaction)
        }
    }
    
    public func restorePurchases(completion: @escaping (RestoreState) -> Void) {
        Logger.shared.log("InAppPurchaseManager", "Restoring purchases")
        self.onRestoreCompletion = completion
        
        let paymentQueue = SKPaymentQueue.default()
        paymentQueue.restoreCompletedTransactions()
    }

    
    public func buyProduct(_ product: Product, account: Account, targetPeerId: PeerId? = nil) -> Signal<PurchaseState, PurchaseError> {
        if !self.canMakePayments() {
            return .fail(.cantMakePayments)
        }
        
        if !product.isSubscription && targetPeerId == nil {
            return .fail(.cantMakePayments)
        }
        
        let accountPeerId = "\(account.peerId.toInt64())"
        
        Logger.shared.log("InAppPurchaseManager", "Buying: account \(accountPeerId), product \(product.skProduct.productIdentifier), price \(product.price)")
        
        let payment = SKMutablePayment(product: product.skProduct)
        payment.applicationUsername = accountPeerId
        SKPaymentQueue.default().add(payment)
        
        let productIdentifier = payment.productIdentifier
        let signal = Signal<PurchaseState, PurchaseError> { subscriber in
            let disposable = MetaDisposable()
            
            self.stateQueue.async {
                let paymentContext = PaymentTransactionContext(targetPeerId: targetPeerId, subscriber: { state in
                    switch state {
                        case let .purchased(transactionId), let .restored(transactionId):
                            if let transactionId = transactionId {
                                subscriber.putNext(.purchased(transactionId: transactionId))
                                subscriber.putCompletion()
                            } else {
                                subscriber.putError(.generic)
                            }
                        case let .failed(error):
                            if let error = error {
                                let mappedError: PurchaseError
                                switch error.code {
                                    case .paymentCancelled:
                                        mappedError = .cancelled
                                    case .cloudServiceNetworkConnectionFailed, .cloudServicePermissionDenied:
                                        mappedError = .network
                                    case .paymentNotAllowed, .clientInvalid:
                                        mappedError = .notAllowed
                                    default:
                                        mappedError = .generic
                                }
                                subscriber.putError(mappedError)
                            } else {
                                subscriber.putError(.generic)
                            }
                        case .assignFailed:
                            subscriber.putError(.assignFailed)
                        case .deferred, .purchasing:
                            break
                    }
                })
                self.paymentContexts[productIdentifier] = paymentContext
                
                disposable.set(ActionDisposable { [weak paymentContext] in
                    self.stateQueue.async {
                        if let current = self.paymentContexts[productIdentifier], current === paymentContext {
                            self.paymentContexts.removeValue(forKey: productIdentifier)
                        }
                    }
                })
            }
            
            return disposable
        }
        return signal
    }

}

extension InAppPurchaseManager: SKProductsRequestDelegate {
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.productRequest = nil
        
        Queue.mainQueue().async {
            self.productsPromise.set(.single(response.products.map { Product(skProduct: $0) }))
        }
    }
}

extension InAppPurchaseManager: SKPaymentTransactionObserver {
    
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        Queue.mainQueue().async {
            if let onRestoreCompletion = self.onRestoreCompletion {
                Logger.shared.log("InAppPurchaseManager", "Transactions restoration finished")
                onRestoreCompletion(.succeed)
                self.onRestoreCompletion = nil
            }
        }
    }

    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        if let transaction = transactions.last {
            let productIdentifier = transaction.payment.productIdentifier
            self.stateQueue.async {
                let transactionState: TransactionState?
                switch transaction.transactionState {
                    case .purchased:
                        transactionState = .purchased(transactionId: transaction.transactionIdentifier)
                    case .restored:
                        transactionState = .restored(transactionId: transaction.transactionIdentifier)
                    case .failed:
                        transactionState = .failed(error: transaction.error as? SKError)
                    case .purchasing:
                        transactionState = .purchasing
                    case .deferred:
                        transactionState = .deferred
                    default:
                        transactionState = nil
                }
                if let transactionState = transactionState {
                    if let context = self.paymentContexts[productIdentifier] {
                        context.state = transactionState
                        context.subscriber?(transactionState)
                    }
                }
            }
        }
    }
}


public extension InAppPurchaseManager {
    static func getReceiptData() -> Data? {
        var receiptData: Data?
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
            do {
                receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
            } catch {
                Logger.shared.log("InAppPurchaseManager", "Couldn't read receipt data with error: \(error.localizedDescription)")
            }
        }
        return receiptData
    }
}
