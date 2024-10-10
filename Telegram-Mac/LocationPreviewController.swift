//
//  LocationPreviewController.swift
//  Telegram
//
//  Created by Mike Renoir on 01.08.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import TGUIKit
import SwiftSignalKit
import MapKit


private var sharedShortDistanceFormatter: MKDistanceFormatter?
func shortStringForDistance(distance: Int32) -> String {
    let distanceFormatter: MKDistanceFormatter
    if let currentDistanceFormatter = sharedShortDistanceFormatter {
        distanceFormatter = currentDistanceFormatter
    } else {
        distanceFormatter = MKDistanceFormatter()
        distanceFormatter.unitStyle = .abbreviated
        sharedShortDistanceFormatter = distanceFormatter
    }
    
    let locale = appAppearance.locale
    if distanceFormatter.locale != locale {
        distanceFormatter.locale = locale
    }
    
    let distance = max(1, distance)
    var result = distanceFormatter.string(fromDistance: Double(distance))
    if result.hasPrefix("0 ") {
        result = result.replacingOccurrences(of: "0 ", with: "1 ")
    }
    return result
}


private final class Arguments {
    let context:AccountContext
    let presentation: TelegramPresentationTheme
    let focusVenue:()->Void
    let updateUserLocation:(CLLocation)->Void
    init(context: AccountContext, presentation: TelegramPresentationTheme, focusVenue:@escaping()->Void, updateUserLocation:@escaping(CLLocation)->Void) {
        self.context = context
        self.presentation = presentation
        self.focusVenue = focusVenue
        self.updateUserLocation = updateUserLocation
    }
}


private struct State : Equatable {
    static func == (lhs: State, rhs: State) -> Bool {
        if let lhsPeer = lhs.peer, let rhsPeer = rhs.peer {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else if (lhs.peer != nil) != (rhs.peer != nil) {
            return false
        }
        if lhs.userLocation != rhs.userLocation {
            return false
        }
        return lhs.map == rhs.map
    }
    
    var map: MediaArea.Venue
    var peer: Peer?
    var userLocation: CLLocation?
    init(map: MediaArea.Venue, peer: Peer?, userLocation: CLLocation?) {
        self.map = map
        self.peer = peer
        self.userLocation = userLocation
    }
}



private final class MapPin : NSObject, MKAnnotation
{
    let coordinate: CLLocationCoordinate2D
    let account: Account
    
    var focusRegion: (()->Void)?
    
    init (coordinate: CLLocationCoordinate2D, account: Account)
    {
        self.coordinate = coordinate
        self.account = account
    }
}

private final class MapPinView: View {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        background = .random
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AnnotationView : MKAnnotationView {
    fileprivate let control = OverlayControl()
    private let locationPin = ImageView()
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
        
        self.wantsLayer = true
        
        layer?.masksToBounds = false
        
        
        
        locationPin.image = darkAppearance.icons.locationMapPin
        locationPin.sizeToFit()

        
        frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        wantsLayer = true
                
        control.frame = bounds
        
        
        addSubview(locationPin)
        addSubview(control)
        
        control.set(handler: { [weak self] _ in
            (self?.annotation as? MapPin)?.focusRegion?()
        }, for: .Click)
        
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
        if let annotation = self.annotation as? MapPin {
           
        }
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
    let presentation: TelegramPresentationTheme
    let updateUserLocation: (CLLocation)->Void
    fileprivate let pin: MapPin
    init(_ initialSize: NSSize, height: CGFloat, stableId: AnyHashable, context: AccountContext, latitude: Double, longitude: Double, viewType: GeneralViewType, presentation: TelegramPresentationTheme, updateUserLocation: @escaping(CLLocation)->Void) {
        self.context = context
        self.presentation = presentation
        self.updateUserLocation = updateUserLocation
        self.pin = MapPin(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), account: context.account)
        super.init(initialSize, height: height, stableId: stableId, viewType: viewType)
    }
    
    deinit {
       
    }
    
    override func viewClass() -> AnyClass {
        return MapRowItemView.self
    }
    
}

@available(macOS 10.13, *)
private final class MapRowItemView : TableRowView, MKMapViewDelegate {
    private let mapView: MKMapView = MKMapView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(mapView)
        mapView.register(AnnotationView.self, forAnnotationViewWithReuseIdentifier: AnnotationView.reuseIdentifier)
        mapView.delegate = self
        
        
        mapView.showsZoomControls = true
        mapView.showsUserLocation = true
        
        mapView.showsBuildings = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        mapView.delegate = nil
    }
    
    override func layout() {
        super.layout()
        mapView.frame = bounds
    }
    
    func focusSelf() {
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
        mapView.setRegion(region, animated: true)
    }
    
    func focusVenue() {
        guard let item = item as? MapRowItem else {
            return
        }
        let userLocation = item.pin.coordinate
        var region = MKCoordinateRegion()
        var span = MKCoordinateSpan()
        span.latitudeDelta = CLLocationDegrees(0.005)
        span.longitudeDelta = CLLocationDegrees(0.005)
        var location = CLLocationCoordinate2D()
        location.latitude = userLocation.latitude
        location.longitude = userLocation.longitude
        region.span = span
        region.center = location
        mapView.setRegion(region, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case is MapPin:
            return mapView.dequeueReusableAnnotationView(withIdentifier: AnnotationView.reuseIdentifier, for: annotation)
        default:
            return nil
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let item = item as? MapRowItem, let location = userLocation.location else {
            return
        }
        item.updateUserLocation(location)
    }
    
    func mapViewDidStopLocatingUser(_ mapView: MKMapView) {
        guard let item = item as? MapRowItem, let location = mapView.userLocation.location else {
            return
        }
        item.updateUserLocation(location)
    }
    
    
    private var doNotUpdateRegion: Bool = false
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if location != nil {
            doNotUpdateRegion = true
        }
        guard let item = item as? MapRowItem, let location = mapView.userLocation.location else {
            return
        }
        item.updateUserLocation(location)
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
        
        
        guard let item = item as? MapRowItem else {
            return
        }
        if let location = mapView.userLocation.location {
            item.updateUserLocation(location)
        }
        
        mapView.appearance = item.presentation.appearance
        
        let focus:(Bool)->Void = { [weak self, unowned item] animated in
            let center = item.pin.coordinate
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            self?.mapView.setRegion(region, animated: animated)
            self?.doNotUpdateRegion = false
        }
        
        if !doNotUpdateRegion {
            focus(animated)
        }
        
        if let previousItem = previousItem as? MapRowItem {
            mapView.removeAnnotation(previousItem.pin)
        }
        item.pin.focusRegion = {
            focus(true)
        }
        
        mapView.addAnnotation(item.pin)
    }
}


private class MapDataRowItem : TableRowItem {
    fileprivate let presentation: TelegramPresentationTheme
    fileprivate let location: MediaArea.Venue
    fileprivate let callback:()->Void
    fileprivate let userLocation: CLLocation?
    init(_ initialSize: NSSize, location: MediaArea.Venue, userLocation: CLLocation?, presentation: TelegramPresentationTheme, callback:@escaping()->Void) {
        self.location = location
        self.callback = callback
        self.presentation = presentation
        self.userLocation = userLocation
        super.init(initialSize)
    }
    
    override var height: CGFloat {
        return 60
    }
    override var stableId: AnyHashable {
        return 2
    }
    
    override func viewClass() -> AnyClass {
        return MapDataRowItemView.self
    }
}

private final class MapDataRowItemView: TableRowView {
    private let control = Control()
    private let titleView = TextView()
    private let distance = TextView()
    private let imageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        distance.userInteractionEnabled = false
        distance.isSelectable = false
        border = [.Top]
        addSubview(control)
        control.set(handler: { [weak self] _ in
            if let item = self?.item as? MapDataRowItem {
                item.callback()
            }
        }, for: .Click)
        
        control.addSubview(titleView)
        control.addSubview(distance)
        control.addSubview(imageView)
        
        control.set(handler: { control in
            control.layer?.opacity = 0.8
        }, for: .Highlight)
        
        control.set(handler: { control in
            control.layer?.opacity = 1.0
        }, for: .Normal)
        
        control.set(handler: { control in
            control.layer?.opacity = 1.0
        }, for: .Normal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var borderColor: NSColor {
        guard let item = item as? MapDataRowItem else {
            return .clear
        }
        return item.presentation.colors.border
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? MapDataRowItem else {
            return .clear
        }
        return item.presentation.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? MapDataRowItem else {
            return
        }
        
        imageView.image = item.presentation.icons.locationPin
        imageView.sizeToFit()
        
        let string = item.location.venue?.title ?? strings().locationPreviewLocation
        let layout = TextViewLayout(.initialize(string: string, color: item.presentation.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        layout.measure(width: frame.width - 70)
        titleView.update(layout)
        
        var distance: String = ""
        if let address = item.location.venue?.address {
            distance += address
            distance += " \(strings().bullet) "
        }
        if let userLocation = item.userLocation {
            let loc1 = CLLocation(latitude: item.location.latitude, longitude: item.location.longitude)
            let loc2 = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
            let dis = loc1.distance(from: loc2)
            distance += strings().locationPreviewDistanceAway(stringForDistance(distance: dis))
        } else {
            distance += "\(item.location.latitude), \(item.location.longitude)"
        }
        
        
        let distanceLayout = TextViewLayout(.initialize(string: distance, color: item.presentation.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        distanceLayout.measure(width: frame.width - 70)
        self.distance.update(distanceLayout)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        control.frame = bounds
        imageView.centerY(x: 10)
        
        titleView.resize(frame.width - 70)
        distance.resize(frame.width - 70)

        if distance.textLayout?.attributedString.string.isEmpty == true {
            titleView.centerY(x: imageView.frame.maxX + 10)
        } else {
            titleView.setFrameOrigin(NSMakePoint(imageView.frame.maxX + 10, 11))
            distance.setFrameOrigin(NSMakePoint(imageView.frame.maxX + 10, control.frame.height - 11 - distance.frame.height))
        }

    }
}


private let _id_map = InputDataIdentifier("_id_map")
private let _id_map_data = InputDataIdentifier("_id_map_data")

@available(macOS 10.13, *)
private func entries(_ state:State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_map, equatable: InputDataEquatable(state.map), comparable: nil, item: { initialSize, stableId in
        return MapRowItem(initialSize, height: 400, stableId: stableId, context: arguments.context, latitude: state.map.latitude, longitude: state.map.longitude, viewType: .legacy, presentation: arguments.presentation, updateUserLocation: arguments.updateUserLocation)
    }))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_map_data, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
        return MapDataRowItem(initialSize, location: state.map, userLocation: state.userLocation, presentation: arguments.presentation, callback: arguments.focusVenue)
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    return entries
}
@available(macOS 10.13, *)
func LocationModalPreview(_ context: AccountContext, venue: MediaArea.Venue, peer: Peer?, presentation: TelegramPresentationTheme) -> InputDataModalController {
    
    let initialState = State(map: venue, peer: peer, userLocation: nil)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var focusSelf:(()->Void)? = nil
    var focusVenue:(()->Void)? = nil
    
    let arguments = Arguments(context: context, presentation: presentation, focusVenue: {
        focusVenue?()
    }, updateUserLocation: { location in
        updateState { current in
            var current = current
            current.userLocation = location
            return current
        }
    })
    
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().locationPreviewTitle)
    

    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: strings().locationPreviewOpenInMaps, accept: {
        close?()
        execute(inapp: .external(link: "https://maps.google.com/maps?q=\(String(format:"%f", stateValue.with { $0.map.latitude })),\(String(format:"%f", stateValue.with { $0.map.longitude }))", false))
    }, singleButton: true, customTheme: {
        .init(presentation: presentation)
    })
    
    
    controller.leftModalHeader = ModalHeaderData(image: presentation.icons.modalClose, handler: {
        close?()
    })
    
    controller.rightModalHeader = ModalHeaderData(image: presentation.icons.locationMapLocated, handler: {
        focusSelf?()
    })
    
    controller.getBackgroundColor = {
        presentation.colors.background
    }
    
    controller.updateDatas = { data in
        
        return .none
    }
    
    
    
    focusSelf = { [weak controller] in
        let view = controller?.tableView.firstItem?.view as? MapRowItemView
        view?.focusSelf()
    }
    focusVenue = { [weak controller] in
        let view = controller?.tableView.firstItem?.view as? MapRowItemView
        view?.focusVenue()
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in f() }, size: NSMakeSize(380, 400))
    
    modalController.getModalTheme = {
        .init(presentation: presentation)
    }
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}
