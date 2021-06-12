//
//  DesktopCapturerWindow.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TgVoipWebrtc
import SwiftSignalKit


struct DesktopCapturerObjectWrapper : Equatable {
    static func == (lhs: DesktopCapturerObjectWrapper, rhs: DesktopCapturerObjectWrapper) -> Bool {
        if !lhs.source.isEqual(rhs.source) {
            return false
        }
        if lhs.isAvailableToStream != rhs.isAvailableToStream {
            return false
        }
        return true
    }

    let source: VideoSourceMac
    let isAvailableToStream: Bool
}


final class CameraCaptureDevice : VideoSourceMac, Equatable {
    func isEqual(_ another: Any) -> Bool {
        if let another = another as? VideoSourceMac {
            return another.uniqueKey() == self.uniqueKey()
        } else {
            return false
        }
    }
    
    let device: AVCaptureDevice
    init(_ device: AVCaptureDevice) {
        self.device = device
    }
    func deviceIdKey() -> String {
        return self.device.uniqueID
    }
    func title() -> String {
        return device.localizedName
    }
    func uniqueKey() -> String {
        return self.device.uniqueID
    }
    static func ==(lhs: CameraCaptureDevice, rhs: CameraCaptureDevice) -> Bool {
        return lhs.device == rhs.device
    }
}

private final class DesktopCaptureListArguments {
    let selectDesktop:(DesktopCaptureSourceMac, DesktopCaptureSourceManagerMac)->Void
    let selectCamera:(CameraCaptureDevice)->Void

    init(selectDesktop:@escaping(DesktopCaptureSourceMac, DesktopCaptureSourceManagerMac)->Void, selectCamera:@escaping(CameraCaptureDevice)->Void) {
        self.selectDesktop = selectDesktop
        self.selectCamera = selectCamera
    }
}

private struct DesktopCaptureListState : Equatable {

    struct Access : Equatable {
        let sharing: Bool
        let camera: Bool
    }

    var cameras:[CameraCaptureDevice]
    var screens: [DesktopCaptureSourceMac]
    var windows: [DesktopCaptureSourceMac]
    var selected: VideoSourceMac?
    var access:Access
    init(cameras: [CameraCaptureDevice], screens: [DesktopCaptureSourceMac], windows: [DesktopCaptureSourceMac], selected: VideoSourceMac?, access: Access) {
        self.cameras = cameras
        self.screens = screens
        self.windows = windows
        self.selected = selected
        self.access = access
    }
    static func ==(lhs: DesktopCaptureListState, rhs: DesktopCaptureListState) -> Bool {
        let listEquals = lhs.cameras == rhs.cameras && lhs.screens == rhs.screens && lhs.windows == rhs.windows
        
        if !listEquals {
            return false
        }
        if let lhsSelected = lhs.selected, let rhsSelected = rhs.selected {
            if !lhsSelected.isEqual(rhsSelected) {
                return false
            }
        } else if (lhs.selected != nil) != (rhs.selected != nil) {
            return false
        }
        if lhs.access != rhs.access {
            return false
        }
        return true
    }
}

private func entries(_ state: DesktopCaptureListState, screens: DesktopCaptureSourceManagerMac?, windows: DesktopCaptureSourceManagerMac?, excludeWindowNumber: Int = 0, arguments: DesktopCaptureListArguments) -> [InputDataEntry] {
        
    var entries:[InputDataEntry] = []
    
    struct DesktopTuple : Equatable {
        let source: DesktopCaptureSourceMac
        let selected: Bool
        let isAvailable: Bool
    }
    struct CameraTuple : Equatable {
        let source: CameraCaptureDevice
        let selected: Bool
        let isAvailable: Bool
    }
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("\(sectionId)"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 15, stableId: stableId, backgroundColor: .clear)
    }))
    sectionId += 1
    
    
    for source in state.cameras {
        let id: String = source.uniqueKey()
        let selected = state.selected != nil ? source.isEqual(state.selected!) : false
        let tuple = CameraTuple(source: source, selected: selected, isAvailable: state.access.camera)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(id), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
            return DesktopCameraCapturerRowItem(initialSize, stableId: stableId, device: tuple.source, isAvailable: tuple.isAvailable, isSelected: tuple.selected, select: arguments.selectCamera)
        }))
        index += 1
    }
    
    for source in state.screens {
        let id: String = source.uniqueKey()
        let selected = state.selected != nil ? source.isEqual(state.selected!) : false
        let tuple = DesktopTuple(source: source, selected: selected, isAvailable: state.access.sharing)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(id), equatable: InputDataEquatable(tuple), comparable: nil, item: { [weak screens] initialSize, stableId in
            return DesktopCapturePreviewItem(initialSize, stableId: stableId, source: tuple.source, isAvailable: tuple.isAvailable, isSelected: tuple.selected, manager: screens, select: arguments.selectDesktop)
        }))
        index += 1
    }
    
    for source in state.windows {
        let id: String = source.uniqueKey()
        let selected = state.selected != nil ? source.isEqual(state.selected!) : false
        let tuple = DesktopTuple(source: source, selected: selected, isAvailable: state.access.sharing)
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(id), equatable: InputDataEquatable(tuple), comparable: nil, item: { [weak windows] initialSize, stableId in
            return DesktopCapturePreviewItem(initialSize, stableId: stableId, source: tuple.source, isAvailable: tuple.isAvailable, isSelected: tuple.selected, manager: windows, select: arguments.selectDesktop)
        }))
        index += 1
    }

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("\(sectionId)"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 15, stableId: stableId, backgroundColor: .clear)
    }))
    sectionId += 1
    
    return entries
}

private final class DesktopCaptureListView : View {
    fileprivate let tableView: HorizontalTableView
    required init(frame frameRect: NSRect) {
        tableView = HorizontalTableView(frame: frameRect.size.bounds, isFlipped: true, bottomInset: 0, drawBorder: false)
        super.init(frame: frameRect)
        addSubview(tableView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        tableView.frame = bounds
    }
}

final class DesktopCaptureListUI {
    
    private var windows: DesktopCaptureSourceManagerMac!
    private var screens: DesktopCaptureSourceManagerMac!

    private var updateDisposable: Disposable?
    private let disposable: MetaDisposable = MetaDisposable()
    private let devicesDisposable = MetaDisposable()

    private let mode: VideoSourceMacMode
    private let devices: DevicesContext
    private var _frame: NSRect
    private var _view:NSView?
    
    private var onDeinit: (()->Void)? = nil
    private let atomicSize:Atomic<NSSize> = Atomic(value:NSZeroSize)

    init(size: NSSize, devices: DevicesContext, mode: VideoSourceMacMode) {
        _frame = size.bounds
        self.devices = devices
        self.mode = mode
        loadViewIfNeeded()
    }
    
    func loadViewIfNeeded(_ frame:NSRect = NSZeroRect) -> Void {
        
         guard _view != nil else {
            if !NSIsEmptyRect(frame) {
                _frame = frame
            }
            let vz = viewClass() as! NSView.Type
            _view = vz.init(frame: _frame);
            _view?.autoresizingMask = [.width,.height]
                        
            NotificationCenter.default.addObserver(self, selector: #selector(viewFrameChanged(_:)), name: NSView.frameDidChangeNotification, object: _view!)
            
            _ = atomicSize.swap(_view!.frame.size)

            
            viewDidLoad()
            
            return
        }
    }
    var view:NSView {
        get {
            return _view!;
        }
       
    }

    @objc func viewFrameChanged(_ notification:Notification) {
        if atomicSize.with({ $0 != view.frame.size }) {
            viewDidResized(view.frame.size)
        }
    }
    
    private func viewDidResized(_ size:NSSize) {
        _ = atomicSize.swap(size)
    }
    
    var updateDesktopSelected:((DesktopCapturerObjectWrapper, DesktopCaptureSourceManagerMac)->Void)? = nil
    var updateCameraSelected:((DesktopCapturerObjectWrapper)->Void)? = nil

    
    private func viewClass() -> AnyClass {
        return DesktopCaptureListView.self
    }
    
    var excludeWindowNumber: Int = 0
    
    private var getCurrentlySelected: (()->VideoSourceMac?)? = nil
    var selected: VideoSourceMac? {
        return self.getCurrentlySelected?()
    }
    
    func viewDidLoad() {
        
        self.windows = DesktopCaptureSourceManagerMac(_w: ())
        self.screens = DesktopCaptureSourceManagerMac(_s: ())

        let actionsDisposable = DisposableSet()
        
        var hasCameraAccess = false
        var requestCamera = false
        if #available(OSX 10.14, *) {
            let camera = AVCaptureDevice.authorizationStatus(for: .video)
            switch camera {
            case .authorized:
                hasCameraAccess = true
            case .notDetermined:
                requestCamera = true
            default:
                break
            }
        } else {
            hasCameraAccess = true
        }

        var sList:[DesktopCaptureSourceMac] = []
        var wList: [DesktopCaptureSourceMac] = []
        var sharingAccess: Bool = false

        switch mode {
        case .screencast:
            sList = screens.list()
            sharingAccess = requestScreenCaptureAccess()
        case .video:
            wList = windows.list()
        }
        
        
        let initialState = DesktopCaptureListState(cameras: [], screens: sList, windows: wList, selected: nil, access: .init(sharing: sharingAccess, camera: hasCameraAccess))


        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((DesktopCaptureListState) -> DesktopCaptureListState) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        getCurrentlySelected = {
            stateValue.with { $0.selected }
        }
        
        self.onDeinit = {
            updateState { current in
                var current = current
                current.cameras = []
                current.screens = []
                current.selected = nil
                current.windows = []
                return current
            }
            actionsDisposable.dispose()
        }

        if requestCamera && mode == .video {
            actionsDisposable.add(requestCameraPermission().start(next: { access in
                updateState { state in
                    var state = state
                    state.access = DesktopCaptureListState.Access(sharing: state.access.sharing, camera: access)
                    return state
                }
            }))
        }
        
        let windows = self.windows
        let screens = self.screens
        
        let checkSelected = {
            updateState { current in
                var current = current
                if let selected = current.selected {
                    let windowsContains = current.windows.contains(where: {
                        $0.isEqual(selected)
                    })
                    let screensContains = current.screens.contains(where: {
                        $0.isEqual(selected)
                    })
                    let camerasContains = current.cameras.contains(where: {
                        $0.isEqual(selected)
                    })
                    if !windowsContains && !screensContains && !camerasContains {
                        current.selected = nil
                    }
                }
                if current.selected == nil {
                    current.selected = current.cameras.first ?? current.screens.first ?? current.windows.first
                }
                return current
            }
        }
        
        let updateSignal = Signal<NoValue, NoError> { [weak windows, weak screens] subscriber in
            
            updateState { current in
                var current = current
                current.screens = screens?.list() ?? []
                current.windows = windows?.list() ?? []
                return current
            }
            checkSelected()
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
        
        let updateSelected: Signal<VideoSourceMac?, NoError> = statePromise.get() |> map { $0.selected } |> distinctUntilChanged(isEqual:  { lhs, rhs in
            if let lhs = lhs, let rhs = rhs {
                return lhs.isEqual(rhs)
            } else if (lhs != nil) != (rhs != nil) {
                return false
            }
            return true
        })
        
        DispatchQueue.main.async {
            actionsDisposable.add(updateSelected.start(next: { [weak self, weak screens] selected in
                if let selected = selected as? DesktopCaptureSourceMac, let screens = screens {
                    self?.updateDesktopSelected?(DesktopCapturerObjectWrapper(source: selected, isAvailableToStream: stateValue.with { $0.access.sharing }), screens)
                } else if let selected = selected as? CameraCaptureDevice {
                    self?.updateCameraSelected?(DesktopCapturerObjectWrapper(source: selected, isAvailableToStream: stateValue.with { $0.access.camera }))
                }
            }))
        }
        
        switch mode {
        case .screencast:
            self.updateDisposable = ((updateSignal |> then(.complete() |> suspendAwareDelay(2, queue: .mainQueue()))) |> restart).start()
        case .video:
            devicesDisposable.set((devices.signal |> deliverOnMainQueue).start(next: { devices in
                updateState { current in
                    var current = current
                    current.cameras = devices.camera.filter { !$0.isSuspended && $0.isConnected }.map { CameraCaptureDevice($0) }
                    return current
                }
                checkSelected()
            }))
        }
        
        let arguments = DesktopCaptureListArguments(selectDesktop: { source, manager in
            updateState { current in
                var current = current
                current.selected = source
                return current
            }
        }, selectCamera: { source in
            updateState { current in
                var current = current
                current.selected = source
                return current
            }
        })
        
        let excludeWindowNumber = self.excludeWindowNumber

        
        let signal = statePromise.get() |> map { [weak windows, weak screens] state in
            return InputDataSignalValue(entries: entries(state, screens: screens, windows: windows, excludeWindowNumber: excludeWindowNumber, arguments: arguments))
        }
        
        let previous: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        
        let initialSize = self.atomicSize
        
        let transaction: Signal<TableUpdateTransition, NoError> = combineLatest(signal, appearanceSignal) |> mapToQueue { state, appearance in
            
            let entries = state.entries.map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return prepareInputDataTransition(left: previous.swap(entries), right: entries, animated: state.animated, searchState: nil, initialSize: initialSize.with { $0 }, arguments: InputDataArguments(select: {_, _ in }, dataUpdated: {}), onMainQueue: false)
        } |> deliverOnMainQueue
        
        genericView.needUpdateVisibleAfterScroll = true
        
        genericView.getBackgroundColor = {
            .clear
        }
        
        disposable.set(transaction.start(next: { [weak self] transaction in
            self?.genericView.merge(with: transaction)
            self?.readyOnce()
            checkSelected()
        }))

    }
    
    private let _ready = Promise<Bool>()
    var ready: Promise<Bool> {
        return self._ready
    }
    public var didSetReady:Bool = false
    
    private func readyOnce() -> Void {
        if !didSetReady {
            didSetReady = true
            ready.set(.single(true))
        }
    }
    
    private var genericView: HorizontalTableView {
        return (self.view as! DesktopCaptureListView).tableView
    }

    deinit {
        disposable.dispose()
        updateDisposable?.dispose()
        devicesDisposable.dispose()
        onDeinit?()
    }
    
}




private final class UnavailableToStreamView : View {
    let text: TextView = TextView()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(text)
        backgroundColor = .black
        self.text.isSelectable = false

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(isScreen: Bool) {
        let text: String
        //TODOLANG
        if isScreen {
            text = "Unavailable to share your screen, please grant access is [System Settings](screen)."
        } else {
            text = "Unavailable to share your camera, please grant access is [System Settings](camera)."
        }
        let attr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: GroupCallTheme.grayStatusColor), bold: MarkdownAttributeSet(font: .bold(.text), textColor: GroupCallTheme.grayStatusColor), link: MarkdownAttributeSet(font: .normal(.text), textColor: GroupCallTheme.accent), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents,  {_ in}))
        }))
        let layout = TextViewLayout(attr)
        let executor = globalLinkExecutor
        executor.processURL = { value in
            if let value = value as? inAppLink {
                switch value.link {
                case "screen":
                    openSystemSettings(.sharing)
                case "camera":
                    openSystemSettings(.camera)
                default:
                    break
                }
            }
        }
        layout.interactions = executor
        layout.measure(width: frame.width)
        self.text.update(layout)
    }

    override func layout() {
        super.layout()
        self.text.center()
    }
}

private final class DesktopCapturerView : View {
    private let listContainer = View()
    private let previewContainer = View()
    private let titleView = TextView()
    private let titleContainer = View()
    private let controls = View()
    
    let cancel = TitleButton()
    let share = TitleButton()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(listContainer)
        addSubview(previewContainer)
        
        addSubview(titleContainer)
        titleContainer.addSubview(titleView)
        addSubview(controls)
        previewContainer.layer?.cornerRadius = 10
        previewContainer.backgroundColor = .black
        backgroundColor = GroupCallTheme.windowBackground
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        layout()
        
        let titleLayout = TextViewLayout.init(.initialize(string: L10n.voiceChatVideoVideoSource, color: GroupCallTheme.titleColor, font: .medium(.title)))
        titleLayout.measure(width: frameRect.width)
        titleView.update(titleLayout)
        
        cancel.set(text: L10n.voiceChatVideoVideoSourceCancel, for: .Normal)
        cancel.set(color: .white, for: .Normal)
        cancel.set(background: GroupCallTheme.speakDisabledColor, for: .Normal)
        cancel.set(background: GroupCallTheme.speakDisabledColor.withAlphaComponent(0.8), for: .Highlight)
        cancel.sizeToFit(.zero, NSMakeSize(100, 30), thatFit: true)
        cancel.layer?.cornerRadius = .cornerRadius
        
        share.set(text: L10n.voiceChatVideoVideoSourceShare, for: .Normal)
        share.set(color: .white, for: .Normal)
        share.set(background: GroupCallTheme.accent, for: .Normal)
        share.set(background: GroupCallTheme.accent.withAlphaComponent(0.8), for: .Highlight)
        share.sizeToFit(.zero, NSMakeSize(100, 30), thatFit: true)
        share.layer?.cornerRadius = .cornerRadius
        
        controls.addSubview(cancel)
        controls.addSubview(share)
        
        cancel.scaleOnClick = true
        share.scaleOnClick = true

    }
    
    private var previousDesktop: (DesktopCaptureSourceScopeMac, DesktopCaptureSourceManagerMac)?
    
    func updatePreview(_ source: DesktopCaptureSourceMac, isAvailable: Bool, manager: DesktopCaptureSourceManagerMac, animated: Bool) {
        if let previous = previousDesktop {
            previous.1.stop(previous.0)
        }
        if isAvailable {
            let size = NSMakeSize(previewContainer.frame.width * 2.5, previewContainer.frame.size.height * 2.5)
            let scope = DesktopCaptureSourceScopeMac(source: source, data: DesktopCaptureSourceDataMac(size: size, fps: 24, captureMouse: true))
            let view = manager.create(forScope: scope)
            manager.start(scope)
            self.previousDesktop = (scope, manager)
            swapView(view, animated: animated)

        } else {
            let view = UnavailableToStreamView(frame: previewContainer.bounds)
            view.update(isScreen: true)
            swapView(view, animated: animated)
        }

        share.isEnabled = isAvailable
    }
    
    private func swapView(_ view: NSView, animated: Bool) {
        let previewView = previewContainer
        view.frame = previewView.bounds

        for previous in previewView.subviews {
            if animated {
                previous.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak previous] _ in
                    previous?.removeFromSuperview()
                })
            } else {
                previous.removeFromSuperview()
            }
        }
        previewView.addSubview(view)
        if animated {
            view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        }

    }
    
    func updatePreview(_ source: CameraCaptureDevice, isAvailable: Bool, animated: Bool) {
        if let previous = previousDesktop {
            previous.1.stop(previous.0)
        }

        if isAvailable {
            let view: View = View()
            let session: AVCaptureSession = AVCaptureSession()
            let input = try? AVCaptureDeviceInput(device: source.device)
            if let input = input {
                session.addInput(input)
            }
            let captureLayer = AVCaptureVideoPreviewLayer(session: session)
            captureLayer.connection?.automaticallyAdjustsVideoMirroring = false
            captureLayer.connection?.isVideoMirrored = true
            captureLayer.videoGravity = .resizeAspectFill
            view.layer = captureLayer


            swapView(view, animated: animated)

            session.startRunning()

        } else {
            let view = UnavailableToStreamView(frame: previewContainer.bounds)
            view.update(isScreen: false)
            swapView(view, animated: animated)

        }
        previousDesktop = nil
        share.isEnabled = isAvailable
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var listView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let value = listView {
                listContainer.addSubview(value)
            }
        }
    }
    
    override func layout() {
        super.layout()
        previewContainer.frame = .init(origin: .init(x: 20, y: 53), size: .init(width: 660, height: 360))
        listContainer.frame = .init(origin: .init(x: 0, y: frame.height - 90 - 80), size: .init(width: frame.width, height: 90))
        if let listView = listView {
            listView.frame = listContainer.bounds
        }
        titleContainer.frame = NSMakeRect(0, 0, frame.width, 53)
        titleView.center()
        
        controls.frame = NSMakeRect(0, frame.height - 80, frame.width, 80)
        
        cancel.centerY(x: frame.midX - cancel.frame.width - 5)
        share.centerY(x: frame.midX + 5)

    }
}

final class DesktopCapturerWindow : Window {
    
    private let listController: DesktopCaptureListUI
    let mode: VideoSourceMacMode
    fileprivate let select: (VideoSourceMac)->Void
    init(mode: VideoSourceMacMode, select: @escaping(VideoSourceMac)->Void, devices: DevicesContext) {
        self.mode = mode
        self.select = select
        let size = NSMakeSize(700, 600)
        listController = DesktopCaptureListUI(size: NSMakeSize(size.width, 90), devices: devices, mode: mode)
        
        var rect: NSRect = .init(origin: .zero, size: size)
        if let screen = NSScreen.main {
            let x = floorToScreenPixels(System.backingScale, (screen.frame.width - size.width) / 2)
            let y = floorToScreenPixels(System.backingScale, (screen.frame.height - size.height) / 2)
            rect = .init(origin: .init(x: x, y: y), size: size)
        }

        super.init(contentRect: rect, styleMask: [.fullSizeContentView, .borderless, .closable, .titled], backing: .buffered, defer: true)
        self.minSize = NSMakeSize(700, 600)
        self.name = "DesktopCapturerWindow"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .visible
        self.animationBehavior = .alertPanel
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = true
        self.level = .normal
        self.toolbar = NSToolbar(identifier: "window")
        self.toolbar?.showsBaselineSeparator = false
        
        
        initSaver()
    }
    
    func initGuts() {
        
        self.contentView = DesktopCapturerView(frame: .init(origin: .zero, size: self.frame.size))

        var first: Bool = true

        
        listController.updateDesktopSelected = { [weak self] wrap, manager in
            self?.genericView.updatePreview(wrap.source as! DesktopCaptureSourceMac, isAvailable: wrap.isAvailableToStream, manager: manager, animated: !first)
            first = false
        }
        
        listController.updateCameraSelected = { [weak self] wrap in
            self?.genericView.updatePreview(wrap.source as! CameraCaptureDevice, isAvailable: wrap.isAvailableToStream, animated: !first)
            first = false
        }
        
        
        self.listController.excludeWindowNumber = self.windowNumber
        self.genericView.listView = listController.view

        
        self.genericView.cancel.set(handler: { [weak self] _ in
            self?.orderOut(nil)
        }, for: .Click)
        
        self.genericView.share.set(handler: { [weak self] _ in
            self?.orderOut(nil)
            if let source = self?.listController.selected {
                delay(1.0, closure: {
                    self?.select(source)
                })
            }
        }, for: .Click)

    }
    
    private var genericView:DesktopCapturerView {
        return self.contentView as! DesktopCapturerView
    }
    
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        
        var point: NSPoint = NSMakePoint(20, 17)
        self.standardWindowButton(.closeButton)?.setFrameOrigin(point)
        point.x += 20
        self.standardWindowButton(.miniaturizeButton)?.setFrameOrigin(point)
        point.x += 20
        self.standardWindowButton(.zoomButton)?.setFrameOrigin(point)
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}

enum VideoSourceMacMode {
    case video
    case screencast
    
    var viceVersa: VideoSourceMacMode {
        switch self {
        case .video:
            return .screencast
        case .screencast:
            return .video
        }
    }
}
extension VideoSourceMac {
    
    var mode: VideoSourceMacMode {
        if self is DesktopCaptureSourceMac {
            return .screencast
        } else {
            return .video
        }
    }
}

func presentDesktopCapturerWindow(mode: VideoSourceMacMode,select: @escaping(VideoSourceMac)->Void, devices: DevicesContext) -> DesktopCapturerWindow? {
    
    switch mode {
    case .video:
        let devices = AVCaptureDevice.devices(for: .video).filter({ $0.isConnected && !$0.isSuspended })
        if devices.isEmpty {
            return nil
        }
    case .screencast:
        break
    }
    
    let window = DesktopCapturerWindow(mode: mode, select: select, devices: devices)
    window.initGuts()
    window.makeKeyAndOrderFront(nil)
    
    return window
}
