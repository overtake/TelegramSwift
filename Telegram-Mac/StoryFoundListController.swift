//
//  StoryFoundListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import MapKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let presentaiton: TelegramPresentationTheme
    let openStory:(StoryInitialIndex?)->Void
    init(context: AccountContext, presentaiton: TelegramPresentationTheme, openStory:@escaping(StoryInitialIndex?)->Void) {
        self.context = context
        self.presentaiton = presentaiton
        self.openStory = openStory
    }
}


private final class AnnotationView : MKAnnotationView {
    private let locationPin = ImageView()
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
        
        self.wantsLayer = true
        
        layer?.masksToBounds = false
        
        
        
        locationPin.image = darkAppearance.icons.locationMapPin
        locationPin.sizeToFit()

        
        frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        wantsLayer = true
                        
        
        addSubview(locationPin)

        
        update()
    }
    override var annotation: MKAnnotation? {
        didSet {
            update()
        }
    }
    
    override func layout() {
        super.layout()
        locationPin.center()
        locationPin.setFrameOrigin(NSMakePoint(locationPin.frame.minX, locationPin.frame.minY - locationPin.frame.height / 2))
    }
    
    private func update() {
        
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    static var reuseIdentifier: String {
        return "peer"
    }
    
}

private class MapRowItem: GeneralRowItem {
    let context: AccountContext
    fileprivate let location: State.Location
    fileprivate let presentation: TelegramPresentationTheme
    fileprivate let userLocation: CLLocation?
    fileprivate let geocodedPlacemark: ReverseGeocodedPlacemark?
    fileprivate let userLocationError: UserLocationError?
    init(_ initialSize: NSSize, height: CGFloat, stableId: AnyHashable, context: AccountContext, location: State.Location, userLocation: CLLocation?, geocodedPlacemark: ReverseGeocodedPlacemark?, userLocationError: UserLocationError?, presentation: TelegramPresentationTheme, viewType: GeneralViewType, action: @escaping()->Void) {
        self.context = context
        self.location = location
        self.userLocation = userLocation
        self.presentation = presentation
        self.geocodedPlacemark = geocodedPlacemark
        self.userLocationError = userLocationError
        super.init(initialSize, height: height + 60, stableId: stableId, viewType: viewType, action: action, inset: NSEdgeInsets())
    }
    
    deinit {
       
    }
    
    override func viewClass() -> AnyClass {
        return MapRowItemView.self
    }
    
}

private final class MapRowItemView : GeneralContainableRowView, MKMapViewDelegate {
    
    final class VenueView : View {
        private let imageView = ImageView()
        private let titleView = TextView()
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            
            addSubview(titleView)
            addSubview(textView)
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            
        }
        
        override func layout() {
            super.layout()
            imageView.centerY(x: 10)
            titleView.setFrameOrigin(NSMakePoint(imageView.frame.maxX + 10, 12))
            textView.setFrameOrigin(NSMakePoint(imageView.frame.maxX + 10, frame.height - textView.frame.height - 12))
        }
        
        func update(item: MapRowItem, animated: Bool) {
            
            self.backgroundColor = item.presentation.colors.background
            imageView.image = item.presentation.icons.locationPin
            imageView.sizeToFit()
            
            let name = TextViewLayout(.initialize(string: item.geocodedPlacemark?.city ?? strings().locationPreviewLocation, color: item.presentation.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
            
            
            var distance: String = ""
            if let address = item.geocodedPlacemark?.street {
                distance += address
                distance += " \(strings().bullet) "
            }
            if let userLocation = item.userLocation {
                let loc1 = CLLocation(latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude)
                let loc2 = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
                let dis = loc1.distance(from: loc2)
                distance += strings().locationPreviewDistanceAway(stringForDistance(distance: dis))
            } else {
                distance += "\(item.location.coordinate.latitude), \(item.location.coordinate.longitude)"
            }
            
            let info = TextViewLayout(.initialize(string: distance, color: item.presentation.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
            
            
            name.measure(width: frame.width - imageView.frame.width - 30)
            info.measure(width: frame.width - imageView.frame.width - 30)
            
            self.titleView.update(name)
            self.textView.update(info)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    
    private let mapView: MKMapView = MKMapView()
    
    
    private let venueView: VenueView = .init(frame: .zero)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(mapView)
        mapView.register(AnnotationView.self, forAnnotationViewWithReuseIdentifier: AnnotationView.reuseIdentifier)
        mapView.delegate = self
        
        mapView.showsZoomControls = true
        mapView.showsUserLocation = true
        
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        
        mapView.showsBuildings = false
        
        addSubview(venueView)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        mapView.delegate = nil
    }
    
    override func layout() {
        super.layout()
        mapView.frame = CGRect(origin: .zero, size: NSMakeSize(containerView.frame.width, containerView.frame.height - 60))
        venueView.frame = NSMakeRect(0, mapView.frame.maxY, mapView.frame.width, 60)
    }

    
    func focusVenue() {
        guard let item = item as? MapRowItem else {
            return
        }
        let userLocation = item.location.coordinate
        var region = MKCoordinateRegion()
        var span = MKCoordinateSpan()
        span.latitudeDelta = CLLocationDegrees(0.005)
        span.longitudeDelta = CLLocationDegrees(0.005)
        var location = CLLocationCoordinate2D()
        location.latitude = userLocation.latitude
        location.longitude = userLocation.longitude
        region.span = span
        region.center = location
        mapView.setRegion(region, animated: false)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case is State.Location:
            return mapView.dequeueReusableAnnotationView(withIdentifier: AnnotationView.reuseIdentifier, for: annotation)
        default:
            return nil
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
    }
    
    func mapViewDidStopLocatingUser(_ mapView: MKMapView) {
        
    }
    
        
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
    }

    private var location: NSPoint? = nil
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        location = nil
       
    }
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        location = event.locationInWindow
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        let previousItem = self.item
        super.set(item: item, animated: animated)
        
        layout()
        
        guard let item = item as? MapRowItem else {
            return
        }

        mapView.appearance = item.presentation.appearance
        
        venueView.update(item: item, animated: animated)
        
    
        mapView.addAnnotation(item.location)

        focusVenue()

    }
}



private struct State : Equatable {
    class Location : NSObject, MKAnnotation {
        var coordinate: CLLocationCoordinate2D
        var venue: MapVenue?
        init(coordinate: CLLocationCoordinate2D, venue: MapVenue?) {
            self.coordinate = coordinate
            self.venue = venue
        }
    }
    
    var location: Location?
    var userLocation: CLLocation?
    var geocodedPlacemark: ReverseGeocodedPlacemark?
    var userLocationError: UserLocationError?
    
    var listState: StoryListContext.State?
}

private let _id_map_map = InputDataIdentifier("_id_map_map")
private let _id_separator = InputDataIdentifier("_id_separator")
private let _id_search_empty = InputDataIdentifier("_id_search_empty")

private func _id_block(_ item: StoryListContextState.Item) -> InputDataIdentifier {
    return .init("_id_\(item.storyItem.id)_\(String(describing: item.peer?.id.toInt64()))")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
  
    if let location = state.location {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_map_map, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return MapRowItem(initialSize, height: 200, stableId: stableId, context: arguments.context, location: location, userLocation: state.userLocation, geocodedPlacemark: state.geocodedPlacemark, userLocationError: state.userLocationError, presentation: arguments.presentaiton, viewType: .legacy, action: { })
        }))
    }
    
    if let listState = state.listState {
        if state.location != nil {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_separator, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return SeparatorRowItem(initialSize, stableId, string: strings().storiesFoundListFromLocationCountable(listState.totalCount), customTheme: .initialize(arguments.presentaiton))
            }))
        }
        
        if listState.totalCount == 0 {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_search_empty, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return SearchEmptyRowItem(initialSize, stableId: stableId, height: 160, isLoading: listState.isLoading, text: strings().storiesFoundListNotFound, customTheme: .initialize(arguments.presentaiton))
            }))
        } else {
            let items = listState.items
            let chunks = items.chunks(3)
            for chunk in chunks {
                let item = chunk[0]
                
                let peerReference = PeerReference(arguments.context.myPeer!)!
                
                let viewType: GeneralViewType = .modern(position: .inner, insets: NSEdgeInsetsMake(0, 0, 0, 0))
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_block(item), equatable: .init(chunk), comparable: nil, item: { initialSize, stableId in
                    return StoryMonthRowItem(initialSize, stableId: stableId, context: arguments.context, standalone: false, peerId: arguments.context.peerId, peerReference: peerReference, items: chunk, selected: nil, pinnedIds: Set(), rowCount: 3, viewType: viewType, openStory: arguments.openStory, toggleSelected: { _ in }, menuItems: { _ in return [] }, presentation: arguments.presentaiton)
                }))
            }
        }
        
    }
    
    
    
    return entries
}

private extension SearchStoryListContext.Source {
    var title: String {
        switch self {
        case .hashtag(let string):
            return string
        case .mediaArea:
            return strings().storyLocationTitle
        }
    }
    
    var coordinates: CLLocationCoordinate2D? {
        switch self {
        case .hashtag:
            return nil
        case let .mediaArea(area):
            switch area {
            case .venue(_, let venue):
                return .init(latitude: venue.latitude, longitude: venue.longitude)
            default:
                return nil
            }
        }
    }
}

func StoryFoundListController(context: AccountContext, source: SearchStoryListContext.Source, presentation: TelegramPresentationTheme, existingsContext: SearchStoryListContext? = nil) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(location: source.coordinates.map { .init(coordinate: $0, venue: nil) })
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil
    
    
    actionsDisposable.add(requestUserLocation().start(next: { location in
        switch location {
        case let .success(location):
            updateState { current in
                var current = current
                current.userLocation = location
                return current
            }
        }
    }, error: { error in
        updateState { current in
            var current = current
            current.userLocationError = error
            return current
        }
    }))
    
    if let location = initialState.location {
        actionsDisposable.add(reverseGeocodeLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude).start(next: { mark in
            updateState { current in
                var current = current
                current.geocodedPlacemark = mark
                return current
            }
        }))
    }
    
    let contextObject = existingsContext ?? SearchStoryListContext(account: context.account, source: source)


    let arguments = Arguments(context: context, presentaiton: presentation, openStory: { [weak contextObject] initialId in
        if let contextObject {
            StoryModalController.ShowListStory(context: context, listContext: contextObject, peerId: context.peerId, initialId: initialId)
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: source.title)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    
    controller.contextObject = contextObject
   
    
    contextObject.loadMore()
    
    actionsDisposable.add(contextObject.state.start(next: { state in
        updateState { current in
            var current = current
            current.listState = state
            return current
        }
    }))
    
    controller.getBackgroundColor = {
        presentation.colors.background
    }

    
    let modalController = InputDataModalController(controller, modalInteractions: nil, size: NSMakeSize(350, 300), presentation: presentation)
    
   
    
    modalController.getModalTheme = {
        .init(text: presentation.colors.text, grayText: presentation.colors.grayText, background: presentation.colors.background, border: .clear, activeBorder: presentation.colors.border)
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    
    controller.centerModalHeader = ModalHeaderData(title: source.title, subtitle: "")
    
    
    switch source {
    case let .mediaArea(area):
        switch area {
        case let .venue(_, venue):
            
            let shareImage = NSImage(resource: .iconStoryShare).precomposed(presentation.colors.accent)
            
            controller.rightModalHeader = ModalHeaderData(image: shareImage, handler: {
                verifyAlert(for: context.window, information: strings().locationPreviewOpenInMaps, ok: strings().inAppLinksConfirmOpenExternalOK, successHandler: { _ in
                    execute(inapp: .external(link: "https://maps.google.com/maps?q=\(String(format:"%f", venue.latitude)),\(String(format:"%f", venue.longitude))", false))
                }, presentation: presentation)
            })
        default:
            break
        }
        
    default:
        break
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    controller.didLoad = { [weak contextObject] controller, _ in
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                contextObject?.loadMore()
            default:
                break
            }
        }
    }
    
    controller.afterTransaction = { [weak modalController] controller in
        controller.centerModalHeader = ModalHeaderData(title: source.title, subtitle: strings().storySearchSubtitleCountable(stateValue.with { $0.listState?.totalCount ?? 0 }))
        modalController?.updateLocalizationAndTheme(theme: presentation)
    }
    
    return modalController
}



