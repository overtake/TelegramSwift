import Foundation
import TelegramCoreMac

enum SecureIdVerificationLocalDocumentState {
    case uploading(Float)
    case uploaded(UploadedSecureIdFile)
    
    func isEqual(to: SecureIdVerificationLocalDocumentState) -> Bool {
        switch self {
            case let .uploading(progress):
                if case .uploading(progress) = to {
                    return true
                } else {
                    return false
                }
            case let .uploaded(file):
                if case .uploaded(file) = to {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct SecureIdVerificationLocalDocument {
    let id: Int64
    let resource: TelegramMediaResource
    var state: SecureIdVerificationLocalDocumentState
    
    func isEqual(to: SecureIdVerificationLocalDocument) -> Bool {
        if self.id != to.id {
            return false
        }
        if !self.resource.isEqual(to: to.resource) {
            return false
        }
        if !self.state.isEqual(to: to.state) {
            return false
        }
        return true
    }
}

enum SecureIdVerificationDocumentId: Hashable {
    case remote(Int64)
    case local(Int64)
    
    static func ==(lhs: SecureIdVerificationDocumentId, rhs: SecureIdVerificationDocumentId) -> Bool {
        switch lhs {
            case let .remote(id):
                if case .remote(id) = rhs {
                    return true
                } else {
                    return false
                }
            case let .local(id):
                if case .local(id) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .local(id):
                return Int(id)
            case let .remote(id):
                return Int(id)
        }
    }
}

enum SecureIdVerificationDocument : Equatable {
    case remote(SecureIdFileReference)
    case local(SecureIdVerificationLocalDocument)
    
    var id: SecureIdVerificationDocumentId {
        switch self {
            case let .remote(file):
                return .remote(file.id)
            case let .local(file):
                return .local(file.id)
        }
    }
    
    var resource: TelegramMediaResource {
        switch self {
            case let .remote(file):
                return SecureFileMediaResource(file: file)
            case let .local(file):
                return file.resource
        }
    }
    
    func isEqual(to: SecureIdVerificationDocument) -> Bool {
        switch self {
            case let .remote(reference):
                if case .remote(reference) = to {
                    return true
                } else {
                    return false
                }
            case let .local(lhsDocument):
                if case let .local(rhsDocument) = to, lhsDocument.isEqual(to: rhsDocument) {
                    return true
                } else {
                    return false
                }
        }
    }
    static func ==(lhs: SecureIdVerificationDocument, rhs: SecureIdVerificationDocument) -> Bool {
        return lhs.isEqual(to: rhs)
    }
}
