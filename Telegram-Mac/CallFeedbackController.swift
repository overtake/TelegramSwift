//
//  CallFeedbackController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit

import TelegramCore


private final class CallFeedbackControllerArguments {
    let updateComment: (String) -> Void
    let scrollToComment: () -> Void
    let toggleReason: (CallFeedbackReason, Bool) -> Void
    let toggleIncludeLogs: (Bool) -> Void
    
    init(updateComment: @escaping (String) -> Void, scrollToComment: @escaping () -> Void, toggleReason: @escaping (CallFeedbackReason, Bool) -> Void, toggleIncludeLogs: @escaping (Bool) -> Void) {
        self.updateComment = updateComment
        self.scrollToComment = scrollToComment
        self.toggleReason = toggleReason
        self.toggleIncludeLogs = toggleIncludeLogs
    }
}


private enum CallFeedbackReason: Int32, CaseIterable {
    case videoDistorted
    case videoLowQuality
    
    case echo
    case noise
    case interruption
    case distortedSpeech
    case silentLocal
    case silentRemote
    case dropped
    
    var hashtag: String {
        switch self {
        case .echo:
            return "echo"
        case .noise:
            return "noise"
        case .interruption:
            return "interruptions"
        case .distortedSpeech:
            return "distorted_speech"
        case .silentLocal:
            return "silent_local"
        case .silentRemote:
            return "silent_remote"
        case .dropped:
            return "dropped"
        case .videoDistorted:
            return "distorted_video"
        case .videoLowQuality:
            return "pixelated_video"
        }
    }
    
    var isVideoRelated: Bool {
        switch self {
        case .videoDistorted, .videoLowQuality:
            return true
        default:
            return false
        }
    }
    
    var localizedString: String {
        switch self {
        case .echo:
            return strings().callFeedbackReasonEcho
        case .noise:
            return strings().callFeedbackReasonNoise
        case .interruption:
            return strings().callFeedbackReasonInterruption
        case .distortedSpeech:
            return strings().callFeedbackReasonDistortedSpeech
        case .silentLocal:
            return strings().callFeedbackReasonSilentLocal
        case .silentRemote:
            return strings().callFeedbackReasonSilentRemote
        case .dropped:
            return strings().callFeedbackReasonDropped
        case .videoDistorted:
            return strings().callFeedbackVideoReasonDistorted
        case .videoLowQuality:
            return strings().callFeedbackVideoReasonLowQuality
        }
    }
}

private struct CallFeedbackState: Equatable {
    let reasons: Set<CallFeedbackReason>
    let comment: String
    let includeLogs: Bool
    
    init(reasons: Set<CallFeedbackReason> = Set(), comment: String = "", includeLogs: Bool = true) {
        self.reasons = reasons
        self.comment = comment
        self.includeLogs = includeLogs
    }
    
    func withUpdatedReasons(_ reasons: Set<CallFeedbackReason>) -> CallFeedbackState {
        return CallFeedbackState(reasons: reasons, comment: self.comment, includeLogs: self.includeLogs)
    }
    
    func withUpdatedComment(_ comment: String) -> CallFeedbackState {
        return CallFeedbackState(reasons: self.reasons, comment: comment, includeLogs: self.includeLogs)
    }
    
    func withUpdatedIncludeLogs(_ includeLogs: Bool) -> CallFeedbackState {
        return CallFeedbackState(reasons: self.reasons, comment: self.comment, includeLogs: includeLogs)
    }
}

private func _id_reason(_ reason: CallFeedbackReason) -> InputDataIdentifier {
    return InputDataIdentifier.init("_id_reason_\(reason.hashtag)")
}
private let _id_comment: InputDataIdentifier = InputDataIdentifier("_id_comment")
private let _id_logs: InputDataIdentifier = InputDataIdentifier("_id_logs")

private func callFeedbackControllerEntries(state: CallFeedbackState, isVideo: Bool, arguments: CallFeedbackControllerArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().callFeedbackWhatWentWrong), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    let reasons = CallFeedbackReason.allCases.filter { value in
        if isVideo {
            return true
        } else if !isVideo && !value.isVideoRelated {
            return true
        }
        return false
    }
    for reason in reasons {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_reason(reason), data: .init(name: reason.localizedString, color: theme.colors.text, type: .switchable(state.reasons.contains(reason)), viewType: bestGeneralViewType(reasons, for: reason), action: {
            arguments.toggleReason(reason, !state.reasons.contains(reason))
        })))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.comment), error: nil, identifier: _id_comment, mode: .plain, data: .init(viewType: .singleItem, canMakeTransformations: false), placeholder: nil, inputPlaceholder: strings().callFeedbackAddComment, filter: { $0 }, limit: 255))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_logs, data: .init(name: strings().callFeedbackIncludeLogs, color: theme.colors.text, type: .switchable(state.includeLogs), viewType: .singleItem, action: {
        arguments.toggleIncludeLogs(!state.includeLogs)
    })))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().callFeedbackIncludeLogsInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries

}

func CallFeedbackController(context: AccountContext, callId: CallId, starsCount: Int, userInitiated: Bool, isVideo: Bool) -> ModalViewController {
    
    let initialState = CallFeedbackState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CallFeedbackState) -> CallFeedbackState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let arguments = CallFeedbackControllerArguments.init(updateComment: { value in
        updateState {
            $0.withUpdatedComment(value)
        }
    }, scrollToComment: {
        
    }, toggleReason: { reason, value in
        updateState { current in
            var reasons = current.reasons
            if value {
                reasons.insert(reason)
            } else {
                reasons.remove(reason)
            }
            return current.withUpdatedReasons(reasons)
        }
    }, toggleIncludeLogs: { value in
          updateState { $0.withUpdatedIncludeLogs(value) }
    })
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: callFeedbackControllerEntries(state: state, isVideo: isVideo, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().callFeedbackTitle)
    
    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: strings().modalSend, accept: { [weak controller] in
        controller?.validateInputValues()
        close?()
    }, singleButton: true)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })
    
    controller.updateDatas = { data in
        
        return .none
    }
    
    controller.validateData = { data in
        
        let state = stateValue.with { $0 }
        var comment = state.comment
        var hashtags = ""
        for reason in CallFeedbackReason.allCases {
            if state.reasons.contains(reason) {
                if !hashtags.isEmpty {
                    hashtags.append(" ")
                }
                hashtags.append("#\(reason.hashtag)")
            }
        }
        if !comment.isEmpty && !state.reasons.isEmpty {
            comment.append("\n")
        }
        comment.append(hashtags)
        
        let _ = rateCallAndSendLogs(context: context, callId: callId, starsCount: starsCount, comment: comment, userInitiated: userInitiated, includeLogs: state.includeLogs).start()
        
        return .success(.custom({
            close?()
        }))
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in f() }, size: NSMakeSize(300, 300))
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}
