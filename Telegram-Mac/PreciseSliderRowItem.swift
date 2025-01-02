import Cocoa
import TGUIKit



final class PrecieSliderRowItem : GeneralRowItem {
    fileprivate let update:(CGFloat)->Void
    fileprivate let current: CGFloat
    fileprivate let magnit: [CGFloat]
    fileprivate let markers: [String]
    fileprivate let showValue: String?
    fileprivate let minValue: CGFloat
    init(_ initialSize: NSSize, stableId: AnyHashable, current: CGFloat, minValue: CGFloat = 0, magnit: [CGFloat] = [], markers: [String] = [], showValue: String? = nil, update: @escaping(CGFloat)->Void, viewType: GeneralViewType) {
        self.markers = markers
        self.current = current
        self.magnit = magnit
        self.update = update
        self.showValue = showValue
        self.minValue = minValue
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    
    override var height: CGFloat {
        return markers.isEmpty && showValue == nil ? 40 : 40 + 20
    }
    
    override func viewClass() -> AnyClass {
        return PrecieSliderRowView.self
    }
}

private final class PrecieSliderRowView : GeneralContainableRowView {
    private let slider = LinearProgressControl(progressHeight: 3)
    private var leftMarker: TextView?
    private var rightMarker: TextView?
    private var currentValue: TextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(slider)
        
        slider.scrubberImage = generateImage(NSMakeSize(20, 20), contextGenerator: { size, ctx in
            let rect = CGRect(origin: .zero, size: size)
            
 
            ctx.clear(rect)
            
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fillEllipse(in: size.bounds)

            ctx.setFillColor(theme.colors.background.cgColor)
            ctx.fillEllipse(in: size.bounds.insetBy(dx: 1, dy: 1))

            
            // Restore graphics state
            ctx.restoreGState()
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PrecieSliderRowItem else {
            return
        }
        
        slider.roundCorners = true
        slider.alignment = .center
        slider.containerBackground = theme.colors.grayText
        slider.style = ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: .clear, highlightColor: .clear)
        slider.fetchingColor = theme.colors.grayText
        slider.set(progress: item.current)
        slider.set(fetchingProgress: item.current)
        
        slider.onUserChanged = { [weak item] value in
            item?.update(CGFloat(value))
        }
        slider.onLiveScrobbling = { [weak item] value in
            if let value {
                item?.update(CGFloat(value))
            }
        }
        
        if !item.markers.isEmpty {
            do {
                let current: TextView
                if let view = self.leftMarker {
                    current = view
                } else {
                    current = TextView()
                    current.isSelectable = false
                    current.userInteractionEnabled = false
                    self.addSubview(current)
                    self.leftMarker = current
                    
                }
                let leftLayout = TextViewLayout(.initialize(string: item.markers[0], color: theme.colors.grayText, font: .normal(.text)))
                leftLayout.measure(width: .greatestFiniteMagnitude)
                current.update(leftLayout)
            }
            
            do {
                let current: TextView
                if let view = self.rightMarker {
                    current = view
                } else {
                    current = TextView()
                    current.isSelectable = false
                    current.userInteractionEnabled = false
                    self.addSubview(current)
                    self.rightMarker = current
                    
                }
                let rightLayout = TextViewLayout(.initialize(string: item.markers[1], color: theme.colors.grayText, font: .normal(.text)))
                rightLayout.measure(width: .greatestFiniteMagnitude)
                current.update(rightLayout)
            }
        } else {
            if let view = self.leftMarker {
                performSubviewRemoval(view, animated: animated)
                self.leftMarker = nil
            }
            if let view = self.rightMarker {
                performSubviewRemoval(view, animated: animated)
                self.rightMarker = nil
            }
        }
        
        if let showValue = item.showValue {
            do {
                let current: TextView
                if let view = self.currentValue {
                    current = view
                } else {
                    current = TextView()
                    current.isSelectable = false
                    current.userInteractionEnabled = false
                    self.addSubview(current)
                    self.currentValue = current
                    
                }
                let layout = TextViewLayout(.initialize(string: showValue, color: theme.colors.text, font: .normal(.title)))
                layout.measure(width: .greatestFiniteMagnitude)
                current.update(layout)
            }
        } else {
            if let view = self.currentValue {
                performSubviewRemoval(view, animated: animated)
                self.currentValue = nil
            }
        }

        needsLayout = true

    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PrecieSliderRowItem else {
            return
        }
        
        var rect = containerView.focus(NSMakeSize(containerView.frame.width - 40, 20))

        if item.showValue != nil || !item.markers.isEmpty {
            rect.origin.y = containerView.frame.height - rect.height - 10
        }
        
        if let leftMarker, let rightMarker {
            leftMarker.setFrameOrigin(NSMakePoint(rect.minX, rect.minY - leftMarker.frame.height - 5))
            rightMarker.setFrameOrigin(NSMakePoint(rect.maxX - rightMarker.frame.width, rect.minY - rightMarker.frame.height - 5))
        }
        
        
        if let currentValue = currentValue {
            currentValue.centerX(y: rect.minY - currentValue.frame.height - 5)
        }
        
        slider.frame = rect
    }
}
