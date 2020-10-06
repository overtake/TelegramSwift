//
//  CallRatingModalViewController.swift
//  Telegram
//
//  Created by keepcoder on 12/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox



private enum CallRatingState {
    case stars
}

private class CallRatingModalView: View {
    let rating:View = View()
    let textView = TextView()
    var starsChangeHandler:((Int32?)->Void)? = nil
    private(set) var stars:Int32? = nil
    var state:CallRatingState = .stars {
        didSet {
            if oldValue != state {
                updateState(state, animated: true)
            }
        }
    }
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        var x:CGFloat = 0
        for i in 0 ..< 5 {
            let star = ImageButton()
            star.set(image: #imageLiteral(resourceName: "Icon_CallStar").precomposed(), for: .Normal)
            star.sizeToFit()
            star.setFrameOrigin(x, 0)
            rating.addSubview(star)
            x += floorToScreenPixels(backingScaleFactor, star.frame.width) + 10
            
            star.set(handler: { [weak self] current in
                for j in 0 ... i {
                    (self?.rating.subviews[j] as? ImageButton)?.set(image: #imageLiteral(resourceName: "Icon_CallStar_Highlighted").precomposed(), for: .Normal)
                }
                for j in i + 1 ..< 5 {
                    (self?.rating.subviews[j] as? ImageButton)?.set(image: #imageLiteral(resourceName: "Icon_CallStar").precomposed(), for: .Normal)
                }
                self?.state = .stars
                delay(0.15, closure: {
                    self?.starsChangeHandler?( Int32(i + 1) )
                })
            }, for: .Click)
        }
        rating.setFrameSize(x - 10, floorToScreenPixels(backingScaleFactor, rating.subviews[0].frame.height))
        addSubview(rating)
        addSubview(textView)
        
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
        updateState(.stars)
        
        let layout = TextViewLayout(.initialize(string: L10n.callRatingModalText, color: theme.colors.text, font: .medium(.text)), alignment: .center)
        layout.measure(width: frame.width - 60)
        
        textView.update(layout)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        rating.centerX(y: frame.midY + 5)
        textView.centerX(y: frame.midY - textView.frame.height - 5)
    }
    
    private func updateState(_ state:CallRatingState, animated: Bool = false) {
        switch state {
        case .stars:
            rating.change(pos: focus(rating.frame.size).origin, animated: animated)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func makeRatingView(_ rating:Int) {
        
    }
}

class CallRatingModalViewController: ModalViewController {
    
    private let account:Account
    private let callId:CallId
    private var starsCount:Int32? = nil
    private let isVideo: Bool
    private let userInitiated: Bool
    init(_ account: Account, callId:CallId, userInitiated: Bool, isVideo: Bool) {
        self.account = account
        self.callId = callId
        self.isVideo = isVideo
        self.userInitiated = userInitiated
        super.init(frame: NSMakeRect(0, 0, 260, 100))
        bar = .init(height: 0)
    }
    
    private var genericView:CallRatingModalView {
        return view as! CallRatingModalView
    }
    
    
    override func viewClass() -> AnyClass {
        return CallRatingModalView.self
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.callRatingModalNotNow, drawBorder: true, height: 50, singleButton: true)
    }
    

    override func becomeFirstResponder() -> Bool? {
        return true
    }

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.starsChangeHandler = { [weak self] stars in
            if let stars = stars {
                self?.saveRating(Int(stars))
            }
        }
        readyOnce()
    }
    
    private func saveRating(_ starsCount: Int) {
        self.close()
        if starsCount < 4, let window = self.window {
            showModal(with: CallFeedbackController(account: account, callId: callId, starsCount: starsCount, userInitiated: userInitiated, isVideo: isVideo), for: window)
        } else {
            let _ = rateCallAndSendLogs(account: account, callId: self.callId, starsCount: starsCount, comment: "", userInitiated: userInitiated, includeLogs: false).start()
        }
    }
}


func rateCallAndSendLogs(account: Account, callId: CallId, starsCount: Int, comment: String, userInitiated: Bool, includeLogs: Bool) -> Signal<Void, NoError> {
    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 4244000)
    
    let rate = rateCall(account: account, callId: callId, starsCount: Int32(starsCount), comment: comment, userInitiated: userInitiated)
    if includeLogs {
        let id = arc4random64()
        let name = "\(callId.id)_\(callId.accessHash).log.json"
        let path = callLogsPath(account: account) + "/" + name
        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)])
        let message = EnqueueMessage.message(text: comment, attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil)
        return rate
            |> then(enqueueMessages(account: account, peerId: peerId, messages: [message])
                |> mapToSignal({ _ -> Signal<Void, NoError> in
                    return .single(Void())
                }))
    } else if !comment.isEmpty {
        return rate
            |> then(enqueueMessages(account: account, peerId: peerId, messages: [.message(text: comment, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)])
                |> mapToSignal({ _ -> Signal<Void, NoError> in
                    return .single(Void())
                }))
    } else {
        return rate
    }
}
