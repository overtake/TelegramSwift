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


enum StorageUsageCollection : Int32 {
    case peers
    case media
    case files
    case music
    case voice
    
    var title: String {
        switch self {
        case .peers:
            return strings().storageUsageSegmentChats
        case .media:
            return strings().storageUsageSegmentMedia
        case .files:
            return strings().storageUsageSegmentFiles
        case .music:
            return strings().storageUsageSegmentMusic
        case .voice:
            return strings().storageUsageSegmentVoice
        }
    }
}



class StorageUsageBlockController: TelegramGenericViewController<StorageUsageMediaContainerView> {
   
    
    private let members: ViewController
    private let media: ViewController
    private let files: ViewController
    private let music: ViewController
    private let voice: ViewController

    private var currentController: ViewController?

    private var mode: StorageUsageCollection?
   
    private var currentTagListIndex: Int {
       if let mode = self.mode {
           return Int(mode.rawValue)
       } else {
           return 0
       }
    }
    private let toggleDisposable = MetaDisposable()
    private let disposable = MetaDisposable()

    
    var currentMainTableView:((TableView?, Bool, Bool)->Void)? = nil {
        didSet {
            if isLoaded() {
                currentMainTableView?(genericView.mainTable, false, false)
            }
        }
    }
    
    private let stateSignal:Signal<StorageUsageUIState, NoError>
    private let updateState:((StorageUsageUIState)->StorageUsageUIState)->StorageUsageUIState
   
    init(context: AccountContext, storageArguments: StorageUsageArguments, state: Signal<StorageUsageUIState, NoError>, updateState:@escaping((StorageUsageUIState)->StorageUsageUIState)->StorageUsageUIState) {
        self.updateState = updateState
        self.stateSignal = state
        
        self.members = StorageUsage_Block_Chats(context: context, storageArguments: storageArguments, state: state, updateState: updateState)
        self.files = StorageUsage_Block_MediaList(context: context, storageArguments: storageArguments, tag: .files, state: state, updateState: updateState)
        self.media = StorageUsage_Block_MediaList(context: context, storageArguments: storageArguments, tag: .media, state: state, updateState: updateState)
        self.music = StorageUsage_Block_MediaList(context: context, storageArguments: storageArguments, tag: .music, state: state, updateState: updateState)
        self.voice = StorageUsage_Block_MediaList(context: context, storageArguments: storageArguments, tag: .voice, state: state, updateState: updateState)
        super.init(context)
        
        self.navigationController = context.bindings.rootNavigation()
   }

   var unableToHide: Bool {
       return !onTheTop
   }
   
   override func viewDidAppear(_ animated: Bool) {
       super.viewDidAppear(animated)
       
       if let mode = self.mode {
           self.controller(for: mode).viewDidAppear(animated)
       }
   }
    
   
   override func viewDidDisappear(_ animated: Bool) {
       super.viewDidDisappear(animated)
       
       if let mode = mode {
           let controller = self.controller(for: mode)
           controller.viewDidDisappear(animated)
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
   
   
   func isEqual(to other: Notifable) -> Bool {
       if let other = other as? PeerMediaController {
           return self == other
       }
       return false
   }
   
   override func viewDidLoad() {
       super.viewDidLoad()
       
       
       
       let context = self.context
       
       
       let data: Signal<StorageUsageUIState, NoError> = stateSignal |> deliverOnMainQueue |> mapToSignal { [weak self] state in
           guard let `self` = self else {
               return .complete()
           }
           var list:[StorageUsageCollection : ViewController] = [:]
           list[.peers] = self.members
           list[.files] = self.files
           list[.media] = self.media
           list[.music] = self.music
           list[.voice] = self.voice

           if let collection = state.effectiveCollection {
               let controller = list[collection]!
               if !controller.isLoaded() {
                   controller.loadViewIfNeeded(self.genericView.view.bounds)
               }
               return controller.ready.get() |> map { ready in
                   return state
               }
           } else {
               return .complete()
           }
           
       } |> distinctUntilChanged(isEqual: { lhs, rhs in
           if lhs.messages != rhs.messages {
               return false
           } else if lhs.segments != rhs.segments {
               return false
           } else if lhs.collection != rhs.collection {
               return false
           } else {
               return true
           }
       }) |> deliverOnMainQueue
       
       let ready = data |> map { _ in return true } |> take(1)
       
       self.ready.set(ready)
       
       genericView.segmentPanelView.segmentControl.didChangeSelectedItem = { [weak self] item in
           let newMode = StorageUsageCollection(rawValue: Int32(item.uniqueId))!
           
           if newMode == self?.mode, let mainTable = self?.genericView.mainTable {
               self?.currentMainTableView?(mainTable, true, true)
           }
           _ = self?.updateState { current in
               var current = current
               current.collection = newMode
               return current
           }
       }
       
       var first = true

       disposable.set(data.start(next: { [weak self] state in
           guard let `self` = self else {
               return
           }
           var items:[ScrollableSegmentItem] = []
           let insets = NSEdgeInsets(left: 10, right: 10, bottom: 2)
           let segmentTheme = ScrollableSegmentTheme(background: .clear, border: .clear, selector: theme.colors.accent, inactiveText: theme.colors.grayText, activeText: theme.colors.accent, textFont: .normal(.title))
           
           for (i, tab) in state.segments.enumerated() {
               items.append(ScrollableSegmentItem(title: tab.title, index: i, uniqueId: Int64(tab.rawValue), selected: state.effectiveCollection == tab, insets: insets, icon: nil, theme: segmentTheme, equatable: nil))
           }
           self.genericView.segmentPanelView.segmentControl.updateItems(items, animated: !first)
           
           if let collection = state.effectiveCollection {
               self.toggle(with: collection, animated: !first)
           }
           
           first = false
           
           if state.segments.isEmpty {
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
   
   private func applyReadyController(mode: StorageUsageCollection, animated: Bool) {
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
       
   }
   
   private func controller(for mode: StorageUsageCollection) -> ViewController {
       switch mode {
       case .media:
           return self.media
       case .music:
           return self.music
       case .files:
           return self.files
       case .peers:
           return self.members
       case .voice:
           return self.voice
       }
   }
   
   private func toggle(with mode:StorageUsageCollection, animated:Bool = false) {
       let isUpdated = self.mode != mode
       if isUpdated {
           let controller: ViewController = self.controller(for: mode)

           let ready = controller.ready.get() |> take(1)
           
           toggleDisposable.set(ready.start(next: { [weak self] _ in
               self?.applyReadyController(mode: mode, animated: animated)
           }))
       } else {
           self.currentMainTableView?(genericView.mainTable, animated, true)
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
   
   override func escapeKeyAction() -> KeyHandlerResult {
       return super.escapeKeyAction()
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




