//
//  StorageUsageBlockController.swift
//  Telegram
//
//  Created by Mike Renoir on 23.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore

import SwiftSignalKit
import Postbox



private final class SegmentContainerView : View {
   fileprivate let segmentControl: ScrollableSegmentView
   required init(frame frameRect: NSRect) {
       self.segmentControl = ScrollableSegmentView(frame: NSMakeRect(0, 0, frameRect.width, 50))
       super.init(frame: frameRect)
       addSubview(segmentControl)
       updateLocalizationAndTheme(theme: theme)
       segmentControl.fitToWidth = true
       
   }
   
   override func layout() {
       super.layout()
       
       segmentControl.frame = bounds
       segmentControl.center()
   }
   
   override func updateLocalizationAndTheme(theme: PresentationTheme) {
       segmentControl.theme = ScrollableSegmentTheme(background: .clear, border: .clear, selector: theme.colors.accent, inactiveText: theme.colors.grayText, activeText: theme.colors.text, textFont: .normal(.text))
       backgroundColor = .clear
   }
   
   required init?(coder: NSCoder) {
       fatalError("init(coder:) has not been implemented")
   }
}

private enum AnimationDirection {
   case leftToRight
   case rightToLeft
}
private let sectionOffset: CGFloat = 30

final class StorageUsageMediaContainerView : View {
   
   
   fileprivate let view: StorageUsageBlockControllerView
   required init(frame frameRect: NSRect) {
       view = StorageUsageBlockControllerView(frame: NSMakeRect(0, sectionOffset, min(600, frameRect.width - sectionOffset * 2), frameRect.height - sectionOffset))
       super.init(frame: frameRect)
       addSubview(view)
       backgroundColor = theme.colors.listBackground
       layout()
   }
   override func updateLocalizationAndTheme(theme: PresentationTheme) {
       super.updateLocalizationAndTheme(theme: theme)
       backgroundColor = theme.colors.listBackground
   }
   
   override func scrollWheel(with event: NSEvent) {
       view.scrollWheel(with: event)
   }
   
   required init?(coder: NSCoder) {
       fatalError("init(coder:) has not been implemented")
   }
   
   override func layout() {
       super.layout()
       
       let blockWidth = min(600, frame.width - sectionOffset * 2)
       view.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - blockWidth) / 2), sectionOffset, blockWidth, frame.height - sectionOffset)
              
   }
   
   var mainView:NSView? {
       return self.view.mainView
   }
   
   var mainTable: TableView? {
       if let tableView = self.view.mainView as? TableView {
           return tableView
       } else if let view = self.view.mainView as? InputDataView {
           return view.tableView
       } else if let view = self.view.mainView as? PeerMediaGifsView {
           return view.tableView
       }
       return nil
   }
   
   func updateInteraction(_ chatInteraction:ChatInteraction) {
       self.view.updateInteraction(chatInteraction)
   }
   
   
   fileprivate func updateMainView(with view:NSView, animated:AnimationDirection?) {
       self.view.updateMainView(with: view, animated: animated)
   }
   
   func changeState(selectState:Bool, animated:Bool) {
       self.view.changeState(selectState: selectState, animated: animated)
   }
   
   fileprivate var segmentPanelView: SegmentContainerView {
       return self.view.segmentPanelView
   }
   
   func updateCorners(_ corners: GeneralViewItemCorners, animated: Bool) {
       view.updateCorners(corners, animated: animated)
   }
}

class StorageUsageBlockControllerView : View {
   
   private let topPanelView = GeneralRowContainerView(frame: .zero)
   fileprivate let segmentPanelView: SegmentContainerView
   
   private(set) weak var mainView:NSView?
   
   private let topPanelSeparatorView = View()
   
   override func scrollWheel(with event: NSEvent) {
       mainTable?.scrollWheel(with: event)
   }
   
   var mainTable: TableView? {
       if let tableView = self.mainView as? TableView {
           return tableView
       } else if let view = self.mainView as? InputDataView {
           return view.tableView
       }
       return nil
   }
   
   fileprivate var corners:GeneralViewItemCorners = [.topLeft, .topRight]
   
   fileprivate var isSelectionState:Bool = false
   private var chatInteraction:ChatInteraction?
   private var searchState: SearchState?
   required init(frame frameRect:NSRect) {
       segmentPanelView = SegmentContainerView(frame: NSMakeRect(0, 0, frameRect.width, 50))
       super.init(frame: frameRect)
       addSubview(topPanelView)
       topPanelView.addSubview(topPanelSeparatorView)
       topPanelView.addSubview(segmentPanelView)
       updateLocalizationAndTheme(theme: theme)
       layout()
   }
   
   override func updateLocalizationAndTheme(theme: PresentationTheme) {
      // super.updateLocalizationAndTheme(theme: theme)
       backgroundColor = theme.colors.listBackground
       topPanelView.backgroundColor = theme.colors.background
       topPanelSeparatorView.backgroundColor = theme.colors.border
   }
   
   func updateInteraction(_ chatInteraction:ChatInteraction) {
       self.chatInteraction = chatInteraction
   }
   
   func updateCorners(_ corners: GeneralViewItemCorners, animated: Bool) {
       self.corners = corners
       self.topPanelView.setCorners(corners, animated: animated)
       topPanelSeparatorView.isHidden = corners == .all
   }
   
   fileprivate func updateMainView(with view:NSView, animated:AnimationDirection?) {
       addSubview(view, positioned: .below, relativeTo: topPanelView)
       
       let timingFunction: CAMediaTimingFunctionName = .spring
       let duration: TimeInterval = 0.35
       
       if let animated = animated {
           if let mainView = mainView {
               switch animated {
               case .leftToRight:
                   mainView._change(pos: NSMakePoint(-mainView.frame.width, mainView.frame.minY), animated: true, duration: duration, timingFunction: timingFunction, completion: { [weak mainView] completed in
                       if completed {
                           mainView?.removeFromSuperview()
                       }
                   })
                   view.layer?.animatePosition(from: NSMakePoint(view.frame.width, mainView.frame.minY), to: NSMakePoint(0, mainView.frame.minY), duration: duration, timingFunction: timingFunction)
               case .rightToLeft:
                   mainView._change(pos: NSMakePoint(mainView.frame.width, mainView.frame.minY), animated: true, duration: duration, timingFunction: timingFunction, completion: { [weak mainView] completed in
                       if completed {
                           mainView?.removeFromSuperview()
                       }
                   })
                   view.layer?.animatePosition(from: NSMakePoint(-view.frame.width, mainView.frame.minY), to: NSMakePoint(0, mainView.frame.minY), duration: duration, timingFunction: timingFunction)
               }
           }
           self.mainView = view
       } else {
           mainView?.removeFromSuperview()
           self.mainView = view
       }
       needsLayout = true
   }
   
   func changeState(selectState:Bool, animated:Bool) {
       assert(mainView != nil)
       
       self.isSelectionState = selectState
       
   }
   
   
   override func layout() {
       
       let inset:CGFloat = isSelectionState ? 50 : 0
       topPanelView.frame = NSMakeRect(0, 0, frame.width, 50)
       topPanelView.setCorners(self.corners)
       topPanelSeparatorView.frame = NSMakeRect(0, topPanelView.frame.height - .borderSize, topPanelView.frame.width, .borderSize)
       
       segmentPanelView.frame = NSMakeRect(0, 0, topPanelView.frame.width, 50)
       mainView?.frame = NSMakeRect(0, topPanelView.isHidden ? 0 : topPanelView.frame.height, frame.width, frame.height - inset - (topPanelView.isHidden ? 0 : topPanelView.frame.height))
       

   }
   
   required init?(coder: NSCoder) {
       fatalError("init(coder:) has not been implemented")
   }
   
}

private extension PeerMediaCollectionMode {
   var title: String {
       if self == .members {
           return strings().peerMediaMembers
       }
       if self == .photoOrVideo {
           return strings().peerMediaMedia
       }
       if self == .file {
           return strings().peerMediaFiles
       }
       if self == .webpage {
           return strings().peerMediaLinks
       }
       if self.tagsValue == .music {
           return strings().peerMediaMusic
       }
       if self == .voice {
           return strings().peerMediaVoice
       }
       if self == .commonGroups {
           return strings().peerMediaCommonGroups
       }
       if self == .gifs {
           return strings().peerMediaGifs
       }
       return ""
   }
}


private enum StorageUsageCollectionMode : Int32 {
    case peers
    case media
    case files
    case music
    
    var title: String {
        switch self {
        case .peers:
            return "Chats"
        case .media:
            return "Media"
        case .files:
            return "Files"
        case .music:
            return "Music"
        }
    }
}


private struct State : Equatable {
    var tabs: [StorageUsageCollectionMode]
    var selected: StorageUsageCollectionMode?
    var editing: Bool
    var stats: StorageUsageStats
    var allStats: AllStorageUsageStats
}

class StorageUsageBlockController: EditableViewController<StorageUsageMediaContainerView>, Notifable {
   
    private let peerId: PeerId?
    private let disposable = MetaDisposable()
    private let members: ViewController
    private let tagsList:[StorageUsageCollectionMode] = [.peers, .media, .files, .music]
   
    
    private var mode: StorageUsageCollectionMode?
   
   private var currentTagListIndex: Int {
       if let mode = self.mode {
           return Int(mode.rawValue)
       } else {
           return 0
       }
   }
   private var interactions:ChatInteraction
   private let toggleDisposable = MetaDisposable()
   private var currentController: ViewController?
    

    
    private let stateValue: Atomic<State>
    private let statePromise:ValuePromise<State>
    private func updateState(_ f: (State) -> State) {
        statePromise.set(stateValue.modify (f))
    }
     
    
   var currentMainTableView:((TableView?, Bool, Bool)->Void)? = nil {
       didSet {
           if isLoaded() {
               currentMainTableView?(genericView.mainTable, false, false)
           }
       }
   }
   
   
   private let editing: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)
   override var state:ViewControllerState {
       didSet {
           let newValue = state
           genericView.mainTable?.scroll(to: .up(true), completion: { [weak self] _ in
               self?.editing.set(newValue == .Edit)
           })
       }
   }
   
    init(context: AccountContext, peerId:PeerId?, allStats: AllStorageUsageStats, stats: StorageUsageStats) {
        self.peerId = peerId
        self.interactions = .init(chatLocation: .peer(peerId ?? context.peerId), context: context)
        let initialValue = State(tabs: [.peers], selected: .peers, editing: false, stats: stats, allStats: allStats)
        self.stateValue = Atomic(value: initialValue)
        self.statePromise = ValuePromise(initialValue, ignoreRepeated: true)
        self.members = StorageUsage_Block_Chats(context: context, stats: allStats)
        super.init(context)
   }

   var unableToHide: Bool {
       return self.state != .Normal || !onTheTop
   }
   
   override func viewDidAppear(_ animated: Bool) {
       super.viewDidAppear(animated)
       interactions.add(observer: self)
       
       if let mode = self.mode {
           self.controller(for: mode).viewDidAppear(animated)
       }
       
       guard let navigationController = self.navigationController else {
           return
       }
       
       navigationController.swapNavigationBar(leftView: nil, centerView: self.centerBarView, rightView: nil, animation: .crossfade)
       navigationController.swapNavigationBar(leftView: nil, centerView: nil, rightView: self.rightBarView, animation: .none)

   }
    
    private var editButton:ImageButton? = nil
    private var doneButton:TitleButton? = nil
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        editButton?.style = navigationButtonStyle
        editButton?.set(image: theme.icons.chatActions, for: .Normal)
        editButton?.set(image: theme.icons.chatActionsActive, for: .Highlight)

        
        editButton?.setFrameSize(70, 50)
        editButton?.center()
        doneButton?.set(color: theme.colors.accent, for: .Normal)
        doneButton?.style = navigationButtonStyle
    }
    
    
    override func getRightBarViewOnce() -> BarView {
        let back = BarView(70, controller: self)
        let editButton = ImageButton()
        back.addSubview(editButton)
        
        self.editButton = editButton
//
        let doneButton = TitleButton()
        doneButton.set(font: .medium(.text), for: .Normal)
        doneButton.set(text: strings().navigationDone, for: .Normal)
        
        
        _ = doneButton.sizeToFit()
        back.addSubview(doneButton)
        doneButton.center()
        
        self.doneButton = doneButton

        
        doneButton.set(handler: { [weak self] _ in
            self?.changeState()
        }, for: .Click)
        
        doneButton.isHidden = true
        
        
        editButton.contextMenu = { [weak self] in
            
            let mode = self?.mode
            
            var items:[ContextMenuItem] = []
            items.append(ContextMenuItem(strings().chatContextEdit1, handler: { [weak self] in
                self?.changeState()
            }, itemImage: MenuAnimation.menu_edit.value))
            
            let menu = ContextMenu(betterInside: true)
            
            for item in items {
                menu.addItem(item)
            }
            
            return menu
        }

        requestUpdateRightBar()
        return back
    }

   
   override func viewDidDisappear(_ animated: Bool) {
       super.viewDidDisappear(animated)
       interactions.remove(observer: self)
       
       if let mode = mode {
           let controller = self.controller(for: mode)
           controller.viewDidDisappear(animated)
       }
       
       if let navigationController = navigationController {
           navigationController.swapNavigationBar(leftView: nil, centerView: navigationController.controller.centerBarView, rightView: nil, animation: .crossfade)
           navigationController.swapNavigationBar(leftView: nil, centerView: nil, rightView: navigationController.controller.rightBarView, animation: .none)
       }
   }
   
   override func viewWillAppear(_ animated: Bool) {
       super.viewWillAppear(animated)
       
       if let mode = mode {
           let controller = self.controller(for: mode)
           controller.viewWillAppear(animated)
       }
   }
   
   override func viewWillDisappear(_ animated: Bool) {
       super.viewWillDisappear(animated)
       window?.removeAllHandlers(for: self)
       
       if let mode = mode {
           let controller = self.controller(for: mode)
           controller.viewWillDisappear(animated)
       }
   }
   
   func notify(with value: Any, oldValue: Any, animated: Bool) {
       if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
           
           let context = self.context
           if value.selectionState != oldValue.selectionState {
               
           }
           
           if (value.state == .selecting) != (oldValue.state == .selecting) {
               self.state = value.state == .selecting ? .Edit : .Normal
               
               doneButton?.isHidden = value.state != .selecting
               editButton?.isHidden = value.state == .selecting

               genericView.changeState(selectState: value.state == .selecting, animated: animated)
           }
           
       }
   }
   
   
   func isEqual(to other: Notifable) -> Bool {
       if let other = other as? PeerMediaController {
           return self == other
       }
       return false
   }
   
   override func viewDidLoad() {
       super.viewDidLoad()
       

       genericView.updateInteraction(interactions)
       
       let tagsList = self.tagsList
       
       let context = self.context
       let peerId = self.peerId
       
       
       
       let data: Signal<State, NoError> = statePromise.get() |> deliverOnMainQueue |> mapToSignal { [weak self] state in
           guard let `self` = self else {
               return .complete()
           }
           if let selected = state.selected {
               switch selected {
               case .peers:
                   if !self.members.isLoaded() {
                       self.members.loadViewIfNeeded(self.genericView.view.bounds)
                   }
                   return self.members.ready.get() |> map { ready in
                       return state
                   }
               default:
                   return .single(state)
               }
           } else {
               return .single(state)
           }
       } |> deliverOnMainQueue
       
       let ready = data |> map { _ in return true } |> take(1)
       
       self.ready.set(ready)
       
       genericView.segmentPanelView.segmentControl.didChangeSelectedItem = { [weak self] item in
           let newMode = StorageUsageCollectionMode(rawValue: item.uniqueId)!
           
           if newMode == self?.mode, let mainTable = self?.genericView.mainTable {
               self?.currentMainTableView?(mainTable, true, true)
           }
           self?.updateState { current in
               var current = current
               current.selected = newMode
               return current
           }
       }
       
       interactions.forwardMessages = { messageIds in
       }
       interactions.focusMessageId = { _, focusMessageId, _ in
       }
       interactions.inlineAudioPlayer = { controller in
       }
       interactions.openInfo = { (peerId, toChat, postId, action) in
       }
       interactions.deleteMessages = { messageIds in
       }
       

       var first = true

       disposable.set(data.start(next: { [weak self] state in
           guard let `self` = self else {
               return
           }
           var items:[ScrollableSegmentItem] = []
           let insets = NSEdgeInsets(left: 10, right: 10, bottom: 2)
           let segmentTheme = ScrollableSegmentTheme(background: .clear, border: .clear, selector: theme.colors.accent, inactiveText: theme.colors.grayText, activeText: theme.colors.accent, textFont: .normal(.title))
           
           for (i, tab) in state.tabs.enumerated() {
               items.append(ScrollableSegmentItem(title: tab.title, index: i, uniqueId: tab.rawValue, selected: state.selected == tab, insets: insets, icon: nil, theme: segmentTheme, equatable: nil))
           }
           self.genericView.segmentPanelView.segmentControl.updateItems(items, animated: !first)
           
           if let selected = state.selected {
               self.toggle(with: selected, animated: !first)
               
           }
           
           first = false
           
           if state.tabs.isEmpty {
               if self.genericView.superview != nil {
                   self.viewWillDisappear(true)
                   self.genericView.removeFromSuperview()
                   self.viewDidDisappear(true)
               }
           }
       }))

   }
   
   
   private var currentTable: TableView? {
       return nil
   }
   
   private func applyReadyController(mode: StorageUsageCollectionMode, animated: Bool) {
       genericView.mainTable?.updatedItems = nil
       let oldMode = self.mode
       
       let previous = self.currentController
       
       let controller = self.controller(for: mode)
       
       self.currentController = controller
       controller.viewWillAppear(animated)
       previous?.viewWillDisappear(animated)
       controller.view.frame = self.genericView.view.bounds
       let animation: AnimationDirection?
       
       if animated, let oldMode = oldMode {
           if oldMode.rawValue > mode.rawValue {
               animation = .rightToLeft
           } else {
               animation = .leftToRight
           }
       } else {
           animation = nil
       }
       
       genericView.updateMainView(with: controller.view, animated: animation)
       controller.viewDidAppear(animated)
       previous?.viewDidDisappear(animated)
       
       var firstUpdate: Bool = true
       genericView.mainTable?.updatedItems = { [weak self] items in
           let filter = items.filter {
               !($0 is PeerMediaEmptyRowItem) && !($0.className == "Telegram.GeneralRowItem") && !($0 is SearchEmptyRowItem)
           }
           self?.genericView.updateCorners(filter.isEmpty ? .all : [.topLeft, .topRight], animated: !firstUpdate)
           firstUpdate = false
       }
       self.currentMainTableView?(genericView.mainTable, animated, previous != controller && genericView.segmentPanelView.segmentControl.contains(oldMode?.rawValue ?? -3))
       
       updateState { current in
           var current = current
           current.selected = mode
           return current
       }
   }
   
   private func controller(for mode: StorageUsageCollectionMode) -> ViewController {
       return self.members
   }
   
   private func toggle(with mode:StorageUsageCollectionMode, animated:Bool = false) {
       let isUpdated = self.mode != mode
       if isUpdated {
           let controller: ViewController = self.controller(for: mode)

           let ready = controller.ready.get() |> take(1)
           
           toggleDisposable.set(ready.start(next: { [weak self] _ in
               self?.applyReadyController(mode: mode, animated: animated)
           }))
       } else {
           self.currentMainTableView?(genericView.mainTable, animated, false)
       }
       self.mode = mode
   }
   
   deinit {
       disposable.dispose()
       toggleDisposable.dispose()
   }
   
   override func updateLocalizationAndTheme(theme: PresentationTheme) {
       super.updateLocalizationAndTheme(theme: theme)
       
       
   }
   
   override public func update(with state:ViewControllerState) -> Void {
       super.update(with:state)
       interactions.update({state == .Normal ? $0.withoutSelectionState() : $0.withSelectionState()})
   }
   
   override func escapeKeyAction() -> KeyHandlerResult {
       if interactions.presentation.state == .selecting {
           interactions.update { $0.withoutSelectionState() }
           return .invoked
       } else {
           return super.escapeKeyAction()
       }
   }
    
    var onTheTop: Bool {
        return true
    }
   
   
   override var defaultBarTitle: String {
       return super.defaultBarTitle
   }
   
   override func backSettings() -> (String, CGImage?) {
       return super.backSettings()
   }
   
   override func didRemovedFromStack() {
       super.didRemovedFromStack()
   }
   
}




