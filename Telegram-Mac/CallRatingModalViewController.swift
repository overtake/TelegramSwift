//
//  CallRatingModalViewController.swift
//  Telegram
//
//  Created by keepcoder on 12/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac



private enum CallRatingState {
    case stars
    case feedback
}

private class CallRatingModalView: View {
    let rating:View = View()
    var starsChangeHandler:((Int32?)->Void)? = nil
    private(set) var stars:Int32? = nil
    var state:CallRatingState = .stars {
        didSet {
            if oldValue != state {
                feedback.setString("", animated: true)

                updateState(state, animated: true)
            }
        }
    }
    let feedback:TGModernGrowingTextView = TGModernGrowingTextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        var x:CGFloat = 0
        for i in 0 ..< 5 {
            let star = ImageButton()
            star.set(image: #imageLiteral(resourceName: "Icon_CallStar").precomposed(), for: .Normal)
            star.sizeToFit()
            star.setFrameOrigin(x, 0)
            rating.addSubview(star)
            x += floorToScreenPixels(scaleFactor: backingScaleFactor, star.frame.width) + 10
            
            star.set(handler: { [weak self] current in
                for j in 0 ... i {
                    (self?.rating.subviews[j] as? ImageButton)?.set(image: #imageLiteral(resourceName: "Icon_CallStar_Highlighted").precomposed(), for: .Normal)
                }
                for j in i + 1 ..< 5 {
                    (self?.rating.subviews[j] as? ImageButton)?.set(image: #imageLiteral(resourceName: "Icon_CallStar").precomposed(), for: .Normal)
                }
                self?.state = i < 4 ? .feedback : .stars
                self?.starsChangeHandler?( Int32(i + 1) )
            }, for: .Click)
        }
        rating.setFrameSize(x - 10, floorToScreenPixels(scaleFactor: backingScaleFactor, rating.subviews[0].frame.height))
        addSubview(rating)
        rating.center()
        
        feedback.setPlaceholderAttributedString(NSAttributedString.initialize(string: tr(L10n.callRatingModalPlaceholder), color: .grayText, font: .normal(.text)), update: false)
        
        feedback.textFont = NSFont.normal(FontSize.text)
        feedback.textColor = .text
        feedback.linkColor = .link
        feedback.max_height = 120
        
        feedback.setFrameSize(NSMakeSize(rating.frame.width, 34))
        
        addSubview(feedback)
        
        updateState(.stars)
    }
    
    override func layout() {
        super.layout()
        feedback.centerX(y: frame.height - feedback.frame.height - 10)
    }
    
    private func updateState(_ state:CallRatingState, animated: Bool = false) {
        switch state {
        case .stars:
            rating.change(pos: focus(rating.frame.size).origin, animated: animated)
            feedback._change(opacity: 0, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.feedback.isHidden = true
                }
            })
        case .feedback:
            rating.change(pos: NSMakePoint(rating.frame.minX, 20), animated: animated)
            feedback.isHidden = false
            feedback._change(opacity: 1, animated: animated)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func makeRatingView(_ rating:Int) {
        
    }
}

class CallRatingModalViewController: ModalViewController, TGModernGrowingDelegate {
    
    private let account:Account
    private let report:ReportCallRating
    private var starsCount:Int32? = nil
    private var comment:String = ""
    init(_ account:Account, report:ReportCallRating) {
        self.account = account
        self.report = report
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
        return ModalInteractions(acceptTitle: tr(L10n.modalOK), accept: { [weak self] in
            if let strongSelf = self, let stars = strongSelf.starsCount {
                _ = rateCall(account: strongSelf.account, report: strongSelf.report, starsCount: stars, comment: strongSelf.comment).start()
            }
            self?.close()
        }, cancelTitle: tr(L10n.modalCancel), drawBorder: true, height: 40)
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        modal?.resize(with:NSMakeSize(genericView.frame.width, genericView.feedback.frame.height + genericView.rating.frame.height + 40), animated: animated)
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    override func firstResponder() -> NSResponder? {
        return genericView.feedback
    }
    
    func textViewEnterPressed(_ event: NSEvent!) -> Bool {
        if FastSettings.checkSendingAbility(for: event) {
            return true
        }
        return false
    }
    
    func textViewTextDidChange(_ string: String!) {
        comment = string
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard!) -> Bool {
        return false
    }
    
    func textViewSize(_ textView: TGModernGrowingTextView!) -> NSSize {
        return NSMakeSize(genericView.feedback.frame.width, genericView.feedback.frame.height)
    }
    
    func textViewIsTypingEnabled() -> Bool {
        return true
    }
    
    func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        return 200
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        modal?.interactions?.updateEnables(false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.feedback.delegate = self
        textViewHeightChanged(34, animated: false)
        
        genericView.starsChangeHandler = { [weak self] stars in
            self?.modal?.interactions?.updateEnables(true)
            self?.starsCount = stars
        }
        readyOnce()
    }
}
