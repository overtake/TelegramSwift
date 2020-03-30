//
//  InputDataController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit


public class InputDataModalController : ModalViewController {
    private let controller: InputDataController
    private let _modalInteractions: ModalInteractions?
    private let closeHandler: (@escaping()-> Void) -> Void
    private let themeDisposable = MetaDisposable()
    init(_ controller: InputDataController, modalInteractions: ModalInteractions? = nil, closeHandler: @escaping(@escaping()-> Void) -> Void = { $0() }, size: NSSize = NSMakeSize(350, 300)) {
        self.controller = controller
        self._modalInteractions = modalInteractions
        self.controller._frameRect = NSMakeRect(0, 0, size.width, size.height)
        self.closeHandler = closeHandler
        super.init(frame: controller._frameRect)
    }
    
    var isFullScreenImpl: (()->Bool)? = nil
    
    public override var isFullScreen: Bool {
        return self.isFullScreenImpl?() ?? super.isFullScreen
    }
    var closableImpl: (()->Bool)? = nil

    public override var closable: Bool {
        return closableImpl?() ?? super.closable
    }
    
    public override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        closeHandler({ [weak self] in
            self?.closeModal()
        })
    }
    
    public override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
    }
    
    public override var containerBackground: NSColor {
        return controller.getBackgroundColor()
    }
    
    private func closeModal() {
        super.close()
    }
    
    public override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        if controller.defaultBarTitle.isEmpty {
            return nil
        }
        return (left: self.controller.leftModalHeader, center: self.controller.centerModalHeader ?? ModalHeaderData(title: controller.defaultBarTitle), right: self.controller.rightModalHeader)
    }
    
    
    public override var modalInteractions: ModalInteractions? {
        return _modalInteractions
    }
    
    public override var handleEvents: Bool {
        return true
    }
    
    public override func becomeFirstResponder() -> Bool? {
        return controller.becomeFirstResponder()
    }
    
    public override func firstResponder() -> NSResponder? {
        return controller.firstResponder()
    }
    
    public override func returnKeyAction() -> KeyHandlerResult {
        return controller.returnKeyAction()
    }
    
    public override var haveNextResponder: Bool {
        return controller.haveNextResponder
    }
    
    public override func nextResponder() -> NSResponder? {
        return controller.nextResponder()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controller.viewWillAppear(animated)
    }
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        controller.viewDidAppear(animated)
    }
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        controller.viewWillDisappear(animated)
    }
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        controller.viewDidDisappear(animated)
        controller.didRemovedFromStack()
    }
    
    
    @objc private func rootControllerFrameChanged(_ notification:Notification) {
        viewDidResized(frame.size)
    }
    
    public override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        
        updateSize(true)
    }
    
    var dynamicSizeImpl:(()->Bool)? = nil
    
    override open var dynamicSize: Bool {
        return self.dynamicSizeImpl?() ?? true
    }
    
    override open func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(max(340, min(self.controller._frameRect.width, max(size.width, 350))), min(size.height - 150, controller.tableView.listHeight)), animated: false)
    }
    
    public func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(max(340, min(self.controller._frameRect.width, max(contentSize.width, 350))), min(contentSize.height - 150, controller.tableView.listHeight)), animated: animated)
        }
    }
    
    public override func viewClass() -> AnyClass {
        fatalError()
    }
    
    public override func loadView() {
        controller.loadView()
    
        viewDidLoad()
    }
    
    public override var view: NSView {
        if !controller.isLoaded() {
            loadView()
        }
        return controller.view
    }
    
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        controller.viewDidLoad()
        ready.set(controller.ready.get())
        
        themeDisposable.set(appearanceSignal.start(next: { [weak self] appearance in
            self?.modal?.updateLocalizationAndTheme(theme: appearance.presentation)
            self?.controller.updateLocalizationAndTheme(theme: appearance.presentation)
        }))
        
        controller.modalTransitionHandler = { [weak self] animated in
            if self?.dynamicSize == true {
                self?.updateSize(animated)
            }
        }
    }
    deinit {
        themeDisposable.dispose()
    }
}




final class InputDataArguments {
    let select:((InputDataIdentifier, InputDataValue))->Void
    let dataUpdated:()->Void
    init(select: @escaping((InputDataIdentifier, InputDataValue))->Void, dataUpdated:@escaping()->Void) {
        self.select = select
        self.dataUpdated = dataUpdated
    }
}

private let queue: Queue = Queue(name: "InputDataItemsQueue", qos: DispatchQoS.background)

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<InputDataEntry>], right: [AppearanceWrapperEntry<InputDataEntry>], animated: Bool, searchState: TableSearchViewState?, initialSize:NSSize, arguments: InputDataArguments, onMainQueue: Bool) -> Signal<TableUpdateTransition, NoError> {
    
    return Signal { subscriber in
        
        func makeItem(_ entry: InputDataEntry) -> TableRowItem {
            return entry.item(arguments: arguments, initialSize: initialSize)
        }
        
        let applyQueue = onMainQueue ? .mainQueue() : prepareQueue
        
        let cancelled: Atomic<Bool> = Atomic(value: false)
        
        if Thread.isMainThread {
            var initialIndex:Int = 0
            var height:CGFloat = 0
            var firstInsertion:[(Int, TableRowItem)] = []
            let entries = Array(right)
            
            let index:Int = 0
            
            for i in index ..< entries.count {
                let item = makeItem(entries[i].entry)
                height += item.height
                firstInsertion.append((i, item))
                if initialSize.height < height {
                    break
                }
            }
            initialIndex = firstInsertion.count
            subscriber.putNext(TableUpdateTransition(deleted: [], inserted: firstInsertion, updated: [], state: .none(nil), searchState: searchState))
            
            queue.async {
                if !cancelled.with({ $0 }) {
                    
                    var insertions:[(Int, TableRowItem)] = []
                    let updates:[(Int, TableRowItem)] = []
                    
                    for i in initialIndex ..< entries.count {
                        let item:TableRowItem
                        item = makeItem(entries[i].entry)
                        insertions.append((i, item))
                        if cancelled.with({ $0 }) {
                            break
                        }
                    }
                    if !cancelled.with({ $0 }) {
                        applyQueue.async {
                            subscriber.putNext(TableUpdateTransition(deleted: [], inserted: insertions, updated: updates, state: .none(nil), searchState: searchState))
                            subscriber.putCompletion()
                        }
                    }
                }
            }
        } else {
            queue.async {
                let (deleted,inserted,updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
                    if !cancelled.with({ $0 }) {
                        return makeItem(entry.entry)
                    } else {
                        return TableRowItem(.zero)
                    }
                })
                if !cancelled.with({ $0 }) {
                    applyQueue.async {
                        subscriber.putNext(TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state: .none(nil), searchState: searchState))
                        subscriber.putCompletion()
                    }
                }
            }
            
        }
        
        return ActionDisposable {
            _ = cancelled.swap(true)
        }
    } |> runOn(onMainQueue ? .mainQueue() : prepareQueue)
    
    
    
//
//    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
//        return entry.entry.item(arguments: arguments, initialSize: initialSize)
//    }
//    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: animated, searchState: searchState)
}


enum InputDataReturnResult {
    case `default`
    case nextResponder
    case invokeEvent
    case nothing
}

enum InputDataDeleteResult {
    case `default`
    case invoked
}

struct InputDataSignalValue {
    let entries: [InputDataEntry]
    let animated: Bool
    let searchState: TableSearchViewState?
    init(entries: [InputDataEntry], animated: Bool = true, searchState: TableSearchViewState? = nil) {
        self.entries = entries
        self.animated = animated
        self.searchState = searchState
    }
}

final class InputDataView : BackgroundView, AppearanceViewProtocol {
    let tableView = TableView()
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        tableView.frame = bounds
    }
    
    func updateLocalizationAndTheme(theme: PresentationTheme) {
        tableView.updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layout() {
        super.layout()
        tableView.frame = bounds
    }
}

class InputDataController: GenericViewController<InputDataView> {

    fileprivate var modalTransitionHandler:((Bool)->Void)? = nil
    
    private let values: Promise<InputDataSignalValue> = Promise()
    private let disposable = MetaDisposable()
    private let appearanceDisposablet = MetaDisposable()
    private let title: String
    var validateData:([InputDataIdentifier : InputDataValue]) -> InputDataValidation
    var afterDisappear: ()->Void
    var updateDatas:([InputDataIdentifier : InputDataValue]) -> InputDataValidation
    var didLoaded:(InputDataController, [InputDataIdentifier : InputDataValue]) -> Void
    private let _removeAfterDisappear: Bool
    private let hasDone: Bool
    var updateDoneValue:([InputDataIdentifier : InputDataValue])->((InputDoneValue)->Void)->Void
    var customRightButton:((ViewController)->BarView?)?
    var afterTransaction: (InputDataController)->Void
    var backInvocation: ([InputDataIdentifier : InputDataValue], @escaping(Bool)->Void)->Void
    var returnKeyInvocation:(InputDataIdentifier?, NSEvent) -> InputDataReturnResult
    var deleteKeyInvocation:(InputDataIdentifier?) -> InputDataDeleteResult
    var tabKeyInvocation:(InputDataIdentifier?) -> InputDataDeleteResult
    var rightModalHeader: ModalHeaderData? = nil
    var leftModalHeader: ModalHeaderData? = nil
    var centerModalHeader: ModalHeaderData? = nil
    var keyWindowUpdate:(Bool, InputDataController) -> Void = { _, _ in }
    var hasBackSwipe:()->Bool = { return true }
    private let searchKeyInvocation:() -> InputDataDeleteResult
    var getBackgroundColor: ()->NSColor
    let identifier: String
    var onDeinit:(()->Void)?
    var ignoreRightBarHandler: Bool = false
    
    var contextOject: Any?
    
    var _abolishWhenNavigationSame: Bool = false
    
    init(dataSignal:Signal<InputDataSignalValue, NoError>, title: String, validateData:@escaping([InputDataIdentifier : InputDataValue]) -> InputDataValidation = {_ in return .fail(.none)}, updateDatas: @escaping([InputDataIdentifier : InputDataValue]) -> InputDataValidation = {_ in return .fail(.none)}, afterDisappear: @escaping() -> Void = {}, didLoaded: @escaping(InputDataController, [InputDataIdentifier : InputDataValue]) -> Void = { _, _ in}, updateDoneValue:@escaping([InputDataIdentifier : InputDataValue])->((InputDoneValue)->Void)->Void  = { _ in return {_ in}}, removeAfterDisappear: Bool = true, hasDone: Bool = true, identifier: String = "", customRightButton: ((ViewController)->BarView?)? = nil, afterTransaction: @escaping(InputDataController)->Void = { _ in }, backInvocation: @escaping([InputDataIdentifier : InputDataValue], @escaping(Bool)->Void)->Void = { $1(true) }, returnKeyInvocation: @escaping(InputDataIdentifier?, NSEvent) -> InputDataReturnResult = {_, _ in return .default }, deleteKeyInvocation: @escaping(InputDataIdentifier?) -> InputDataDeleteResult = {_ in return .default }, tabKeyInvocation: @escaping(InputDataIdentifier?) -> InputDataDeleteResult = {_ in return .default }, searchKeyInvocation: @escaping() -> InputDataDeleteResult = { return .default }, getBackgroundColor: @escaping()->NSColor = { theme.colors.listBackground }) {
        self.title = title
        self.validateData = validateData
        self.afterDisappear = afterDisappear
        self.updateDatas = updateDatas
        self.didLoaded = didLoaded
        self.identifier = identifier
        self._removeAfterDisappear = removeAfterDisappear
        self.hasDone = hasDone
        self.updateDoneValue = updateDoneValue
        self.customRightButton = customRightButton
        self.afterTransaction = afterTransaction
        self.backInvocation = backInvocation
        self.returnKeyInvocation = returnKeyInvocation
        self.deleteKeyInvocation = deleteKeyInvocation
        self.tabKeyInvocation = tabKeyInvocation
        self.searchKeyInvocation = searchKeyInvocation
        self.getBackgroundColor = getBackgroundColor
        super.init()
        values.set(dataSignal)
    }
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        self.genericView.updateLocalizationAndTheme(theme: theme)
        requestUpdateBackBar()
        requestUpdateCenterBar()
        requestUpdateRightBar()
    }
    
    
    
    override var defaultBarTitle: String {
        return title
    }
    
    override func getRightBarViewOnce() -> BarView {
        return customRightButton?(self) ?? (hasDone ? TextButtonBarView(controller: self, text: L10n.navigationDone, style: navigationButtonStyle, alignment:.Right) : super.getRightBarViewOnce())
    }
    
    private var doneView: TextButtonBarView {
        return rightBarView as! TextButtonBarView
    }
    
    override var responderPriority: HandlerPriority {
        return .modal
    }
    var tableView: TableView {
        return self.genericView.tableView
    }
    
    func fetchData() -> [InputDataIdentifier : InputDataValue] {
        var values:[InputDataIdentifier : InputDataValue] = [:]
        tableView.enumerateItems { item -> Bool in
            if let identifier = (item.stableId.base as? InputDataEntryId)?.identifier {
                if let item = item as? InputDataRowDataValue {
                    values[identifier] = item.value
                }
            }
            return true
        }
        return values
    }
    
    private func findItem(for identifier: InputDataIdentifier) -> TableRowItem? {
        var item: TableRowItem?
        tableView.enumerateItems { current -> Bool in
            if let stableId = current.stableId.base as? InputDataEntryId {
                if  stableId.identifier == identifier {
                    item = current
                }
            }
            return item == nil
        }
        return item
    }
    
    func makeFirstResponderIfPossible(for identifier: InputDataIdentifier, focusIdentifier: InputDataIdentifier? = nil, scrollDown: Bool = false, scrollIfNeeded: Bool = true) {
        if let item = findItem(for: identifier) {
            _ = window?.makeFirstResponder(findItem(for: identifier)?.view?.firstResponder)
            
            if let focusIdentifier = focusIdentifier {
                if let item = findItem(for: focusIdentifier) {
                    tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0), inset: NSEdgeInsets(), true)
                }
            } else if scrollIfNeeded {
                if !scrollDown  {
                    tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0), inset: NSEdgeInsets(), true)
                } else {
                    tableView.scroll(to: .down(true))
                }
            }
        }
    }
    
    func proccessValidation(_ validation: InputDataValidation) {
        var scrollFirstItem: TableRowItem? = nil
        switch validation {
        case let .fail(fail):
            switch fail {
            case let .alert(text):
                alert(for: mainWindow, info: text)
            case let .fields(fields):
                for (identifier, action) in fields {
                    switch action {
                    case .shake:
                        let item = findItem(for: identifier)
                        item?.view?.shakeView()
                        if scrollFirstItem == nil {
                            var invoked: Bool = false
                            scrollFirstItem = item
                            if let item = item, !invoked {
                                tableView.scroll(to: .top(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsets(), timingFunction: .linear, true)
                                invoked = true
                            }
                        }
                    case let .shakeWithData(data):
                        let item = findItem(for: identifier)
                        item?.view?.shakeViewWithData(data)
                    }
                }
            case let .doSomething(next):
                next { [weak self] validation in
                    self?.proccessValidation(validation)
                }
            default:
                //TODO IF NEEDED
                break
            }
        case let .success(behaviour):
            switch behaviour {
            case .navigationBack:
                navigationController?.back()
            case .navigationBackWithPushAnimation:
                 navigationController?.back(animationStyle: .push)
            case let .custom(action):
                action()
            }
        case .none:
            break
        }
    }
    
    func validateInputValues() {
        self.proccessValidation(self.validateData(self.fetchData()))
    }
    
    private func validateInput(data: [InputDataIdentifier : InputDataValue]) {
        proccessValidation(self.validateData(data))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.tableView.getBackgroundColor = self.getBackgroundColor
        
        
        appearanceDisposablet.set(appearanceSignal.start(next: { [weak self] _ in
            self?.updateLocalizationAndTheme(theme: theme)
        }))
        
        let arguments = InputDataArguments(select: { [weak self] (identifier, value) in
            guard let `self` = self else {return}
            self.validateInput(data: [identifier : value])
        }, dataUpdated: { [weak self] in
            guard let `self` = self else {return}
            self.proccessValidation(self.updateDatas(self.fetchData()))
        })
        
        self.rightBarView.set(handler:{ [weak self] _ in
            guard let `self` = self else {return}
            if !self.ignoreRightBarHandler {
                self.validateInput(data: self.fetchData())
            }
        }, for: .Click)
        
        let previous: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        let onMainQueue: Atomic<Bool> = Atomic(value: true)
        
        let signal: Signal<TableUpdateTransition, NoError> = combineLatest(queue: .mainQueue(), appearanceSignal, values.get()) |> mapToQueue { appearance, state in
            let entries = state.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            return prepareTransition(left: previous.swap(entries), right: entries, animated: state.animated, searchState: state.searchState, initialSize: initialSize.modify{$0}, arguments: arguments, onMainQueue: onMainQueue.swap(false))
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition in
            guard let `self` = self else {return}
            self.tableView.merge(with: transition)
            
            
            let result = self.updateDoneValue(self.fetchData())
            result { [weak self] value in
                guard let `self` = self else {return}
                switch value {
                case let .disabled(text):
                    self.doneView.isHidden = false
                    self.doneView.isLoading = false
                    self.doneView.isEnabled = false
                    self.doneView.set(text: text, for: .Normal)
                case let .enabled(text):
                    self.doneView.isHidden = false
                    self.doneView.isLoading = false
                    self.doneView.isEnabled = true
                    self.doneView.set(text: text, for: .Normal)
                case .loading:
                    self.doneView.isHidden = false
                    self.doneView.isLoading = true
                case .invisible:
                    self.doneView.isHidden = true
                }
                
            }
            
            self.afterTransaction(self)
            self.modalTransitionHandler?(transition.animated)
            
            let wasReady: Bool = self.didSetReady
            self.readyOnce()
            if !wasReady {
                self.didLoaded(self, self.fetchData())
            }
        }))
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if let event = NSApp.currentEvent {
            switch returnKeyInvocation(self.currentFirstResponderIdentifier, event) {
            case .default:
                self.validateInput(data: self.fetchData())
                return .invoked
            case .nextResponder:
                _ = window?.makeFirstResponder(self.nextResponder())
                return .invoked
            case .nothing:
                return .invoked
            case .invokeEvent:
                return .invokeNext
            }
        }
        return .invokeNext
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func didRemovedFromStack() {
        super.didRemovedFromStack()
        afterDisappear()
    }
    private var firstTake: Bool = true
    
    override func firstResponder() -> NSResponder? {
        if self.window?.firstResponder == self.window || self.window?.firstResponder == tableView.documentView {
            var first: NSResponder? = nil
            tableView.enumerateViews { view -> Bool in
                first = view.firstResponder
                if first != nil, self.firstTake {
                    if let item = view.item as? InputDataRowDataValue {
                        switch item.value {
                        case let .string(value):
                            let value = value ?? ""
                            if !value.isEmpty {
                                return true
                            }
                        default:
                            break
                        }
                    }
                }
                return first == nil
            }
            self.firstTake = false
            return first
        }
        return window?.firstResponder
    }

    override func backSettings() -> (String, CGImage?) {
        
        return super.backSettings()
    }
    
    override var enableBack: Bool {
        return true
    }
   // private var canInvokeBack: Bool = false
    override func invokeNavigationBack() -> Bool {
       return true
    }
    
    override func executeReturn() {
        backInvocation(fetchData(), { [weak self] result in
            if result {
                self?.navigationController?.back()
            }
        })
    }
    
    override func getLeftBarViewOnce() -> BarView {
        if let navigation = navigationController {
            return navigation.empty === self ? BarView(controller: self) : super.getLeftBarViewOnce()
        }
        return BarView(controller: self)
    }
    
    override var haveNextResponder: Bool {
        return true
    }
    
    override var abolishWhenNavigationSame: Bool {
        return _abolishWhenNavigationSame
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    override func viewDidAppear(_ animated: Bool) {
        _ = self.window?.makeFirstResponder(nil)
        super.viewDidAppear(animated)
        
        window?.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            let index = self.tableView.row(at: self.tableView.documentView!.convert(event.locationInWindow, from: nil))
            
            if index > -1, let view = self.tableView.item(at: index).view {
                if view.mouseInsideField {
                    if self.window?.firstResponder != view.firstResponder {
                        _ = self.window?.makeFirstResponder(view.firstResponder)
                        return .invoked
                    }
                }
            }
            
            return .invokeNext
        }, with: self, for: .leftMouseUp, priority: self.responderPriority)
        
        
        window?.set(handler: { [weak self] in
            guard let `self` = self else {return .rejected}
            
            switch self.deleteKeyInvocation(self.currentFirstResponderIdentifier) {
            case .default:
                return .rejected
            case .invoked:
                return .invoked
            }
            
        }, with: self, for: .Delete, priority: self.responderPriority, modifierFlags: nil)
        
        
        window?.set(handler: { [weak self] in
            guard let `self` = self else {return .rejected}
            
            switch self.searchKeyInvocation() {
            case .default:
                return .rejected
            case .invoked:
                return .invoked
            }
            
        }, with: self, for: .F, priority: self.responderPriority, modifierFlags: nil)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    
    var currentFirstResponderIdentifier: InputDataIdentifier? {
        var identifier: InputDataIdentifier? = nil
        
        tableView.enumerateViews { view -> Bool in
            if view.hasFirstResponder() {
                if view.firstResponder == view.window?.firstResponder {
                    identifier = (view.item?.stableId.base as? InputDataEntryId)?.identifier
                }
                
            }
            return identifier == nil
        }
        return identifier
    }
    
    override var supportSwipes: Bool {
        let horizontal = HackUtils.findElements(byClass: "TGUIKit.HorizontalTableView", in: genericView.tableView)?.first as? HorizontalTableView
        if let horizontal = horizontal {
            return !horizontal._mouseInside()
        }
        return self.hasBackSwipe()
    }
    
    override func nextResponder() -> NSResponder? {
        var next: NSResponder?
        let current = self.window?.firstResponder
        

        
        var selectNext: Bool = false
        
        var first: NSResponder? = nil

        
        tableView.enumerateViews { view -> Bool in
            if view.hasFirstResponder() {
                first = view.firstResponder
            }
            return first == nil
        }
        
        tableView.enumerateViews { view -> Bool in
            if view.hasFirstResponder() {
                if selectNext {
                    next = view.firstResponder
                } else if view.firstResponder == current || view.firstResponder == (current as? NSView)?.superview?.superview {
                    if let nextInner = view.nextResponder() {
                        next = nextInner
                        return false
                    }
                    selectNext = true
                    return true
                }
            }
            return next == nil
        }
        
        
        return next ?? first
    }
    
    override var removeAfterDisapper: Bool {
        return _removeAfterDisappear
    }
    
    override func windowDidBecomeKey() {
        self.keyWindowUpdate(true, self)
    }
   
    override func windowDidResignKey() {
        self.keyWindowUpdate(false, self)
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        self.executeReturn()
        return .invoked
    }
    
    deinit {
        disposable.dispose()
        appearanceDisposablet.dispose()
        onDeinit?()
    }
    
}
