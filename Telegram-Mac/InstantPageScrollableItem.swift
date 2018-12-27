
import Foundation
import TelegramCoreMac
import PostboxMac
import TGUIKit

protocol InstantPageScrollableItem: class, InstantPageItem {
    var contentSize: CGSize { get }
    var horizontalInset: CGFloat { get }
    var isRTL: Bool { get }
    
    func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)?
}

private final class InstantPageScrollableContentViewParameters: NSObject {
    let item: InstantPageScrollableItem
    
    init(item: InstantPageScrollableItem) {
        self.item = item
        super.init()
    }
}

final class InstantPageScrollableContentView: View {
    let item: InstantPageScrollableItem
    
    init(item: InstantPageScrollableItem, additionalViews: [InstantPageView]) {
        self.item = item
        super.init()
        for case let view as NSView in additionalViews {
            self.addSubview(view)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        item.drawInTile(context: ctx)
    }

}




final class InstantPageScrollableView: ScrollView, InstantPageView {
    let item: InstantPageScrollableItem
    let contentNode: InstantPageScrollableContentView
    let containerView: View = View()

    
    override var hasVerticalScroller: Bool {
        get {
            return false
        }
        set {
            super.hasVerticalScroller = newValue
        }
    }

    
    override func scrollWheel(with event: NSEvent) {
        
        var scrollPoint = contentView.bounds.origin
        let isInverted: Bool = System.isScrollInverted
        
        if event.scrollingDeltaX != 0 {
            if !isInverted {
                scrollPoint.x += -event.scrollingDeltaX
            } else {
                scrollPoint.x -= event.scrollingDeltaX
            }
            
            scrollPoint.x = max(0, min(scrollPoint.x, (documentView!.frame.width) - contentSize.width))
            
            clipView.scroll(to: scrollPoint)
            
            
        } else {
            superview?.enclosingScrollView?.scrollWheel(with: event)
        }
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
      //  clipView.scroll(to: NSMakePoint(0, 0))
    }
    
    
//    @objc var contentOffset: NSPoint {
//        get {
//            return NSZeroPoint
//        }
//    }
    
    init(item: InstantPageScrollableItem, arguments: InstantPageItemArguments, additionalViews: [InstantPageView]) {
        self.item = item
        self.contentNode = InstantPageScrollableContentView(item: item, additionalViews: additionalViews)
        super.init(frame: NSZeroRect)
       // wantsLayer = true
        
        containerView.frame = CGRect(origin: CGPoint(x: 0, y: 0.0), size: NSMakeSize(item.contentSize.width + item.horizontalInset * 2, item.contentSize.height))
        containerView.backgroundColor = .clear
        self.contentNode.frame = CGRect(origin: CGPoint(x: item.horizontalInset, y: 0.0), size: item.contentSize)
        
        
        containerView.addSubview(contentNode)
        self.documentView = containerView
        
        if item.isRTL {
            self.contentView.scroll(to: CGPoint(x: containerView.frame.width - item.frame.width, y: 0.0))
           // self.contentOffset = CGPoint(x: self.contentSize.width - item.frame.width, y: 0.0)
        }
        
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    
    func updateHiddenMedia(media: InstantPageMedia?) {
    }
    

}
