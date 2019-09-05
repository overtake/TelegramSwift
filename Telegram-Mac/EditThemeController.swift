//
//  EditThemeController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

private let _id_no_preview1 = InputDataIdentifier("_id_no_preview1")
private let _id_no_preview2 = InputDataIdentifier("_id_no_preview2")
private let _id_uploadFile = InputDataIdentifier("_id_uploadFile")
private let _id_input_title = InputDataIdentifier("_id_input_title")
private let _id_input_slug = InputDataIdentifier("_id_input_slug")

private struct EditThemeState : Equatable {
    let current: TelegramTheme
    let palette: ColorPalette
    let name: String
    let slug: String?
    let path: String?
    let errors:[InputDataIdentifier : InputDataValueError]
    init(current:TelegramTheme, palette: ColorPalette, name: String, slug: String?, path: String?, errors:[InputDataIdentifier : InputDataValueError]) {
        self.current = current
        self.palette = palette
        self.name = name
        self.slug = slug
        self.path = path
        self.errors = errors
    }
    func withUpdatedError(_ error: InputDataValueError?, for key: InputDataIdentifier) -> EditThemeState {
        var errors = self.errors
        if let error = error {
            errors[key] = error
        } else {
            errors.removeValue(forKey: key)
        }
        return EditThemeState(current: self.current, palette: self.palette, name: self.name, slug: self.slug, path: self.path, errors: errors)
    }
    func withUpdatedName(_ name: String) -> EditThemeState {
        return EditThemeState(current: self.current, palette: self.palette, name: name, slug: self.slug, path: self.path, errors: self.errors)
    }
    func withUpdatedSlug(_ slug: String?) -> EditThemeState {
        return EditThemeState(current: self.current, palette: self.palette, name: self.name, slug: slug, path: self.path, errors: self.errors)
    }
    func withUpdatedPath(_ path: String?) -> EditThemeState {
        return EditThemeState(current: self.current, palette: self.palette, name: self.name, slug: self.slug, path: path, errors: self.errors)
    }
    func withUpdatedPalette(_ palette: ColorPalette) -> EditThemeState {
        return EditThemeState(current: self.current, palette: palette, name: self.name, slug: self.slug, path: self.path, errors: self.errors)
    }
}

private final class EditThemeArguments {
    let context: AccountContext
    let updateFile:(String)->Void
    let updateSlug:(String)->Void
    init(context: AccountContext, updateFile:@escaping(String)->Void, updateSlug:@escaping(String)->Void) {
        self.context = context
        self.updateFile = updateFile
        self.updateSlug = updateSlug
    }
}

private func editThemeEntries(state: EditThemeState, arguments: EditThemeArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index:Int32 = 0
    
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(state.name), error: state.errors[_id_input_title], identifier: _id_input_title, mode: .plain, placeholder: nil, inputPlaceholder: L10n.editThemeNamePlaceholder, filter: { $0 }, limit: 128))
    index += 1

//    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(state.slug), error: state.errors[_id_input_slug], identifier: _id_input_slug, mode: .plain, placeholder: InputDataInputPlaceholder("t.me/addtheme/", hasLimitationText: true), inputPlaceholder: L10n.editThemeSlugPlaceholder, filter: { $0 }, limit: 64))
//    index += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .string(state.slug), identifier: _id_input_slug, equatable: InputDataEquatable(state.slug), item: { size, id in
        return UsernameInputRowItem(size, stableId: id, placeholder: "t.me/addtheme/", limit: 64, status: nil, text: state.slug ?? "", changeHandler: { updated in
            arguments.updateSlug(updated)
        }, holdText: true)
    }))
    index += 1
    
    let slugDesc = L10n.editThemeSlugDesc
    
    if let error = state.errors[_id_input_slug] {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(error.description), color: theme.colors.redUI, detectBold: true))
        index += 1
    } else {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(slugDesc), color: theme.colors.grayText, detectBold: true))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId, type: .custom(10)))
    sectionId += 1

    
    let previewTheme = theme.withUpdatedColors(state.palette)
    
    let chatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), context: arguments.context, disableSelectAbility: true)
    let fromUser1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
    let fromUser2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName2, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
    let replyMessage = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewZeroText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
    let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 20 + 60*60*18, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser2, text: tr(L10n.appearanceSettingsChatPreviewFirstText), attributes: [ReplyMessageAttribute(messageId: replyMessage.id)], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary([replyMessage.id : replyMessage]), associatedMessageIds: [])
    let firstEntry: ChatHistoryEntry = .MessageEntry(firstMessage, MessageIndex(firstMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil), nil, nil, nil, AutoplayMediaPreferences.defaultSettings)
    let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewSecondText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
    let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil), nil, nil, nil, AutoplayMediaPreferences.defaultSettings)
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_top"), equatable: InputDataEquatable(state.palette), item: { size, id in
        return GeneralRowItem(size, height: 10, stableId: id, backgroundColor: state.palette.background)
    }))
    index += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_no_preview1, equatable: InputDataEquatable(state.palette), item: { size, stableId in
        let item = ChatRowItem.item(size, from: firstEntry, interaction: chatInteraction, theme: previewTheme)
        item.forceBackgroundColor = state.palette.background
        _ = item.makeSize(size.width, oldWidth: 0)
        return item
    }))
    index += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_no_preview2, equatable: InputDataEquatable(state.palette), item: { size, stableId in
        let item = ChatRowItem.item(size, from: secondEntry, interaction: chatInteraction, theme: previewTheme)
        item.forceBackgroundColor = state.palette.background
        _ = item.makeSize(size.width, oldWidth: 0)
        return item
    }))
    index += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_bottom"), equatable: InputDataEquatable(state.palette), item: { size, id in
        return GeneralRowItem(size, height: 10, stableId: id, backgroundColor: state.palette.background)
    }))
    index += 1
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    let selectFileText: String
    let selectFileDesc: String

    if state.current.file == nil {
        selectFileText = L10n.editThemeSelectFile
        selectFileDesc = L10n.editThemeSelectFileDesc
    } else {
        selectFileText = L10n.editThemeSelectUpdatedFile
        selectFileDesc = L10n.editThemeSelectUpdatedFileDesc
    }
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_uploadFile, data: .init(name: selectFileText, color: theme.colors.blueText, type: .context(state.path ?? ""), action: {
        filePanel(with: ["palette"], allowMultiple: false, for: arguments.context.window, completion: { paths in
            if let first = paths?.first {
                arguments.updateFile(first)
            }
        })
    })))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(selectFileDesc), color: theme.colors.grayText, detectBold: true))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

 

    return entries
}

func EditThemeController(context: AccountContext, telegramTheme: TelegramTheme, palette: ColorPalette) -> InputDataModalController {
    let initialState = EditThemeState(current: telegramTheme, palette: palette, name: telegramTheme.title, slug: telegramTheme.slug, path: nil, errors: [:])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((EditThemeState) -> EditThemeState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    
    let slugDisposable = MetaDisposable()
    let disposable = MetaDisposable()

    
    func checkSlug(_ slug: String)->Void {
        if slug.length >= 5 && slug != telegramTheme.slug {
            let signal = getTheme(account: context.account, slug: slug) |> deliverOnMainQueue |> delay(0.2, queue: .mainQueue())
            slugDisposable.set(signal.start(next: { value in
                updateState {
                    $0.withUpdatedError(InputDataValueError(description: L10n.editThemeSlugErrorAlreadyExists, target: .data), for: _id_input_slug)
                }
            }, error: { error in
                switch error {
                case .slugInvalid:
                    updateState {
                        $0.withUpdatedError(InputDataValueError(description: L10n.editThemeSlugErrorFormat, target: .data), for: _id_input_slug)
                    }
                default:
                    updateState {
                        $0.withUpdatedError(nil, for: _id_input_slug)
                    }
                }
                
            }))
        } else {
            slugDisposable.set(nil)
            updateState {
                $0.withUpdatedError(nil, for: _id_input_slug)
            }
        }
    }
    
    let arguments = EditThemeArguments(context: context, updateFile: { path in
        if let palette = importPalette(path) {
            updateState {
                $0.withUpdatedPath(path).withUpdatedPalette(palette)
            }
        } else {
            alert(for: context.window, info: L10n.unknownError)
        }
        
    }, updateSlug: { slug in
        let oldSlug = stateValue.with { $0.slug }
        updateState { value in
            var value = value.withUpdatedSlug(slug)
            if oldSlug != slug {
                value = value.withUpdatedError(nil, for: _id_input_slug)
            }
            return value
        }
        if oldSlug != slug {
            checkSlug(slug)
        }
    })
    
    
    var close: (() -> Void)? = nil
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: editThemeEntries(state: state, arguments: arguments))
    }
    
    
    let save:()->InputDataValidation = {
        return .fail(.doSomething(next: { f in
            let state = stateValue.with { $0 }
            slugDisposable.set(nil)
            
            let slug = state.slug ?? ""
            
            var failed:[InputDataIdentifier : InputDataValidationFailAction] = [:]
            if !slug.isEmpty, slug.length < 5 {
                failed[_id_input_slug] = .shake
            }
            if state.name.isEmpty {
                failed[_id_input_title] = .shake
            }
            if !failed.isEmpty {
                f(.fail(.fields(failed)))
                return
            }
            
            var mediaResource: MediaResource? = nil
            var thumbnailData: Data? = nil
            var palette: ColorPalette = state.palette
            if let path = state.path {
                if let importedColors = importPalette(path)?.withUpdatedName(state.name) {
                    palette = importedColors
                    let temp = NSTemporaryDirectory() + "\(arc4random()).palette"
                    try? palette.toString.write(to: URL(fileURLWithPath: temp), atomically: true, encoding: .utf8)
                    mediaResource = LocalFileReferenceMediaResource(localFilePath: temp, randomId: arc4random64(), isUniquelyReferencedTemporaryFile: true, size: fs(temp))
                }
            } else {
                if state.current.file == nil {
                    let temp = NSTemporaryDirectory() + "'\(arc4random())'.palette"
                    try? palette.toString.write(to: URL(fileURLWithPath: temp), atomically: true, encoding: .utf8)
                    mediaResource = LocalFileReferenceMediaResource(localFilePath: temp, randomId: arc4random64(), isUniquelyReferencedTemporaryFile: true, size: fs(temp))
                }
            }
            if let _ = mediaResource {
                let preview = generateThemePreview(for: palette)
                if let mutableData = CFDataCreateMutable(nil, 0), let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, preview, nil)
                    if CGImageDestinationFinalize(destination) {
                        let data = mutableData as Data
                        thumbnailData = data
                    }
                }
            }
            
            let signal = updateTheme(account: context.account, accountManager: context.sharedContext.accountManager, theme: telegramTheme, title: state.name, slug: state.slug, resource: mediaResource, thumbnailData: thumbnailData)
            |> filter {
                switch $0 {
                case .progress:
                    return false
                case .result:
                    return true
                }
            }
            |> take(1)
            disposable.set(showModalProgress(signal: signal, for: context.window).start(next: { _ in
                delay(0.2, closure: {
                    close?()
                })
            }, error: { error in
                switch error {
                case .generic:
                    alert(for: context.window, info: L10n.unknownError)
                case .slugOccupied:
                    updateState {
                        $0.withUpdatedError(InputDataValueError(description: L10n.editThameNameAlreadyTaken, target: .data), for: _id_input_slug)
                    }
                    f(.fail(.fields([_id_input_slug : .shake])))
                case .slugInvalid:
                    updateState {
                        $0.withUpdatedError(InputDataValueError(description: L10n.editThemeSlugErrorFormat, target: .data), for: _id_input_slug)
                    }
                    f(.fail(.fields([_id_input_slug : .shake])))
                }
            }))
        }))
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.editThemeTitle, validateData: { data in
        
        return save()
        
    }, updateDatas: { data in
        updateState { value in
            let oldSlug = value.slug
            var value = value
            value = value.withUpdatedName(data[_id_input_title]?.stringValue ?? value.name)
                    .withUpdatedSlug(data[_id_input_slug]?.stringValue ?? oldSlug)
                    .withUpdatedError(nil, for: _id_input_title)
            if oldSlug != value.slug {
                value = value.withUpdatedError(nil, for: _id_input_slug)
                checkSlug(value.slug ?? "")
            }
            return value
        }
        return .none
    }, afterDisappear: {
        disposable.dispose()
        slugDisposable.dispose()
    }, afterTransaction: { controller in
        
    })
    
    
    let modalInteractions = ModalInteractions(acceptTitle: L10n.editThemeEdit, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, cancelTitle: L10n.modalCancel, drawBorder: true, height: 50)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


func showEditThemeModalController(context: AccountContext, theme telegramTheme: TelegramTheme) {
    if let file = telegramTheme.file {
        
        
        let fetchDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: MediaResourceReference.standalone(resource: file.resource)).start()
        
        let resourceData = context.account.postbox.mediaBox.resourceData(file.resource) |> filter { $0.complete } |> take(1) |> afterDisposed {
            fetchDisposable.dispose()
        }
        
        _ = showModalProgress(signal: resourceData, for: context.window).start(next: { data in
            if let palette = importPalette(data.path) {
                showModal(with: EditThemeController(context: context, telegramTheme: telegramTheme, palette: palette), for: context.window)
            } else {
                alert(for: context.window, info: L10n.unknownError)
            }
        })
        
    } else {
        showModal(with: EditThemeController(context: context, telegramTheme: telegramTheme, palette: theme.colors), for: context.window)
    }
}


