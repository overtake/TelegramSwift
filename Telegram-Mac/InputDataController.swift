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
import HackUtils
import SwiftSignalKit
import ObjcUtils

public class InputDataModalController : ModalViewController {
    private let controller: InputDataController
    private let _modalInteractions: ModalInteractions?
    private let closeHandler: (@escaping()-> Void) -> Void
    private let themeDisposable = MetaDisposable()
    init(_ controller: InputDataController, modalInteractions: ModalInteractions? = nil, closeHandler: @escaping(@escaping()-> Void) -> Void = { $0() }, size: NSSize = NSMakeSize(340, 300), presentation: TelegramPresentationTheme = theme) {
        self.controller = controller
        self._modalInteractions = modalInteractions
        self.controller._frameRect = NSMakeRect(0, 0, max(size.width, 280), size.height)
        self.controller.prepareAllItems = true
        self.closeHandler = closeHandler
        super.init(frame: controller._frameRect)
        
        self.getModalTheme = {
            return .init(text: presentation.colors.text, grayText: presentation.colors.grayText, background: .clear, border: .clear, accent: presentation.colors.accent, grayForeground: presentation.colors.grayBackground, activeBackground: presentation.colors.background, activeBorder: presentation.colors.border)
        }
    }
    
    var _hasBorder: Bool = true
    public override var hasBorder: Bool {
        return _hasBorder
    }
    
    var getHeaderColor: (()->NSColor)? = nil
    public override var headerBackground: NSColor {
        return getHeaderColor?() ?? super.headerBackground
    }
    var getHeaderBorderColor: (()->NSColor)? = nil
    public override var headerBorderColor: NSColor {
        return getHeaderBorderColor?() ?? super.headerBackground
    }
    var getModalTheme: (()->ModalViewController.Theme)? = nil
    public override var modalTheme: ModalViewController.Theme {
        return getModalTheme?() ?? super.modalTheme
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
    public override var shouldCloseAllTheSameModals: Bool {
        return false
    }
    
    public override var isVisualEffectContainer: Bool {
        return true
    }
    
    public override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        modal?.updateLocalizationAndTheme(theme: theme)
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
        let result = controller.returnKeyAction()
        return result
    }
    
    public override var hasNextResponder: Bool {
        return controller.hasNextResponder
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
        controller.tableView.notifyScrollHandlers()
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
    
    private var first: Bool = true
    public override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        
        updateSize(!first)
    }
    
    var dynamicSizeImpl:(()->Bool)? = nil
    
    override open var dynamicSize: Bool {
        return self.dynamicSizeImpl?() ?? true
    }
    
    override open func measure(size: NSSize) {
        let topHeight = controller.genericView.topView?.frame.height ?? 0
        self.modal?.resize(with:NSMakeSize(max(280, min(self.controller._frameRect.width, max(size.width, 350))), min(min(size.height - 200, 500), controller.tableView.listHeight + topHeight)), animated: false)
    }
    
    public func updateSize(_ animated: Bool) {
        let topHeight = controller.genericView.topView?.frame.height ?? 0
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(max(280, min(self.controller._frameRect.width, max(contentSize.width, 350))), min(min(contentSize.height - 200, 500), controller.tableView.listHeight + topHeight)), animated: animated)
        }
    }
    
    public override func viewClass() -> AnyClass {
        fatalError()
    }
    
    public override func loadView() {
        viewDidLoad()
    }
    
    public override var view: NSView {
        if !controller.isLoaded() {
            loadView()
        }
        return controller.view
    }
    
    
    public override func viewDidLoad() {
        controller.loadView()
        super.viewDidLoad()
        ready.set(controller.ready.get())
        
        themeDisposable.set(appearanceSignal.start(next: { [weak self] appearance in
            self?.modal?.updateLocalizationAndTheme(theme: appearance.presentation)
            self?.controller.updateLocalizationAndTheme(theme: appearance.presentation)
        }))
        var first = true
        controller.modalTransitionHandler = { [weak self] animated in
            if self?.dynamicSize == true {
                self?.updateSize(animated && !first)
                first = false
            }
        }
        

        
        controller.tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            guard let `self` = self else {
                return
            }
            if self.controller.tableView.documentSize.height > self.controller.tableView.frame.height {
                self.controller.tableView.verticalScrollElasticity = .automatic
            } else {
                self.controller.tableView.verticalScrollElasticity = .none
            }
            if position.rect.minY - self.controller.tableView.frame.height > 0 {
                self.modal?.makeHeaderState(state: .active, animated: true)
            } else {
                self.modal?.makeHeaderState(state: .normal, animated: true)
            }
        }))
        
    }
    
    public override func updateFrame(_ frame: NSRect, transition: ContainedViewLayoutTransition) {
        controller.genericView.change(size: frame.size, animated: transition.isAnimated)
        controller.genericView.change(pos: frame.origin, animated: transition.isAnimated)
        self.controller.genericView.updateLayout(size: frame.size, transition: transition)
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

func prepareInputDataTransition(left:[AppearanceWrapperEntry<InputDataEntry>], right: [AppearanceWrapperEntry<InputDataEntry>], animated: Bool, searchState: TableSearchViewState?, initialSize:NSSize, arguments: InputDataArguments, onMainQueue: Bool, animateEverything: Bool = false, grouping: Bool = true, makeFirstFast: Bool = false) -> Signal<TableUpdateTransition, NoError> {
    return Signal { subscriber in
        
        func makeItem(_ entry: InputDataEntry) -> TableRowItem {
            return entry.item(arguments: arguments, initialSize: initialSize)
        }
        
        let applyQueue = prepareQueue
        
        let cancelled: Atomic<Bool> = Atomic(value: false)
        
        if Thread.isMainThread || makeFirstFast, left.isEmpty {
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
            
            applyQueue.justDispatch {
                if !cancelled.with({ $0 }) {
                    var insertions:[(Int, TableRowItem)] = []
                    
                    for i in initialIndex ..< entries.count {
                        let item:TableRowItem
                        item = makeItem(entries[i].entry)
                        insertions.append((i, item))
                        if cancelled.with({ $0 }) {
                            break
                        }
                    }
                    if !cancelled.with({ $0 }) {
                        subscriber.putNext(TableUpdateTransition(deleted: [], inserted: insertions, updated: [], state: .none(nil), animateVisibleOnly: !animateEverything, searchState: searchState))
                        subscriber.putCompletion()
                    }
                }
            }
        } else {
            let (deleted,inserted,updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
                if !cancelled.with({ $0 }) {
                    return makeItem(entry.entry)
                } else {
                    return TableRowItem(.zero)
                }
            })
            if !cancelled.with({ $0 }) {
                subscriber.putNext(TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state: .none(nil), animateVisibleOnly: !animateEverything, searchState: searchState))
                subscriber.putCompletion()
            }
        }
        
        return ActionDisposable {
            _ = cancelled.swap(true)
        }
    } |> runOn(onMainQueue ? .mainQueue() : prepareQueue)
    
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
    let grouping: Bool
    let animateEverything: Bool
    init(entries: [InputDataEntry], animated: Bool = true, searchState: TableSearchViewState? = nil, grouping: Bool = true, animateEverything: Bool = false) {
        self.entries = entries
        self.animated = animated
        self.searchState = searchState
        self.grouping = grouping
        self.animateEverything = animateEverything
    }
}

final class InputDataView : BackgroundView {
    let tableView: TableView
    
    fileprivate var topView: NSView?
    
    required init(frame frameRect: NSRect) {
        tableView = TableView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        addSubview(tableView)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        tableView.updateLocalizationAndTheme(theme: theme)
    }
    
    override var frame: NSRect {
        didSet {
            var bp = 0
            bp == 1
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        if newOrigin.y == 0 {
            var bp = 0
            bp += 1
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    
    func set(_ topView: NSView?) {
        if let topView = self.topView {
            topView.removeFromSuperview()
        }
        self.topView = topView
        if let topView = topView {
            addSubview(topView)
        }
        self.needsLayout = true
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        let tableRect: NSRect
        if let view = self.topView {
            transition.updateFrame(view: view, frame: NSMakeRect(0, 0, size.width, view.frame.height))
            tableRect = NSMakeRect(0, view.frame.height, size.width, size.height - view.frame.height)
        } else {
            tableRect = size.bounds
        }
        
//        transition.updateFrame(view: tableView.contentView, frame: tableRect.size.bounds)
        transition.updateFrame(view: tableView, frame: tableRect)
//        transition.updateFrame(view: tableView.documentView!, frame: tableView.documentSize.bounds)
        
    }
}


final class InputDataMediaSearchContext {
    let searchState:Promise<SearchState> = Promise()
    let mediaSearchState:ValuePromise<MediaSearchState> = ValuePromise(ignoreRepeated: true)
    var inSearch: Bool = false
}

extension InputDataController : PeerMediaSearchable {
    func toggleSearch() {
        guard let context = self.searchContext else {
            return
        }
        context.inSearch = !context.inSearch
        if context.inSearch {
            context.searchState.set(.single(.init(state: .Focus, request: nil)))
        } else {
            context.searchState.set(.single(.init(state: .None, request: nil)))
        }
    }
    
    fileprivate var searchContext: InputDataMediaSearchContext? {
        return self.contextObject as? InputDataMediaSearchContext
    }
    
    func setSearchValue(_ value: Signal<SearchState, NoError>) {
        self.searchContext?.searchState.set(value)
    }
    
    func setExternalSearch(_ value: Signal<ExternalSearchMessages?, NoError>, _ loadMore: @escaping () -> Void) {
        
    }
    
    var mediaSearchValue: Signal<MediaSearchState, NoError> {
        if let context = self.searchContext {
            return context.mediaSearchState.get()
        }
        return .complete()
    }
    
}

class InputDataController: GenericViewController<InputDataView> {

    fileprivate var modalTransitionHandler:((Bool)->Void)? = nil
    fileprivate var prepareAllItems: Bool = false
    
    private let values: Promise<InputDataSignalValue> = Promise()
    private let disposable = MetaDisposable()
    private let appearanceDisposablet = MetaDisposable()
    private let title: String
    var validateData:([InputDataIdentifier : InputDataValue]) -> InputDataValidation
    var afterDisappear: ()->Void
    var updateDatas:([InputDataIdentifier : InputDataValue]) -> InputDataValidation
    var didLoad:(InputDataController, [InputDataIdentifier : InputDataValue]) -> Void
    private let _removeAfterDisappear: Bool
    private let hasDone: Bool
    var updateDoneValue:([InputDataIdentifier : InputDataValue])->((InputDoneValue)->Void)->Void
    var customRightButton:((ViewController)->BarView?)?
    var updateRightBarView:((BarView)->Void)?
    var afterTransaction: (InputDataController)->Void
    var beforeTransaction: (InputDataController)->Void
    var backInvocation: ([InputDataIdentifier : InputDataValue], @escaping(Bool)->Void)->Void
    var returnKeyInvocation:(InputDataIdentifier?, NSEvent) -> InputDataReturnResult
    var deleteKeyInvocation:(InputDataIdentifier?) -> InputDataDeleteResult
    var tabKeyInvocation:(InputDataIdentifier?) -> InputDataDeleteResult
    var rightModalHeader: ModalHeaderData? = nil
    var leftModalHeader: ModalHeaderData? = nil
    var centerModalHeader: ModalHeaderData? = nil
    var keyWindowUpdate:(Bool, InputDataController) -> Void = { _, _ in }
    var hasBackSwipe:()->Bool = { return true }
    var searchKeyInvocation:() -> InputDataDeleteResult
    var getBackgroundColor: ()->NSColor
    let identifier: String
    var ignoreRightBarHandler: Bool = false
    
    var inputLimitReached:(Int)->Void = { _ in }
    var _externalFirstResponder:(()->NSResponder?)? = nil
    var _becomeFirstResponder:(()->Bool)?
    var contextObject: Any?
    var didAppear: ((InputDataController)->Void)?
    var didDisappear: ((InputDataController)->Void)?

    var afterViewDidLoad:(()->Void)?
    
    var _abolishWhenNavigationSame: Bool = false

    var getTitle:(()->String)? = nil
    var getStatus:(()->String?)? = nil
    var doneString: ()->String
    
    var autoInputAction: Bool = false
    
    init(dataSignal:Signal<InputDataSignalValue, NoError>, title: String, validateData:@escaping([InputDataIdentifier : InputDataValue]) -> InputDataValidation = {_ in return .fail(.none)}, updateDatas: @escaping([InputDataIdentifier : InputDataValue]) -> InputDataValidation = {_ in return .fail(.none)}, afterDisappear: @escaping() -> Void = {}, didLoad: @escaping(InputDataController, [InputDataIdentifier : InputDataValue]) -> Void = { _, _ in}, updateDoneValue:@escaping([InputDataIdentifier : InputDataValue])->((InputDoneValue)->Void)->Void  = { _ in return {_ in}}, removeAfterDisappear: Bool = true, hasDone: Bool = true, identifier: String = "", customRightButton: ((ViewController)->BarView?)? = nil, beforeTransaction: @escaping(InputDataController)->Void = { _ in }, afterTransaction: @escaping(InputDataController)->Void = { _ in }, backInvocation: @escaping([InputDataIdentifier : InputDataValue], @escaping(Bool)->Void)->Void = { $1(true) }, returnKeyInvocation: @escaping(InputDataIdentifier?, NSEvent) -> InputDataReturnResult = {_, _ in return .default }, deleteKeyInvocation: @escaping(InputDataIdentifier?) -> InputDataDeleteResult = {_ in return .default }, tabKeyInvocation: @escaping(InputDataIdentifier?) -> InputDataDeleteResult = {_ in return .default }, searchKeyInvocation: @escaping() -> InputDataDeleteResult = { return .default }, getBackgroundColor: @escaping()->NSColor = { theme.colors.listBackground }, doneString: @escaping()->String = { strings().navigationDone }) {
        self.title = title
        self.validateData = validateData
        self.afterDisappear = afterDisappear
        self.updateDatas = updateDatas
        self.doneString = doneString
        self.didLoad = didLoad
        self.identifier = identifier
        self._removeAfterDisappear = removeAfterDisappear
        self.hasDone = hasDone
        self.updateDoneValue = updateDoneValue
        self.customRightButton = customRightButton
        self.afterTransaction = afterTransaction
        self.beforeTransaction = beforeTransaction
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
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        self.updateRightBarView?(self.rightBarView)
    }

    override var defaultBarTitle: String {
        return getTitle?() ?? title
    }
    override var defaultBarStatus: String? {
        return getStatus?()
    }
    
    override func getRightBarViewOnce() -> BarView {
        return customRightButton?(self) ?? (hasDone ? TextButtonBarView(controller: self, text: doneString(), style: navigationButtonStyle, alignment:.Right) : super.getRightBarViewOnce())
    }
    
    private var doneView: TextButtonBarView {
        return rightBarView as! TextButtonBarView
    }
    
    override var responderPriority: HandlerPriority {
        return .medium
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
                    tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0), inset: NSEdgeInsets(), toVisible: true)
                }
            } else if scrollIfNeeded {
                if !scrollDown  {
                    tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0), inset: NSEdgeInsets(), toVisible: true)
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
                                tableView.scroll(to: .top(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0), inset: NSEdgeInsets(), timingFunction: .linear, toVisible: true)
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
        
        var values:[InputDataIdentifier : Int] = [:]
        tableView.enumerateItems { item -> Bool in
            if let identifier = (item.stableId.base as? InputDataEntryId)?.identifier {
                if let item = item as? InputDataRowItem {
                    if let data = data[identifier] {
                        let length = (data.stringValue?.length ?? 0)
                        if item.limit < length {
                            values[identifier] = length - Int(item.limit)
                        }
                    }
                }
            }
            return true
        }
        if !values.isEmpty {
            for (key, _) in values {
                let item = findItem(for: key)
                item?.view?.shakeView()
            }
            let first = values.first!.value
            self.inputLimitReached(first)
        } else {
            proccessValidation(self.validateData(data))
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.afterViewDidLoad?()
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
        
        let onMainQueue: Atomic<Bool> = Atomic(value: !prepareAllItems)
        
        let signal: Signal<TableUpdateTransition, NoError> = combineLatest(queue: .mainQueue(), appearanceSignal, values.get()) |> mapToQueue { appearance, state in
            let entries = state.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            return prepareInputDataTransition(left: previous.swap(entries), right: entries, animated: state.animated, searchState: state.searchState, initialSize: initialSize.modify{$0}, arguments: arguments, onMainQueue: onMainQueue.swap(false), animateEverything: state.animateEverything, grouping: state.grouping)
        } |> deliverOnMainQueue |> afterDisposed {
            previous.swap([])
        }
        
        disposable.set(signal.start(next: { [weak self] transition in
            guard let `self` = self else {return}
            self.beforeTransaction(self)
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
                self.didLoad(self, self.fetchData())
            }
        }))
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if let event = NSApp.currentEvent {
            switch returnKeyInvocation(self.currentFirstResponderIdentifier, event) {
            case .default:
                if event.type != .keyDown || FastSettings.checkSendingAbility(for: event) {
                    self.validateInput(data: self.fetchData())
                } else {
                    
                    let containsString = fetchData().compactMap {
                        $0.value.stringValue
                    }
                    if event.type == .keyDown, containsString.isEmpty || autoInputAction {
                        self.validateInput(data: self.fetchData())
                    } else {
                        return .invokeNext
                    }
                }
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
    
    func jumpNext() {
        if hasNextResponder {
            _ = window?.makeFirstResponder(self.nextResponder())
        }
    }
    
    override func becomeFirstResponder() -> Bool? {
        if let value = _becomeFirstResponder?() {
            return value
        }
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
        
        if let responder = _externalFirstResponder?() {
            return responder
        }
        let responder = window?.firstResponder as? NSView
        
        var responderInController: Bool = false
        var superview = responder?.superview
        while superview != nil {
            if superview == self.genericView {
                responderInController = true
                break
            } else {
                superview = superview?.superview
            }
        }
        
        if self.window?.firstResponder == self.window || self.window?.firstResponder == tableView.documentView || !responderInController {
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
    
    override var hasNextResponder: Bool {
        return true
    }
    
    override var abolishWhenNavigationSame: Bool {
        return _abolishWhenNavigationSame
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.didDisappear?(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        _ = self.window?.makeFirstResponder(nil)
        super.viewDidAppear(animated)
        
        didAppear?(self)
        
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
        
        
        window?.set(handler: { [weak self] _ in
            guard let `self` = self else {return .rejected}
            
            switch self.deleteKeyInvocation(self.currentFirstResponderIdentifier) {
            case .default:
                return .rejected
            case .invoked:
                return .invoked
            }
            
        }, with: self, for: .Delete, priority: self.responderPriority, modifierFlags: nil)
        
        
        window?.set(handler: { [weak self] _ in
            guard let `self` = self else {return .rejected}
            
            switch self.searchKeyInvocation() {
            case .default:
                return .rejected
            case .invoked:
                return .invoked
            }
            
        }, with: self, for: .F, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            let view = self?.findReponsderView as? InputDataRowView
            
            view?.makeBold()
            return .invoked
        }, with: self, for: .B, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            let view = self?.findReponsderView as? InputDataRowView
            view?.makeUrl()
            return .invoked
        }, with: self, for: .U, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            let view = self?.findReponsderView as? InputDataRowView
            view?.makeItalic()
            return .invoked
        }, with: self, for: .I, priority: self.responderPriority, modifierFlags: [.command])
        
        
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            let view = self?.findReponsderView as? InputDataRowView
            view?.makeMonospace()
            return .invoked
        }, with: self, for: .K, priority: responderPriority, modifierFlags: [.command, .shift])
        
    }
    
    
    
    var findReponsderView: TableRowView? {
        if let view = self.firstResponder() as? NSView {
            var superview: NSView? = view
            while superview != nil {
                if let current = superview as? TableRowView {
                    return current
                } else {
                    superview = superview?.superview
                }
            }
        }
        return nil
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
    }
    
}
