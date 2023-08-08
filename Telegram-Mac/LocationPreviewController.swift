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

private final class Arguments {
    let context:AccountContext
    let presentation: TelegramPresentationTheme
    init(context: AccountContext, presentation: TelegramPresentationTheme) {
        self.context = context
        self.presentation = presentation
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
        return lhs.map == rhs.map
    }
    
    var map: MediaArea.Venue
    var peer: Peer?
    init(map: MediaArea.Venue, peer: Peer?) {
        self.map = map
        self.peer = peer
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

private final class AnnotationView : MKAnnotationView {
    fileprivate let control = OverlayControl()
    private let locationPin = ImageView()
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
        
        locationPin.image = storyTheme.icons.locationMapPin
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
@available(macOS 10.13, *)
private class MapRowItem: GeneralRowItem {
    let context: AccountContext
    let presentation: TelegramPresentationTheme
    fileprivate let pin: MapPin
    init(_ initialSize: NSSize, height: CGFloat, stableId: AnyHashable, context: AccountContext, latitude: Double, longitude: Double, viewType: GeneralViewType, presentation: TelegramPresentationTheme) {
        self.context = context
        self.presentation = presentation
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
        if #available(macOS 11.0, *) {
            mapView.showsPitchControl = true
        }
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
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case is MapPin:
            return mapView.dequeueReusableAnnotationView(withIdentifier: AnnotationView.reuseIdentifier, for: annotation)
        default:
            return nil
        }
    }
    
    private var doNotUpdateRegion: Bool = false
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if location != nil {
            doNotUpdateRegion = true
        }
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
    init(_ initialSize: NSSize, presentation: TelegramPresentationTheme) {
        self.presentation = presentation
        super.init(initialSize)
    }
    
    override var height: CGFloat {
        return 50
    }
    override var stableId: AnyHashable {
        return 2
    }
    
    override func viewClass() -> AnyClass {
        return MapDataRowItemView.self
    }
}

private final class MapDataRowItemView: TableRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? MapDataRowItem else {
            return super.backdorColor
        }
        return item.presentation.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
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
        return MapRowItem(initialSize, height: 400, stableId: stableId, context: arguments.context, latitude: state.map.latitude, longitude: state.map.longitude, viewType: .legacy, presentation: arguments.presentation)
    }))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_map_data, equatable: InputDataEquatable(state.map), comparable: nil, item: { initialSize, stableId in
        return MapDataRowItem(initialSize, presentation: arguments.presentation)
    }))
    index += 1
    
    return entries
}
@available(macOS 10.13, *)
func LocationModalPreview(_ context: AccountContext, venue: MediaArea.Venue, peer: Peer?, presentation: TelegramPresentationTheme) -> InputDataModalController {
    
    let initialState = State(map: venue, peer: peer)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var focusSelf:(()->Void)? = nil
    
    let arguments = Arguments(context: context, presentation: presentation)
    
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().locationPreviewTitle)
    

    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: strings().locationPreviewOpenInMaps, accept: {
        close?()
        execute(inapp: .external(link: "https://maps.google.com/maps?q=\(String(format:"%f", stateValue.with { $0.map.latitude })),\(String(format:"%f", stateValue.with { $0.map.longitude }))", false))
    }, height: 50, singleButton: true, customTheme: {
        .init(presentation: presentation)
    })
    
    
    controller.leftModalHeader = ModalHeaderData(image: presentation.icons.modalClose, handler: {
        close?()
    })
    
    controller.rightModalHeader = ModalHeaderData(image: presentation.icons.locationMapLocated, handler: {
        focusSelf?()
    })
    
    controller.updateDatas = { data in
        
        return .none
    }
    
    focusSelf = { [weak controller] in
        let view = controller?.tableView.firstItem?.view as? MapRowItemView
        view?.focusSelf()
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
