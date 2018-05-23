//
//  InstantViewWindow.swift
//  Telegram
//
//  Created by keepcoder on 22/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
private final class InstantViewArguments {
    let account: Account
    let share:()->Void
    let back:()->Void
    let openInSafari:()->Void
    let enableSansSerif:(Bool)->Void
    init(account: Account, share: @escaping()->Void, back: @escaping()->Void, openInSafari: @escaping()->Void, enableSansSerif:@escaping(Bool)->Void) {
        self.account = account
        self.share = share
        self.back = back
        self.enableSansSerif = enableSansSerif
        self.openInSafari = openInSafari
    }
}

private class HeaderView : View {
    private var titleView: TextView?
    private let borderView: View = View()
    fileprivate let share: ImageButton = ImageButton()
    fileprivate let actions: ImageButton = ImageButton()
    fileprivate let safari: ImageButton = ImageButton()
    fileprivate let back: ImageButton = ImageButton()
    fileprivate var presenation: InstantViewAppearance = InstantViewAppearance.defaultSettings

    fileprivate var arguments: InstantViewArguments? {
        didSet {
            safari.removeAllHandlers()
            share.removeAllHandlers()
            back.removeAllHandlers()
            
            safari.set(handler: { [weak self] _ in
                self?.arguments?.openInSafari()
            }, for: .Click)
            back.set(handler: { [weak self] _ in
                self?.arguments?.back()
            }, for: .Click)
            share.set(handler: { [weak self] _ in
                self?.arguments?.share()
            }, for: .Click)
            
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        initialize()
    }
    
    private func initialize() {
        updateLocalizationAndTheme()
        addSubview(borderView)
        addSubview(share)
        addSubview(actions)
        addSubview(back)
        addSubview(safari)
        
        actions.set(handler: { [weak self] control in
            if let strongSelf = self {
                var items:[SPopoverItem] = []
                items.append(SPopoverItem("San Francisco", { [weak strongSelf] in
                    strongSelf?.arguments?.enableSansSerif(false)
                }, strongSelf.presenation.fontSerif ? nil : theme.icons.instantViewCheck))
                
                items.append(SPopoverItem("Georgia", { [weak strongSelf] in
                    strongSelf?.arguments?.enableSansSerif(true)
                }, !strongSelf.presenation.fontSerif ? nil : theme.icons.instantViewCheck))
                
                showPopover(for: control, with: SPopoverViewController(items: items), edge: .maxY, inset: NSMakePoint(-80,  control.frame.height + 80))
            }
            
        }, for: .Click)
        
    }
    
    override init() {
        super.init(frame: NSZeroRect)
        initialize()
    }
    
    func updateTitle(_ title:String, animated: Bool) {
        let layout: TextViewLayout = TextViewLayout(.initialize(string: title, color: theme.colors.text, font: .normal(.title)), maximumNumberOfLines: 2, alignment: .center)
        layout.measure(width: frame.width - 280)
        let view = TextView()
        view.backgroundColor = theme.colors.background
        view.isSelectable = false
        view.userInteractionEnabled = false
        view.update(layout)
        
        view.center(self)
        view.setFrameOrigin(view.frame.minX, view.frame.minY - 1)
        if animated {
            addSubview(view)
            view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak self, weak view] completed in
                if completed {
                    self?.titleView?.removeFromSuperview()
                    self?.titleView = view
                }
            })
            titleView?.change(opacity: 0, timingFunction: kCAMediaTimingFunctionSpring)
        } else {
            titleView?.removeFromSuperview()
            titleView = view
            addSubview(view)
        }
        needsLayout = true
    }
    
    func updateBorder(_ isVisible: Bool, animated: Bool) {
        borderView.change(opacity: isVisible ? 1 : 0, animated: animated)
    }
    
    func updateBackVisiblity(_ isVisible: Bool, animated: Bool) {
        back.change(opacity: isVisible ? 1 : 0, animated: animated)
    }
    
    override func layout() {
        super.layout()
        titleView?.layout?.measure(width: frame.width - 280)
        titleView?.update(titleView?.layout)
        titleView?.center()
        if let titleView = titleView {
            titleView.setFrameOrigin(titleView.frame.minX, titleView.frame.minY - 1)
        }

        borderView.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        
        actions.centerY(x: frame.width - actions.frame.width - 19)
        share.centerY(x: actions.frame.minX - share.frame.width - 10)
        safari.centerY(x: share.frame.minX - safari.frame.width - 10)
        back.centerY(x: 86)
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        borderView.backgroundColor = theme.colors.border
        backgroundColor = theme.colors.background
        titleView?.backgroundColor = theme.colors.background
        
        let nLayout = TextViewLayout(.initialize(string: titleView?.layout?.attributedString.string, color: theme.colors.text, font: .normal(.title)), maximumNumberOfLines: 2, alignment: .center)
        titleView?.update(nLayout)
        share.set(image: theme.icons.instantViewShare, for: .Normal)
        actions.set(image: theme.icons.instantViewActions, for: .Normal)
        actions.set(image: theme.icons.instantViewActionsActive, for: .Highlight)
        safari.set(image: theme.icons.instantViewSafari, for: .Normal)
        back.set(image: theme.icons.instantViewBack, for: .Normal)
        
        share.sizeToFit()
        actions.sizeToFit()
        safari.sizeToFit()
        back.sizeToFit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class InstantWindowContentView : View {
    private let headerView: HeaderView = HeaderView(frame: NSZeroRect)
    private let contentView: View = View()
    fileprivate var arguments: InstantViewArguments? {
        didSet {
            headerView.arguments = arguments
        }
    }
    fileprivate var presenation: InstantViewAppearance = InstantViewAppearance.defaultSettings {
        didSet {
            headerView.presenation = presenation
        }
    }

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(contentView)
        flip = false
        contentView.autoresizesSubviews = false
        layout()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        contentView.backgroundColor = theme.colors.background
        backgroundColor = theme.colors.background
    }
    
    func updateTitle(_ title:String, animated: Bool) {
        headerView.updateTitle(title, animated: animated)
    }
    
    func updateBorder(_ isVisible: Bool, animated: Bool) {
        headerView.updateBorder(isVisible, animated: animated)
    }
    func updateBackVisiblity(_ isVisible: Bool, animated: Bool) {
        headerView.updateBackVisiblity(isVisible, animated: animated)
    }
    
    func addContentView(_ view: NSView) {
        view.autoresizingMask = []
        view.frame = contentView.bounds
        contentView.addSubview(view)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        headerView.frame = NSMakeRect(0, frame.height - barHeight, frame.width, barHeight)
        contentView.frame = NSMakeRect(0, 0, frame.width, frame.height - headerView.frame.height)
        contentView.subviews.first?.frame = contentView.bounds
    }
}

fileprivate let barHeight: CGFloat = 50

private var instantController:InstantViewController?



class InstantViewController : TelegramGenericViewController<InstantWindowContentView> {
    fileprivate let navigation: MajorNavigationController
    private let page: InstantPageViewController
    
    fileprivate let _window:Window
    private let appearanceDisposable = MetaDisposable()
    init( page: InstantPageViewController, account: Account) {
        navigation = MajorNavigationController(ViewController.self, page)
        navigation.alwaysAnimate = true
        let screen = NSScreen.main!
        
        self.page = page
        
        let height = (screen.frame.height * 0.7)
        let center = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (screen.frame.width - 720)/2), floorToScreenPixels(scaleFactor: System.backingScale, (screen.frame.height - height)/2), 720, height)
        
        _window = Window(contentRect: center, styleMask: [.closable, .resizable, .miniaturizable, .fullSizeContentView, .titled, .unifiedTitleAndToolbar, .texturedBackground], backing: .buffered, defer: true)
       
        super.init(account)
        _window.isMovableByWindowBackground = false
        _window.name = "Telegram.InstantViewWindow"
        _window.initSaver()
        _window.contentView = genericView
        _window.titleVisibility = .hidden
        navigation._frameRect = NSMakeRect(0, 0, genericView.frame.width, genericView.frame.height - barHeight)
        
        _window.titlebarAppearsTransparent = true
        _window.minSize = NSMakeSize(500, 600)
        genericView.customHandler.layout = { [weak self] _ in
            self?.windowDidNeedSaveState(Notification(name: Notification.Name(rawValue: "")))
        }
        
        windowDidNeedSaveState(Notification(name: Notification.Name(rawValue: "")))
        
        
        navigation.add(listener: WeakReference(value: self))
        
        page.pageDidScrolled = { [weak self] value in
            self?.genericView.updateBorder(value.position.rect.minY - value.documentSize.height > 0, animated: true)
        }
        
        let arguments = InstantViewArguments(account: account, share: { [weak self] in
            self?.share()
        }, back: { [weak self] in
            self?.navigation.back()
        }, openInSafari: { [weak self] in
            self?.openInSafari()
        }, enableSansSerif: { [weak self] enable in
            if let strongSelf = self {
                _ = updateInstantViewAppearanceSettingsInteractively(postbox: strongSelf.account.postbox, {$0.withUpdatedFontSerif(enable)}).start()
            }
        })

        genericView.arguments = arguments
        appearanceDisposable.set((ivAppearance(postbox: account.postbox) |> deliverOnMainQueue).start(next: { [weak self] appearance in
            self?.genericView.presenation = appearance
        }))
        
        _window.closeInterceptor = { [weak self] in
            if let window = self?._window, !window.styleMask.contains(.fullScreen) {
                self?._window.orderOut(nil)
                instantController = nil
            }
            return true
        }
        
        let closeKeyboardHandler:()->KeyHandlerResult = { [weak self] in
            if let window = self?._window {
                if !window.styleMask.contains(.fullScreen) {
                    self?._window.orderOut(nil)
                    instantController = nil
                }
            }
			
            return .invoked
        }
        
        _window.set(handler: { [weak page] in
            page?.scrollPage(direction: .up)
            return .invoked
        }, with: self, for: .UpArrow, priority: .medium)
        
        _window.set(handler: { [weak page] in
            page?.scrollPage(direction: .down)
            return .invoked
        }, with: self, for: .DownArrow, priority: .medium)

        
        _window.set(handler: closeKeyboardHandler, with: self, for: .Escape)
		if FastSettings.instantViewScrollBySpace {
			let spaceScrollDownKeyboardHandler:()->KeyHandlerResult = { [weak self, weak page] in
				if let window = self?._window {
					if !window.styleMask.contains(.fullScreen) {
						page?.scrollPage(direction: .down)
					}
				}
				
				return .invoked
			}
			_window.set(handler: spaceScrollDownKeyboardHandler, with: self, for: .Space, priority: .low)
			
			let spaceScrollUpKeyboardHandler:()->KeyHandlerResult = { [weak self, weak page] in
				if let window = self?._window {
					if !window.styleMask.contains(.fullScreen) {
						page?.scrollPage(direction: .up)
					}
				}
				
				return .invoked
			}
			
			_window.set(handler: spaceScrollUpKeyboardHandler, with: self, for: .Space, priority: .medium, modifierFlags: [.shift])
		} else {
			_window.set(handler: closeKeyboardHandler, with: self, for: .Space)
		}

        
        if let titleView = titleView {
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidNeedSaveState(_:)), name: NSView.frameDidChangeNotification, object: titleView)
        }
    }
    
    private var titleView: NSView? {
        if let windowView = _window.contentView?.superview {
            return ObjcUtils.findElements(byClass: "NSTitlebarContainerView", in: windowView).first
        }
        return nil
    }

    
    private func openInSafari() {
        if let currentPageUrl = currentPageUrl {
            execute(inapp: .external(link: currentPageUrl, false))
            if navigation.stackCount > 1 {
                navigation.back()
            } else {
                _window.orderOut(nil)
                instantController = nil
            }
        }
    }
    
    private var currentPageUrl:String? {
        let content = (navigation.controller as? InstantPageViewController)?.webPage.content
        if let content = content {
            switch content {
            case .Loaded(let content):
                return content.url
            default:
                break
            }
        }
        return nil
    }
    
    private func share() {
        if let currentPageUrl = currentPageUrl {
            showModal(with: ShareModalController(ShareLinkObject(account, link: currentPageUrl)), for: _window)
        }
    }
    
    override func navigationWillChangeController() {
        genericView.updateTitle(navigation.controller.defaultBarTitle, animated: true)
        _window.title = navigation.controller.defaultBarTitle
        genericView.updateBackVisiblity(navigation.stackCount > 1, animated: true)
        windowDidNeedSaveState(Notification(name: Notification.Name(rawValue: "")))
        (navigation.controller as? InstantPageViewController)?.pageDidScrolled = { [weak self] value in
            self?.genericView.updateBorder(value.position.rect.minY - value.documentSize.height > 0, animated: true)
        }
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        _window.appearance = theme.appearance
        _window.backgroundColor = theme.colors.grayBackground
    }
    
    
    
    @objc func windowDidNeedSaveState(_ notification: Notification) {
        if let windowView = _window.contentView?.superview {
            if let titleView = ObjcUtils.findElements(byClass: "NSTitlebarContainerView", in: windowView).first {
                let frame = NSMakeRect(0, _window.frame.height - barHeight, titleView.frame.width, barHeight)
                if !NSEqualRects(frame, titleView.frame) {
                    titleView.frame = frame
                }
                if let controls = titleView.subviews.first?.subviews {
                    var xs:[CGFloat] = [18, 58, 38]
                    for i in 0 ..< 3 {
                        let view = controls[i]
                        view.setFrameOrigin(xs[i], floorToScreenPixels(scaleFactor: System.backingScale, (barHeight - view.frame.height)/2))
                    }
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        appearanceDisposable.dispose()
        
        if let titleView = titleView {
            NotificationCenter.default.removeObserver(titleView)
        }
    }
    
    private func _show() {
        navigation.viewWillAppear(true)
        genericView.addContentView(navigation.view)
        genericView.updateTitle(navigation.controller.defaultBarTitle, animated: false)
        genericView.updateBorder(false, animated: false)
        genericView.updateBackVisiblity(false, animated: false)
        _window.title = navigation.controller.defaultBarTitle
        navigation.viewDidAppear(true)
        instantController = self
    }
    
    func show() {
        _show()
        self.ready.set(navigation.controller.ready.get() |> take(1) |> filter {$0} |> deliverOnMainQueue |> map { [weak self] value in
            self?._window.makeKeyAndOrderFront(nil)

            return value
        })
    }
}

func showInstantPage(_ page: InstantPageViewController) {
    if let instantController = instantController {
        instantController.navigation.push(page, true)
        instantController._window.orderFront(nil)
        instantController._window.deminiaturize(nil)
    } else {
        instantController = InstantViewController(page: page, account: page.account)
        instantController?.show()
    }
}

