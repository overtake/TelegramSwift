import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

/*fileprivate func prepareEntries() -> Signal<TableUpdateTransition, NoError>{
    return Signal { subscriber in
        
    }
}*/

class UpdatedNavigationViewController: NavigationViewController {
    var callback:(() -> Void)?
    override func currentControllerDidChange() {
        callback?()
    }
}
             
final class CirclesArguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

enum CirclesTableEntryStableId : Hashable {
    case group(PeerGroupId)
    case sectionId
    var hashValue: Int {
        switch self {
        case .group(let groupId):
            return groupId.hashValue
        case .sectionId:
            return -1
        }
    }
}

enum CirclesTableEntry : TableItemListNodeEntry {
    case group(groupId: PeerGroupId, title: String)
    case sectionId
    
    var stableId:CirclesTableEntryStableId {
        switch self {
        case .sectionId:
            return .sectionId
        case .group(let groupId, _):
            return .group(groupId)
        }
    }
    
    func item(_ arguments: CirclesArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .sectionId:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .group(groupId, title):
            return CirclesRowItem(initialSize, stableId: stableId, groupId: groupId, title: title)
            
        }
    }
}
        
func <(lhs:CirclesTableEntry, rhs:CirclesTableEntry) -> Bool {
    return lhs.stableId.hashValue < rhs.stableId.hashValue
}

private func circlesControllerEntries(settings: Circles?) -> [CirclesTableEntry] {
    var entries: [CirclesTableEntry] = []
    
    entries.append(.sectionId)
    entries.append(.group(groupId: PeerGroupId(rawValue: 0), title: "Personal"))
    if let settings = settings {
        for key in settings.groupNames.keys {
            entries.append(.group(groupId: key, title: settings.groupNames[key]!))
        }
    }
    
    entries.append(.group(groupId: Namespaces.PeerGroup.archive, title: "Archived"))
    return entries
}

class CirclesRowView: TableRowView {
    private let titleTextView:TextView
    private let iconView:ImageView
    
    required init(frame frameRect: NSRect) {
        iconView = ImageView(frame: NSMakeRect(16, 0, 48, 48))
        iconView.layer?.contentsGravity = .resizeAspect
        titleTextView = TextView(frame: NSMakeRect(5, 55, 70, 20))
        
        super.init(frame: frameRect)
        addSubview(titleTextView)
        addSubview(iconView)
        iconView.layer?.cornerRadius = 10
        iconView.layer?.borderWidth = 2
        iconView.layer?.borderColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
        //iconView.wantsLayer = true
        titleTextView.isSelectable = false
        titleTextView.isEventLess = true
        titleTextView.userInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return NSColor(red: 0x19/255, green: 0x13/255, blue: 0x3c/255, alpha: 1)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? CirclesRowItem {
            let icon:CGImage = {
                switch item.groupId {
                case .group(0),.root:
                    return #imageLiteral(resourceName: "Icon_CirclePersonal").precomposed()
                case .group(1):
                    return #imageLiteral(resourceName: "Icon_CircleArchived").precomposed()
                default:
                    return #imageLiteral(resourceName: "Icon_CircleCustom").precomposed()
                }
            }()
            iconView.image = icon
            if item.isSelected {
                iconView.layer?.backgroundColor = theme.colors.accent.cgColor
            } else {
                iconView.layer?.backgroundColor = NSColor(red: 0x7a/255, green: 0x7d/255, blue: 0x94/255, alpha: 1).cgColor
            }
            titleTextView.update(item.title)
            needsLayout = true
        }
    }
    
    override func layout() {
        super.layout()
        if let item = item as? CirclesRowItem {
            titleTextView.update(item.title, origin: NSMakePoint(5, 54))
            titleTextView.centerX()
        }
        
    }
}

class CirclesRowItem: TableRowItem {
    //let groupId: PeerGroupId
    public let title: TextViewLayout
    public let groupId: PeerGroupId
    
    fileprivate let _stableId:AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
    
    init(_ initialSize:NSSize, stableId: CirclesTableEntryStableId, groupId: PeerGroupId, title:String) {
        self.groupId = groupId
        self._stableId = stableId
        self.title = TextViewLayout(
            .initialize(
                string: title,
                color: theme.colors.text,
                font: .normal(.short)
            ),
            constrainedWidth: 70,
            maximumNumberOfLines: 1,
            alignment: .center
        )
        super.init(initialSize)
        _ = makeSize(70, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        title.measure(width: width)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return CirclesRowView.self
    }
    override var height: CGFloat {
        return 80
    }
    
    
}

class CirclesListView: View {
    var tableView = TableView(frame:NSZeroRect, drawBorder: true) {
       didSet {
           oldValue.removeFromSuperview()
           addSubview(tableView)
       }
    }

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        //autoresizesSubviews = false
        addSubview(tableView)
    }
    
    override func layout() {
        super.layout()
        setFrameOrigin(0,0)
        setFrameSize(frame.width, frame.height)
        tableView.setFrameSize(frame.width, frame.height)
        tableView.setFrameOrigin(0,0)
        
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0x19/255, green: 0x13/255, blue: 0x3c/255, alpha: 1).cgColor
        
        tableView.layer?.backgroundColor = .clear
        //tableView.backgroundColor = NSColor(red: 0x19/255, green: 0x13/255, blue: 0x3c/255, alpha: 1)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<CirclesTableEntry>], right: [AppearanceWrapperEntry<CirclesTableEntry>], initialSize:NSSize, arguments: CirclesArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class CirclesController: TelegramGenericViewController<CirclesListView>, TableViewDelegate {
    
    private let disposable = MetaDisposable()
    var chatListNavigationController:UpdatedNavigationViewController
    var tabController:TabBarController
    
    init(context: AccountContext, chatListNavigationController: UpdatedNavigationViewController, tabController: TabBarController) {
        self.chatListNavigationController = chatListNavigationController
        self.tabController = tabController
        super.init(context)

    }
    
    func select(groupId:PeerGroupId?) {
        if let groupId = groupId {
            if let item = genericView.tableView.item(stableId: CirclesTableEntryStableId.group(groupId)) {
                genericView.tableView.select(item: item, notify: false)
            }
        } else {
            if let item = genericView.tableView.item(stableId: CirclesTableEntryStableId.sectionId) {
                genericView.tableView.select(item: item, notify: false)
            }
        }
    }
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
        if let item = item as? CirclesRowItem {
            let controller = ChatListController(context, modal: false, groupId: item.groupId)
            //self.chatListNavigationController.stackInsert(controller, at: 0)
            self.tabController.select(index: 2)
            self.chatListNavigationController.empty = controller
            self.chatListNavigationController.gotoEmpty(true)

        }
        return
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return true
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func loadView() {
        super.loadView()
        backgroundColor = NSColor(red: 0x19/255, green: 0x13/255, blue: 0x3c/255, alpha: 1)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.backgroundColor = NSColor(red: 0x19/255, green: 0x13/255, blue: 0x3c/255, alpha: 1)
        
        genericView.tableView.delegate = self
        let context = self.context
        
        let previous:Atomic<[AppearanceWrapperEntry<CirclesTableEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        
        let signal = getCirclesSettings(postbox: context.account.postbox) |> deliverOnPrepareQueue
        let first: Atomic<Bool> = Atomic(value: true)
        
        let arguments = CirclesArguments(context: context)
        
        let transition: Signal<TableUpdateTransition, NoError> = combineLatest(signal, appearanceSignal)
        |> map { settings, appearance in
            let entries = circlesControllerEntries(settings: settings!)
                .map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            
            return prepareTransition(
                left: previous.swap(entries),
                right: entries,
                initialSize: initialSize.modify({$0}),
                arguments: arguments
            )
            
        } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition)
            self?.readyOnce()
            self?.chatListNavigationController.callback?()
        }))
    }
}

