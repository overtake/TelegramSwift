//
//  ValidateAddressNameInteractive.swift
//  Telegram
//
//  Created by keepcoder on 23/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox

enum AddressNameValidationStatus: Equatable {
    case checking
    case invalidFormat(AddressNameFormatError)
    case availability(AddressNameAvailability)

}

func validateAddressNameInteractive(account: Account, domain: AddressNameDomain, name: String) -> Signal<AddressNameValidationStatus, NoError> {
    if let error = checkAddressNameFormat(name) {
        return .single(.invalidFormat(error))
    } else {
        return .single(.checking) |> then(addressNameAvailability(account: account, domain: domain, name: name)
            |> delay(0.3, queue: Queue.concurrentDefaultQueue())
            |> map { result -> AddressNameValidationStatus in .availability(result) })
    }
}
