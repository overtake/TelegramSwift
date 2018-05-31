//
//  LocationModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/05/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import MapKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
import MtProtoKitMac


private enum PickLocationState : Equatable {
    case user(CLLocation?)
    case custom(CLLocation?, named: String?)
    var location: CLLocation? {
        switch self {
        case let .user(location):
            return location
        case let .custom(location, _):
            return location
        }
    }
}

private enum LocationViewState : Equatable {
    case normal(PickLocationState)
    case expanded(CLLocation?)
}


private final class LocationPinView : View {
    private let locationPin: ImageView = ImageView()
    private let dotView: View = View(frame: NSMakeRect(0, 0, 4, 4))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(locationPin)
        addSubview(dotView)
        dotView.layer?.cornerRadius = 2
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        locationPin.image = theme.icons.locationMapPin
        locationPin.sizeToFit()
        dotView.backgroundColor = theme.colors.blueIcon
    }
    
    override func layout() {
        super.layout()
        dotView.centerX(y: frame.height - dotView.frame.height)
    }
    
    func updateState(_ state: PickLocationState, animated: Bool) -> Void {
        
        switch state {
        case .user:
            dotView.change(opacity: 0, animated: animated)
            locationPin.change(pos: NSMakePoint(locationPin.frame.minX, frame.height - dotView.frame.height - locationPin.frame.height - 6), animated: animated, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        case let .custom(location, _):
            dotView.change(opacity: 1, animated: animated)
            locationPin.change(pos: NSMakePoint(locationPin.frame.minX, location == nil ? 0 : frame.height - dotView.frame.height - locationPin.frame.height - 6), animated: animated, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class LocationMapView : View {
    fileprivate let mapView: MKMapView = MKMapView()
    private let headerTextView: TextView = TextView()
    private let header: View = View()
    private let expandContainer: Control = Control(frame: NSMakeRect(0, 0, 0, 50))
    private let expandButton: TitleButton = TitleButton()
    private var state: LocationViewState = .normal(.user(nil))
    private var hasExpand: Bool = true
    private let loadingView: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 20, 20))
    fileprivate let dismiss: ImageButton = ImageButton()
    fileprivate let tableView: TableView = TableView(frame: NSZeroRect)
    fileprivate let locateButton: ImageButton = ImageButton()
    
    private let locationPinView = LocationPinView(frame: NSMakeRect(0, 0, 40, 70))
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(mapView)
        
        mapView.mapType = .standard
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.showsUserLocation = true
        mapView.showsZoomControls = true
        mapView.wantsLayer = true
        header.addSubview(headerTextView)
        header.addSubview(dismiss)
        header.addSubview(locateButton)
        addSubview(header)
        addSubview(tableView)
        updateLocalizationAndTheme()
        
        expandButton.isEventLess = true
        expandButton.userInteractionEnabled = false
        
        expandContainer.addSubview(loadingView)
        expandContainer.addSubview(expandButton)
        addSubview(expandContainer)
        locateButton.autohighlight = false
        mapView.addSubview(locationPinView)
    }
    
    fileprivate func getSelectedLocation() -> CLLocation? {
        let windowLocation = locationPinView.convert(NSMakePoint(locationPinView.frame.width / 2, locationPinView.frame.height - 2), to: nil)
        let coordinate = mapView.convert(windowLocation, toCoordinateFrom: nil)
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        
        locationPinView.updateLocalizationAndTheme()
        expandButton.set(font: .medium(.title), for: .Normal)
        expandButton.set(color: theme.colors.blueUI, for: .Normal)
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        _ = locateButton.sizeToFit()
        _ = dismiss.sizeToFit()
        header.backgroundColor = theme.colors.background
        header.border = [.Bottom]
        loadingView.progressColor = theme.colors.blueUI
        expandContainer.border = [.Top]
        expandContainer.backgroundColor = theme.colors.background
        let title = TextViewLayout(.initialize(string: L10n.locationSendTitle, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        title.measure(width: frame.width - 20)
        
        headerTextView.update(title)
        headerTextView.center()
    }
    
    fileprivate func updateExpandState(_ state: LocationViewState, loading: Bool, hasVenues: Bool, animated: Bool, toggleExpand:@escaping(LocationViewState)->Void) {
        loadingView.isHidden = !loading && hasVenues
        expandButton.isHidden = loading || !hasVenues
        hasExpand = (loading || hasVenues)
        self.state = state
        
        let duration: Double = 0.3
        let timingFunction: String = kCAMediaTimingFunctionSpring
        
        CATransaction.begin()
        let mapY: CGFloat
        switch state {
        case let .normal(pickState):
            switch pickState {
            case .custom:
                hasExpand = false
                locateButton.set(image: theme.icons.locationMapLocate, for: .Normal)
            case let .user(location):
                locateButton.set(image: theme.icons.locationMapLocated, for: .Normal)
                locateButton.isHidden = location == nil
            }
            locationPinView.change(opacity: loading ? 0 : 1, animated: animated)
            locationPinView.updateState(pickState, animated: animated)
            expandButton.set(text: L10n.locationSendShowNearby, for: .Normal)
            //NSMakeRect(0, frame.height - 50 - expandContainer.frame.height, frame.width, 50)
            tableView.change(size: NSMakeSize(frame.width, 60), animated: animated, timingFunction: kCAMediaTimingFunctionSpring)
            tableView.change(pos: NSMakePoint(0, frame.height - 60 - (hasExpand ? expandContainer.frame.height : 0)), animated: animated, duration: duration, timingFunction: timingFunction)
            mapY = header.frame.height
            locateButton.userInteractionEnabled = true
        case .expanded:
            locateButton.userInteractionEnabled = false
            locateButton.set(image: theme.icons.locationMapLocate, for: .Normal)
            locationPinView.change(opacity: 0, animated: animated)
            expandButton.set(text: L10n.locationSendHideNearby, for: .Normal)
            let tableHeight = min(tableView.listHeight, frame.height - (hasExpand ? expandContainer.frame.height : 0) - header.frame.height - 50)
            tableView.change(size: NSMakeSize(frame.width, tableHeight), animated: animated, duration: duration, timingFunction: timingFunction)
            tableView.change(pos: NSMakePoint(0, frame.height - (hasExpand ? expandContainer.frame.height : 0) - tableHeight), animated: animated, duration: duration, timingFunction: timingFunction)
            mapY = -(mapView.frame.height / 2) + header.frame.height + 50 / 2
        }
        expandContainer.change(pos: NSMakePoint(0, hasExpand ? frame.height - expandContainer.frame.height : frame.height), animated: animated, duration: duration, timingFunction: timingFunction)
        _ = locateButton.sizeToFit()
        
        
        mapView._change(pos: NSMakePoint(0, mapY), animated: animated, duration: duration, timingFunction: timingFunction)
        //pinPoint.midY - locationPinView.frame.height
        let pinPoint = mapView.focus(NSMakeSize(locationPinView.frame.width, 4))
        locationPinView.change(pos: NSMakePoint(pinPoint.minX, pinPoint.midY - locationPinView.frame.height), animated: animated, duration: 0.2, timingFunction: kCAMediaTimingFunctionLinear)


        CATransaction.commit()
        
        expandContainer.removeAllHandlers()
        if !loading {
            expandContainer.set(handler: { [weak self] _ in
                guard let `self` = self else {return}
                switch state {
                case .normal:
                    toggleExpand(.expanded(self.mapView.userLocation.location))
                case .expanded:
                    toggleExpand(.normal(.user(self.mapView.userLocation.location)))
                }
            }, for: .Click)
        }
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        header.frame = NSMakeRect(0, 0, frame.width, 50)
        headerTextView.center()
        dismiss.centerY(x: 10)
        locateButton.centerY(x: frame.width - 10 - locateButton.frame.width)
        expandContainer.frame = NSMakeRect(0, hasExpand ? frame.height - expandContainer.frame.height : frame.height, frame.width, expandContainer.frame.height)
        let mapY: CGFloat
        let mapHeight: CGFloat = frame.height - 50 - header.frame.height
        switch state {
        case .normal:
            tableView.frame = NSMakeRect(0, frame.height - 60 - (hasExpand ? expandContainer.frame.height : 0), frame.width, 60)
            mapY = header.frame.height
        case .expanded:
            let tableHeight = min(tableView.listHeight, frame.height - (hasExpand ? expandContainer.frame.height : 0) - header.frame.height - 50)
            tableView.frame = NSMakeRect(0, frame.height - (hasExpand ? expandContainer.frame.height : 0) - tableHeight, frame.width, tableHeight)
            mapY = -(mapHeight / 2) + header.frame.height + 50 / 2
        }
        let delegate = mapView.delegate
        mapView.delegate = nil
        mapView.frame = NSMakeRect(0, mapY, frame.width, mapHeight)
        mapView.delegate = delegate
        
        let pinPoint = mapView.focus(NSMakeSize(4, 4))
        locationPinView.centerX(y: pinPoint.midY - locationPinView.frame.height)

        
        expandButton.center()
        loadingView.center()
        
        let zoomControls = HackUtils.findElements(byClass: "MKZoomSegmentedControl", in: mapView).first as? NSView
        if let zoomControls = zoomControls {
            zoomControls.setFrameOrigin(20, 20)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



private final class MapItemsArguments {
    let account: Account
    let sendCurrent:()->Void
    let sendVenue:(TelegramMediaMap)->Void
    let searchVenues:(String)->Void
    init(account: Account, sendCurrent:@escaping()->Void, sendVenue:@escaping(TelegramMediaMap)->Void, searchVenues: @escaping(String)->Void) {
        self.account = account
        self.sendCurrent = sendCurrent
        self.sendVenue = sendVenue
        self.searchVenues = searchVenues
    }
}

private enum MapItemEntryId : Hashable {
    case currentLocation
    case expandNearby
    case nearby(Int32)
    case search
    case searchEmptyId
    var hashValue: Int {
        return 0
    }
}

private enum MapItemEntry : TableItemListNodeEntry {
    case currentLocation(index:Int32, state: LocationSelectCurrentState)
    case expandNearby(index: Int32, expand: Bool, loading: Bool)
    case nearby(index: Int32, result: ChatContextResult)
    case search(index: Int32)
    case searchEmpty(index: Int32, loading: Bool)
    var index: Int32 {
        switch self {
        case let .currentLocation(index, _):
            return index
        case let .expandNearby(index, _, _):
            return index
        case let .nearby(index, _):
            return index
        case let .search(index):
            return index
        case let .searchEmpty(index, _):
            return index
        }
    }
    
    var stableId: MapItemEntryId {
        switch self {
        case .currentLocation:
            return .currentLocation
        case .expandNearby:
            return .expandNearby
        case .search:
            return .search
        case .searchEmpty:
            return .searchEmptyId
        case let .nearby(index, _):
            return .nearby(index)
        }
    }
    
    func item(_ arguments: MapItemsArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .nearby(_, result):
            return LocationPlaceSuggestionRowItem(initialSize, stableId: stableId, account: arguments.account, result: result, action: {
                switch result.message {
                case let .mapLocation(media, _):
                    arguments.sendVenue(media)
                default:
                    break
                }
            })
        case .search:
            return SearchRowItem(initialSize, stableId: stableId, searchInteractions: SearchInteractions({ state in
                arguments.searchVenues(state.request)
            }, { state in
                arguments.searchVenues(state.request)
            }), inset: NSEdgeInsets(left:10,right:10, top: 10, bottom: 10))
        case let .currentLocation(_, state):
            return LocationSendCurrentItem(initialSize, stableId: stableId, state: state, action: {
                arguments.sendCurrent()
            })
        case let .searchEmpty(_, loading):
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: loading)
        default:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
}

private func < (lhs: MapItemEntry, rhs: MapItemEntry) -> Bool {
    return lhs.index < rhs.index
}

private func mapEntries(result: [ChatContextResult], loading: Bool, location: CLLocation?, state: LocationViewState) -> [MapItemEntry] {
    var entries: [MapItemEntry] = []
    

    
    var index: Int32 = 0
    
    let selectState: LocationSelectCurrentState
    switch state {
    case .expanded:
        selectState = .accurate(location: location, expanded: true)
    case let .normal(pickState):
        switch pickState {
        case .user:
            selectState = .accurate(location: location, expanded: false)
        case let .custom(_, name):
            let text: String
            if let name = name {
                text = name.isEmpty ? L10n.locationSendThisLocationUnknown : name
            } else {
                text = L10n.locationSendLocating
            }
            selectState = .selected(location: text)
        }
    }
    
    entries.append(.currentLocation(index: index, state: selectState))
    index += 1
    switch state {
    case .expanded:
        entries.append(.search(index: index))
        index += 1
        if !result.isEmpty {
            for value in result {
                entries.append(.nearby(index: index, result: value))
                index += 1
            }
        } else {
            entries.append(MapItemEntry.searchEmpty(index: index, loading: false))
            index += 1
        }
       
    case .normal:
        break
    }
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<MapItemEntry>], right: [AppearanceWrapperEntry<MapItemEntry>], initialSize:NSSize, arguments:MapItemsArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

private class MapDelegate : NSObject, MKMapViewDelegate {
    
    fileprivate var isPinRaised: Bool = false
    private var animated: Bool = false
    let location:Promise<MKUserLocation?> = Promise()
    fileprivate var willChangeRegion:()->Void = {}
    fileprivate var didChangeRegion:()->Void = {}
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        self.location.set(.single(userLocation))
        
        guard !isPinRaised else {return}
        focusUserLocation(mapView)
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        willChangeRegion()

    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        didChangeRegion()
    }
    
    func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
        if "\(error)".contains("Code=1") {
            self.location.set(.single(nil))
            isPinRaised = true
            didChangeRegion()
            mapView.showsUserLocation = false
        }
    }
    
    
    fileprivate func focusUserLocation(_ mapView: MKMapView) {
        let userLocation = mapView.userLocation
        
        var region = MKCoordinateRegion()
        var span = MKCoordinateSpan()
        span.latitudeDelta = CLLocationDegrees(0.005)
        span.longitudeDelta = CLLocationDegrees(0.005)
        var location = CLLocationCoordinate2D()
        location.latitude = userLocation.coordinate.latitude
        location.longitude = userLocation.coordinate.longitude
        region.span = span
        region.center = location
        mapView.setRegion(region, animated: animated)
        animated = true
    }
}

class LocationModalController: ModalViewController {

    private let chatInteraction: ChatInteraction
    private let delegate: MapDelegate = MapDelegate()
    private let disposable = MetaDisposable()
    private let sendDisposable = MetaDisposable()
    private let statePromise:Promise<LocationViewState> = Promise()
    init(_ chatInteraction: ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init(frame: NSMakeRect(0, 0, 360, 380))
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override open func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(360, size.height - 70), animated: false)
    }
    
    public func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(360, contentSize.height - 70), animated: animated)
        }
    }
    
    override func viewClass() -> AnyClass {
        return LocationMapView.self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        genericView.mapView.showsUserLocation = false
        window?.removeAllHandlers(for: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(mouseHandler: { [weak self] _ -> KeyHandlerResult in
            self?.delegate.isPinRaised = true
            return .rejected
        }, with: self, for: .leftMouseDragged, priority: .modal)
    }
    
    private func sendLocation(_ media: TelegramMediaMap? = nil) {
        sendDisposable.set((statePromise.get() |> deliverOnMainQueue).start(next: { [weak self] state in
            switch state {
            case let .normal(picked):
                if let location = picked.location {
                    self?.chatInteraction.sendLocation(location.coordinate, nil)
                    self?.close()
                }
            case let .expanded(location):
                if let media = media {
                    let coordinate = CLLocationCoordinate2D(latitude: media.latitude, longitude: media.longitude)
                    self?.chatInteraction.sendLocation(coordinate, media.venue)
                    self?.close()
                } else if let location = location {
                    self?.chatInteraction.sendLocation(location.coordinate, nil)
                    self?.close()
                }
            }
        }))
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        sendLocation()
        return .invoked
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.mapView.delegate = delegate
        genericView.dismiss.set(handler: { [weak self] _ in
            self?.close()
        }, for: .Click)
        
        let state: ValuePromise<LocationViewState> = ValuePromise(.normal(.user(genericView.mapView.userLocation.location)), ignoreRepeated: true)
        statePromise.set(state.get())
        
        genericView.locateButton.set(handler: { [weak self] _ in
            guard let `self` = self else {return}
            self.delegate.focusUserLocation(self.genericView.mapView)
            self.delegate.isPinRaised = false
        }, for: .Click)
        
        if let _ = genericView.mapView.userLocation.location {
            delegate.location.set(.single(genericView.mapView.userLocation))
            delegate.focusUserLocation(genericView.mapView)
        }
        
        var handleRegion: Bool = true
        
        delegate.willChangeRegion = { [weak self] in
            guard let `self` = self, handleRegion else {return}
            if self.delegate.isPinRaised {
                state.set(.normal(.custom(nil, named: nil)))
            } else {
                state.set(.normal(.user(self.genericView.mapView.userLocation.location)))
            }
        }
        delegate.didChangeRegion = { [weak self] in
            guard let `self` = self, handleRegion else {return}
            if self.delegate.isPinRaised {
                state.set(.normal(.custom(self.genericView.getSelectedLocation(), named: nil)))
            } else {
                state.set(.normal(.user(self.genericView.mapView.userLocation.location)))
            }
        }
        
        let peerId = chatInteraction.peerId
        let account = self.chatInteraction.account
        
        let search:Promise<String> = Promise("")
        
        var cachedData:[String : ChatContextResultCollection] = [:]
        let previousResult:Atomic<ChatContextResultCollection?> = Atomic(value: nil)
        let peerSignal: Signal<PeerId?, Void> = .single(nil) |> then(resolvePeerByName(account: chatInteraction.account, name: "foursquare") )
        let requestSignal = combineLatest(peerSignal |> deliverOnPrepareQueue, delegate.location.get() |> take(1) |> deliverOnPrepareQueue, search.get() |> distinctUntilChanged |> deliverOnPrepareQueue)
            |> mapToSignal { botId, location, query -> Signal<(ChatContextResultCollection?, CLLocation?, Bool, Bool), NoError> in
                if let botId = botId, let location = location {
                    let first = Signal<(ChatContextResultCollection?, CLLocation?, Bool, Bool), Void>.single((cachedData[query] ?? previousResult.modify {$0}, location.location, cachedData[query] == nil, !query.isEmpty))
                    if cachedData[query] == nil {
                        return first |> then(requestChatContextResults(account: account, botId: botId, peerId: peerId, query: query, offset: "", geopoint: ChatContextGeoPoint(latitude: location.coordinate.latitude, longtitude: location.coordinate.longitude))
                            |> deliverOnPrepareQueue |> map { result in
                                var value = result
                                if let result = result {
                                    cachedData[query] = result
                                }
                                value = previousResult.modify {_ in result}
                                
                                return (value, location.location, false, !query.isEmpty)
                            })
                    } else {
                        return first
                    }
                    
                } else {
                    return .single((nil, location?.location, botId == nil, false))
                }
        }
        
        let signal: Signal<(ChatContextResultCollection?, CLLocation?, Bool, Bool), NoError> = .single((nil, nil, true, false)) |> then(requestSignal)
        
        let previous: Atomic<[AppearanceWrapperEntry<MapItemEntry>]> = Atomic(value: [])
        
        let initialSize = self.atomicSize
        let arguments = MapItemsArguments(account: chatInteraction.account, sendCurrent: { [weak self] in
            self?.sendLocation()
        }, sendVenue: { [weak self] venue in
            self?.sendLocation(venue)
        }, searchVenues: { query in
            prepareQueue.async {
                if cachedData[query] != nil {
                    search.set(.single(query))
                } else {
                    search.set(.single(query) |> delay(0.2, queue: prepareQueue))
                }
            }
        })
        
        let stateModified = state.get() |> mapToSignal { state -> Signal<LocationViewState, Void> in
            switch state {
            case let .normal(pick):
                switch pick {
                case let .custom(location, _):
                    if let location = location {
                        return .single(state) |> then(googleVenueForLatitude(location.coordinate.latitude, longtitude: location.coordinate.longitude) |> map { value in
                            return .normal(.custom(location, named: value))
                        })
                    }
                default:
                    break
                }
            default:
                break
            }
            return .single(state)
        } |> distinctUntilChanged
        
        let transition:Signal<(TableUpdateTransition, Bool, LocationViewState, Bool), Void> = combineLatest(signal |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, stateModified |> deliverOnPrepareQueue) |> map { data, appearance, state in
            let results:[ChatContextResult] = data.0?.results ?? []
            let entries = mapEntries(result: results, loading: data.2, location: data.1, state: state).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return (prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), data.2, state, !results.isEmpty || data.3)
        } |> deliverOnMainQueue
        
        let animated:Atomic<Bool> = Atomic(value: false)
        
        disposable.set(transition.start(next: { [weak self] transition, loading, expanded, hasVenues in
            guard let `self` = self else {return}
            self.genericView.tableView.merge(with: transition)
            switch expanded {
            case .expanded:
                handleRegion = false
            default:
                handleRegion = true
            }
            self.genericView.updateExpandState(expanded, loading: loading, hasVenues: hasVenues, animated: animated.swap(true), toggleExpand: { [weak self] viewState in
                self?.genericView.tableView.clipView.scroll(to: NSMakePoint(0, 0), animated: false)
                search.set(.single(""))
                state.set(viewState)
            })
            self.readyOnce()
        }))
        
        
        
    }
    
    deinit {
        disposable.dispose()
        sendDisposable.dispose()
    }
    
    private var genericView: LocationMapView {
        return view as! LocationMapView
    }
}


private func googleVenueForLatitude(_ latitude: Double, longtitude: Double) -> Signal<String?, Void> {
    return Signal { subscriber in
        let string = "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(latitude),\(longtitude)&sensor=true&language=\(appAppearance.language.languageCode)"
        let request = MTHttpRequestOperation.data(forHttpUrl: URL(string: string))
        let disposable = request?.start(next: { value in
            if let data = value as? Data {
                let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? Dictionary<String, Any>
                 if let results = json?["results"] as? Array<Any> {
                    if let first = results.first as? Dictionary<String, Any> {
                        if let components = first["address_components"] as? [Any] {
                            for component in components {
                                if let component = component as? [String : Any] {
                                    let types = component["types"] as? [String]
                                    let longName = component["long_name"] as? String
                                    if let types = types, types.contains("route") {
                                        subscriber.putNext(longName)
                                        subscriber.putCompletion()
                                        return
                                    }
                                }
                            }
                        }
                    }
                }
                
            }
            subscriber.putNext("")
            subscriber.putCompletion()
        }, error: { error in
            subscriber.putNext("")
            subscriber.putCompletion()
        }, completed: {
            subscriber.putCompletion()
        })
        return ActionDisposable {
            disposable?.dispose()
        }
    }
}
