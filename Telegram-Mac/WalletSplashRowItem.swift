////
////  WalletSplashRowItem.swift
////  Telegram
////
////  Created by Mikhail Filimonov on 19/09/2019.
////  Copyright © 2019 Telegram. All rights reserved.
////
//
//import Cocoa
//import TGUIKit
//import TelegramCore
//import SyncCore
//
//
//@available (OSX 10.12, *)
//class WalletSplashRowItem: GeneralRowItem {
//    fileprivate let descLayout: TextViewLayout
//    fileprivate let titleLayout: TextViewLayout
//    fileprivate let animation: LocalAnimatedSticker?
//    fileprivate let context: AccountContext
//    private var h: CGFloat = 0
//    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, title: String, desc: String, animation: LocalAnimatedSticker?, viewType: GeneralViewType, action:@escaping(String)->Void) {
//        self.context = context
//        self.animation = animation
//        
//        let attributedText: NSMutableAttributedString = parseMarkdownIntoAttributedString(desc, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.listGrayText), bold: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.listGrayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
//            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, action))
//        })).mutableCopy() as! NSMutableAttributedString
//        
//        attributedText.detectBoldColorInString(with: .medium(.text))
//        
//        self.descLayout = TextViewLayout(attributedText, alignment: .center)
//        
//        self.titleLayout = TextViewLayout(.initialize(string: title, color: theme.colors.text, font: .medium(22)), alignment: .center)
//
//        
//        self.descLayout.interactions = globalLinkExecutor
//        
//        super.init(initialSize, stableId: stableId, viewType: viewType)
//        _ = makeSize(initialSize.width, oldWidth: 0)
//    }
//    
//    override var height: CGFloat {
//        return self.h
//    }
//    
//    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
//        _ = super.makeSize(width, oldWidth: oldWidth)
//        
//        self.descLayout.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
//        self.titleLayout.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
////
//        var height: CGFloat = self.descLayout.layoutSize.height + self.titleLayout.layoutSize.height + self.viewType.innerInset.top
//        
//        if let _ = self.animation {
//            height += (20 + 140)
//        }
//        self.h = height
//        
//        return true
//    }
//    
//    override func viewClass() -> AnyClass {
//        return WalletIntroRowView.self
//    }
//}
//
//
//@available (OSX 10.12, *)
//private final class WalletIntroRowView : TableRowView {
//    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
//    private let titleView = TextView()
//    private let descView = TextView()
//    private let animationView: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSZeroRect)
//    required init(frame frameRect: NSRect) {
//        super.init(frame: frameRect)
//        containerView.addSubview(animationView)
//        containerView.addSubview(titleView)
//        containerView.addSubview(descView)
//        titleView.isSelectable = false
//        descView.isSelectable = false
//        addSubview(containerView)
//    }
//    
//    override var backdorColor: NSColor {
//        return theme.colors.listBackground
//    }
//    
//    override func updateColors() {
//        guard let item = item as? WalletSplashRowItem else {
//            return
//        }
//        self.backgroundColor = item.viewType.rowBackground
//        self.titleView.background = backdorColor
//        self.descView.background = backdorColor
//        self.containerView.backgroundColor = backdorColor
//    }
//    
//    override func layout() {
//        super.layout()
//        guard let item = item as? WalletSplashRowItem else {
//            return
//        }
//        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
//        self.containerView.setCorners(item.viewType.corners)
//        
//        animationView.centerX(y: 0)
//        if item.animation != nil {
//            titleView.centerX(y: animationView.frame.maxY + 20)
//        } else {
//            titleView.centerX(y: 0)
//        }
//        descView.centerX(y: titleView.frame.maxY + item.viewType.innerInset.top)
//
//    }
//    
//    override func set(item: TableRowItem, animated: Bool = false) {
//        super.set(item: item, animated: animated)
//        
//        guard let item = item as? WalletSplashRowItem else {
//            return
//        }
//        titleView.update(item.titleLayout)
//        descView.update(item.descLayout)
//        if let animation = item.animation?.file {
//            animationView.update(with: animation, size: NSMakeSize(140, 140), context: item.context, parent: nil, table: item.table, parameters: item.animation?.parameters, animated: animated, positionFlags: nil, approximateSynchronousValue: !animated)
//        }
//        
//        needsLayout = true
//    }
//    
//    override var firstResponder: NSResponder? {
//        return nil
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//}
