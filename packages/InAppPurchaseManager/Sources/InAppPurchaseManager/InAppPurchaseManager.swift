import Foundation
import CoreLocation
import SwiftSignalKit
import StoreKit
import Postbox
import TelegramCore


public final class InAppPurchaseManager: NSObject {
    public final class Product : NSObject {
        let skProduct: SKProduct
        
        init(skProduct: SKProduct) {
            self.skProduct = skProduct
        }
//
//        var subscriptionInfo: String {
//            return skProduct.
//        }
        
        public var price: String {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .currency
            numberFormatter.locale = self.skProduct.priceLocale
            return numberFormatter.string(from: self.skProduct.price) ?? ""
        }
    }
    
    public enum PurchaseState {
        case purchased(transactionId: SKPaymentTransaction)
    }
    
    public enum PurchaseError {
        case generic(SKPaymentTransaction?)
    }
    
    private final class PaymentTransactionContext {
        var state: TransactionState?
        var subscriber: ((TransactionState) -> Void)?
        
        init(subscriber: ((TransactionState) -> Void)? = nil) {
            self.subscriber = subscriber
        }
    }
    
    private enum TransactionState {
        case purchased(transactionId: SKPaymentTransaction?)
        case restored(transactionId: SKPaymentTransaction?)
        case purchasing(transactionId: SKPaymentTransaction?)
        case failed(transactionId: SKPaymentTransaction?)
        case deferred
    }
    
    private let premiumProductId: String
    
    private var products: [Product] = []
    private var productsPromise = Promise<[Product]>()
    private var productRequest: SKProductsRequest?
    
    private let stateQueue = Queue()
    private var paymentContexts: [String: PaymentTransactionContext] = [:]
    
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
        guard !self.premiumProductId.isEmpty else {
            return
        }
        let productRequest = SKProductsRequest(productIdentifiers: Set([self.premiumProductId]))
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
    
    public func buyProduct(_ product: Product, account: Account) -> Signal<PurchaseState, PurchaseError> {
        let payment = SKMutablePayment(product: product.skProduct)
        
        SKPaymentQueue.default().add(payment)
        
        let productIdentifier = payment.productIdentifier
        let signal = Signal<PurchaseState, PurchaseError> { subscriber in
            let disposable = MetaDisposable()
            
            self.stateQueue.async {
                
                let paymentContext: PaymentTransactionContext? = self.paymentContexts[productIdentifier] ?? PaymentTransactionContext(subscriber: nil)
                
                paymentContext?.subscriber = { state in
                    switch state {
                        case let .purchased(transactionId), let .restored(transactionId):
                            if let transactionId = transactionId {
                                subscriber.putNext(.purchased(transactionId: transactionId))
                                subscriber.putCompletion()
                            } else {
                                subscriber.putError(.generic(nil))
                            }
                        case let .failed(transaction):
                            subscriber.putError(.generic(transaction))
                        case .deferred, .purchasing:
                            break
                    }
                }
                if let state = paymentContext?.state {
                    paymentContext?.subscriber?(state)
                }
                self.paymentContexts[productIdentifier] = paymentContext!
                
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
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        if let transaction = transactions.last {
            let productIdentifier = transaction.payment.productIdentifier
            self.stateQueue.async {
                let transactionState: TransactionState?
                switch transaction.transactionState {
                    case .purchased:
                        transactionState = .purchased(transactionId: transaction)
                    case .restored:
                        transactionState = .restored(transactionId: transaction)
                    case .failed:
                        transactionState = .failed(transactionId: transaction)
                    case .purchasing:
                        transactionState = .purchasing(transactionId: transaction)
                    case .deferred:
                        transactionState = .deferred
                    default:
                        transactionState = nil
                }
                if let transactionState = transactionState {
                    if let context = self.paymentContexts[productIdentifier] {
                        context.state = transactionState
                        context.subscriber?(transactionState)
                    } else {
                        let context = PaymentTransactionContext(subscriber: nil)
                        context.state = transactionState
                        self.paymentContexts[productIdentifier] = context
                    }
                }
            }
            for transaction in transactions {
                if transaction != transactions.last {
                    SKPaymentQueue.default().finishTransaction(transaction)
                }
            }
        }
    }
}
