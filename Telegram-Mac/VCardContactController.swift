//
//  VCardContactController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/07/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import Contacts
import SwiftSignalKit
//
//private class VCardContactView : View {
//    let tableView: TableView = TableView(frame: NSZeroRect)
//    private let title: TextView = TextView()
//    private let separator : View = View()
//    required init(frame frameRect: NSRect) {
//        super.init(frame: frameRect)
//        addSubview(title)
//        addSubview(tableView)
//        addSubview(separator)
//        separator.backgroundColor = theme.colors.border
//        
//        self.title.update(TextViewLayout(.initialize(string: "Contact", color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1))
//        needsLayout = true
//    }
//    
//    
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    override func layout() {
//        super.layout()
//        tableView.frame = NSMakeRect(0, 50, frame.width, frame.height - 50)
//        title.layout?.measure(width: frame.width - 60)
//        title.update(title.layout)
//        title.centerX(y: floorToScreenPixels(backingScaleFactor, (50 - title.frame.height) / 2))
//        separator.frame = NSMakeRect(0, 49, frame.width, .borderSize)
//    }
//}
//
//private final class VCardArguments {
//    let account: Account
//    init(account: Account) {
//        self.account = account
//    }
//}
//
//private func vCardEntries(vCard: CNContact, contact: TelegramMediaContact, arguments: VCardArguments) -> [InputDataEntry] {
//    
//    var entries: [InputDataEntry] = []
//    var sectionId:Int32 = 0
//    var index: Int32 = 0
//    
//    func getLabel(_ key: String) -> String {
//        
//        switch key {
//        case "_$!<HomePage>!$_":
//            return L10n.contactInfoURLLabelHomepage
//        case "_$!<Home>!$_":
//            return L10n.contactInfoPhoneLabelHome
//        case "_$!<Work>!$_":
//            return L10n.contactInfoPhoneLabelWork
//        case "_$!<Mobile>!$_":
//            return L10n.contactInfoPhoneLabelMobile
//        case "_$!<Main>!$_":
//            return L10n.contactInfoPhoneLabelMain
//        case "_$!<HomeFax>!$_":
//            return L10n.contactInfoPhoneLabelHomeFax
//        case "_$!<WorkFax>!$_":
//            return L10n.contactInfoPhoneLabelWorkFax
//        case "_$!<Pager>!$_":
//            return L10n.contactInfoPhoneLabelPager
//        case "_$!<Other>!$_":
//            return L10n.contactInfoPhoneLabelOther
//        default:
//            return L10n.contactInfoPhoneLabelOther
//        }
//    }
//    
//    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("header"), equatable: nil, item: { initialSize, stableId -> TableRowItem in
//        return VCardHeaderItem(initialSize, stableId: stableId, account: arguments.account, vCard: vCard, contact: contact)
//    }))
//    index += 1
//    
//    for phoneNumber in vCard.phoneNumbers {
//        if let label = phoneNumber.label {
//            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("phone_\(phoneNumber.identifier)"), equatable: nil, item: { initialSize, stableId -> TableRowItem in
//                return TextAndLabelItem(initialSize, stableId: stableId, label: getLabel(label), text: phoneNumber.value.stringValue, account: arguments.account)
//            }))
//        }
//        index += 1
//    }
//    
//    for email in vCard.emailAddresses {
//        if let label = email.label {
//            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("email_\(email.identifier)"), equatable: nil, item: { initialSize, stableId -> TableRowItem in
//                return TextAndLabelItem(initialSize, stableId: stableId, label: getLabel(label), text: email.value as String, account: arguments.account)
//            }))
//        }
//        index += 1
//    }
//    
//    for address in vCard.urlAddresses {
//        if let label = address.label {
//            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("url_\(address.identifier)"), equatable: nil, item: { initialSize, stableId -> TableRowItem in
//                return TextAndLabelItem(initialSize, stableId: stableId, label: getLabel(label), text: address.value as String, account: arguments.account)
//            }))
//        }
//        index += 1
//    }
//    
//    for address in vCard.postalAddresses {
//        if let label = address.label {
//            let text: String = address.value.street + "\n" + address.value.city + "\n" + address.value.country
//            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("url_\(address.identifier)"), equatable: nil, item: { initialSize, stableId -> TableRowItem in
//                return TextAndLabelItem(initialSize, stableId: stableId, label: getLabel(label), text: text, account: arguments.account)
//            }))
//        }
//        index += 1
//    }
//    
//    if let birthday = vCard.birthday {
//        let date = Calendar.current.date(from: birthday)!
//        
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateStyle = .long
//        
//        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("birthday"), equatable: nil, item: { initialSize, stableId -> TableRowItem in
//            return TextAndLabelItem(initialSize, stableId: stableId, label: L10n.contactInfoBirthdayLabel, text: dateFormatter.string(from: date), account: arguments.account)
//        }))
//        index += 1
//    }
//    
//    for social in vCard.socialProfiles {
//        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("social_\(social.identifier)"), equatable: nil, item: { initialSize, stableId -> TableRowItem in
//            return TextAndLabelItem(initialSize, stableId: stableId, label: social.value.service, text: social.value.urlString, account: arguments.account)
//        }))
//    }
//    
//    for social in vCard.instantMessageAddresses {
//        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("instant_\(social.identifier)"), equatable: nil, item: { initialSize, stableId -> TableRowItem in
//            return TextAndLabelItem(initialSize, stableId: stableId, label: social.value.service, text: social.value.username, account: arguments.account)
//        }))
//    }
//    
//
//    return entries
//}
//
//
//final class VCardModalController : ModalViewController {
//    private let controller: NavigationViewController
//    init(_ account: Account, vCard: CNContact, contact: TelegramMediaContact) {
//        self.controller = VCardContactController(account, vCard: vCard, contact: contact)
//        super.init(frame: controller._frameRect)
//    }
//    
//    public override var handleEvents: Bool {
//        return true
//    }
//    
//    public override func firstResponder() -> NSResponder? {
//        return controller.controller.firstResponder()
//    }
//    
//    public override func returnKeyAction() -> KeyHandlerResult {
//        return controller.controller.returnKeyAction()
//    }
//    
//    public override var haveNextResponder: Bool {
//        return true
//    }
//    
//    public override func nextResponder() -> NSResponder? {
//        return controller.controller.nextResponder()
//    }
//    
//    var input: InputDataController {
//        return controller.controller as! InputDataController
//    }
//    
//    public override func viewDidLoad() {
//        super.viewDidLoad()
//        ready.set(controller.ready.get())
//    }
//    
//    override var view: NSView {
//        if !controller.isLoaded() {
//            controller.loadViewIfNeeded()
//            viewDidLoad()
//        }
//        return controller.view
//    }
//    
//    override var modalInteractions: ModalInteractions? {
//        return ModalInteractions(acceptTitle: L10n.modalOK)
//    }
//    
//    override func measure(size: NSSize) {
//        self.modal?.resize(with:NSMakeSize(380, min(size.height - 70, input.genericView.listHeight + 70)), animated: false)
//    }
//    
//    public func updateSize(_ animated: Bool) {
//        if let contentSize = self.modal?.window.contentView?.frame.size {
//            self.modal?.resize(with:NSMakeSize(380, min(contentSize.height - 70, input.genericView.listHeight + 70)), animated: animated)
//        }
//    }
//    override var dynamicSize: Bool {
//        return true
//    }
//    
//}
//
//private class VCardContactController: NavigationViewController {
//
////    override func viewClass() -> AnyClass {
////        return VCardContactView.self
////    }
//    
//    fileprivate let context: AccountContext
//    fileprivate let vCard: CNContact
//    fileprivate let contact: TelegramMediaContact
//    fileprivate let input: InputDataController
//    fileprivate let values: Promise<[InputDataEntry]> = Promise()
//    init(_ account: Account, vCard: CNContact, contact: TelegramMediaContact) {
//        self.account = account
//        self.vCard = vCard
//        self.contact = contact
//        input = InputDataController(dataSignal: values.get() |> map {($0, true)}, title: L10n.contactInfoContactInfo, hasDone: false)
//        super.init(input)
//        self._frameRect = NSMakeRect(0, 0, 380, 500)
//    }
//    
//   
//    
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        ready.set(input.ready.get())
//        let arguments = VCardArguments(account: account)
//        let vCard = self.vCard
//        let contact = self.contact
//        
//        values.set(appearanceSignal |> deliverOnPrepareQueue |> map { _ in return vCardEntries(vCard: vCard, contact: contact, arguments: arguments)})
//    }
//    
////    private var genericView:VCardContactView {
////        return self.view as! VCardContactView
////    }
//    
//}
