////
////  PasteboardUtils.swift
////  TelegramMac
////
////  Created by keepcoder on 30/01/2017.
////  Copyright © 2017 Telegram. All rights reserved.
////
//
//import Cocoa
//
//
//extension NSDragOperation {
//    
//    var involves_deletion:Bool {
//        // TODO: Might need to revisit this, since if we drop *outside* our app
//        // ".generic" probably should be copy, not cut or delete
//        return self == .generic || self == .move || self == .delete
//    }
//    
//}
//
//extension NSDragOperation {
//    
//    static var all_values: [(op:NSDragOperation,str:String)]{
//        return [ (.copy,".copy"),(.link,"link"),(.generic,".generic"), (.`private`,".private"),(.move,".move"),(.delete,".delete") ]
//    }
//    
//}
//
//extension NSDragOperation: CustomStringConvertible {
//    
//    public var description:String {
//        
//        var arr = [String]()
//        
//        for pair in NSDragOperation.all_values where self.contains(pair.op){
//            arr.append(pair.str)
//        }
//        
//        return "[" + arr.joined(separator: ",") + "]"
//        
//    }
//    
//}
//
//enum DraggingIconSource {
//    case uti, screenshot
//}
//
//extension NSDraggingSource where Self: NSView {
//    
//    @discardableResult
//    func begin_dragging_session(
//        with event: NSEvent,
//        icon_source: DraggingIconSource,
//        data_sources: [PasteboardWriting]
//        ) -> NSDraggingSession {
//        
//        var dr_items = [NSDraggingItem]()
//        let icon_src = data_sources.count >= 2 ? .uti : icon_source
//        
//        data_sources.forEach {
//            
//            let pb_item = PasteboardItem( data_source: $0, for: NSPasteboard.dragging )
//            let dr_item: NSDraggingItem
//            
//            switch icon_src {
//            case .uti:
//                let pt = self.convert( event.locationInWindow, from: event.window?.contentView )
//                let uti = $0.writable_utis.first ?? kUTTypeFileURL
//                dr_item = NSDraggingItem( writer: pb_item, origin: pt, icon_uti: uti.description )
//            case .screenshot:
//                dr_item = NSDraggingItem( writer: pb_item, icon_image: self.screenshot() )
//            }
//            
//            dr_items.append( dr_item )
//            
//        }
//        
//        return self.beginDraggingSession( with: dr_items, event: event, source: self )
//        
//    }
//    
//}
//
//extension NSView {
//    
//    func register_droppable( utis_for classes: [PasteboardReading.Type] ){
//        
//        let utis = NSPasteboard.dragging.readable_utis( by: classes )
//        
//        self.register( forDraggedTypes: utis )
//        
//    }
//    
//    func is_drag_source( of_drop info:NSDraggingInfo ) -> Bool {
//        
//        if let source = info.draggingSource() as? NSView {
//            return source === self
//        }
//        
//        return false
//        
//    }
//    
//}
//
//extension NSDraggingSession {
//    
//    func configure_promises( in parent:URL ) -> [String] {
//        
//        var filenames = [String]()
//        
//        self.draggingPasteboard.pasteboardItems?.forEach{
//            
//            guard
//                let pb_item = $0 as? PasteboardItem,
//                let name = pb_item.filename_for_promise( in: parent )
//                else { return }
//            
//            pb_item.pending_promise = URL( filename: name, parent: parent )
//            filenames.append( name )
//            
//        }
//        
//        return filenames
//        
//    }
//    
//    func fulfill_dragging_promises(){
//        
//        self.draggingPasteboard.pasteboardItems?.forEach{
//            
//            ($0 as? PasteboardItem)?.fulfill_promise()
//            
//        }
//        
//    }
//    
//}
//
//extension NSPasteboard {
//    
//    func copy( _ objects: [PasteboardWriting], replace_existing:Bool=true ){
//        
//        if replace_existing { self.clearContents() }
//        
//        let items = objects.map{
//            // precondition( type(of:$0) != PasteboardItem, "Error: This item is *already* a PasteboardItem!" )
//            return PasteboardItem( data_source: $0, for: self )
//        }
//        self.writeObjects( items )
//        
//    }
//    
//    // return self.canReadObject( forClasses: classes, options: [:] )
//    
//    func can_paste( _ classes: [PasteboardReading.Type] ) -> Bool {
//        
//        let readable_utis = self.readable_utis( by: classes )
//        
//        return self.canReadItem( withDataConformingToTypes: readable_utis )
//        
//    }
//    
//    func paste( _ classes:[PasteboardReading.Type] ) -> [Any]? {
//        
//        if !self.can_paste( classes ) { return nil }
//        
//        return self.instances( of: classes )
//        
//    }
//    
//}
//
//
//extension NSPasteboard {
//    
//    func readable_utis( by classes: [PasteboardReading.Type] ) -> [String] {
//        
//        var utis = [String]()
//        
//        classes.forEach{
//            utis += $0.readable_utis( for: self )
//        }
//        
//        return utis.unique
//        
//    }
//    
//    
//}
//
//extension NSPasteboardItem {
//    
//    func reference( class_type:PasteboardReading.Type ) -> Any? {
//        
//        guard
//            let rclass = class_type as? ReferenceReading.Type,
//            let instance = rclass.reference( from: self )
//            else { return nil }
//        
//        return instance
//        
//    }
//    
//    func instance( class_type:PasteboardReading.Type ) -> Any? {
//        
//        guard let
//            iclass = class_type as? ItemReading.Type
//            else { return nil }
//        
//        
//        for case let uti as String in class_type.readable_utis {
//            
//            guard
//                let data:Any = self.get_value( for: uti ),
//                let instance = iclass.init( value: data, uti: uti )
//                else { continue }
//            
//            return instance
//            
//        }
//        
//        return nil
//        
//    }
//    
//}
//
//
//extension NSPasteboard {
//    
//    func instances( of classes:[PasteboardReading.Type], promise_requester:NSDraggingInfo?=nil ) -> [Any] {
//        
//        var arr = [Any]()
//        arr += arr.isEmpty ? self.instances_from_items( of: classes ) : []
//        arr += arr.isEmpty ? self.instances_from_promises( of: classes, using:promise_requester ) : []
//        arr += arr.isEmpty ? self.instances_from_urls( of: classes ) : []
//        return arr
//        
//    }
//    
//    private func instances_from_items( of classes:[PasteboardReading.Type] ) -> [Any] {
//        
//        var instances = [Any]()
//        
//        self.pasteboardItems?.forEach {
//            
//            for class_type in classes {
//                
//                guard let instance = $0.reference( class_type: class_type ) ?? $0.instance( class_type: class_type )
//                    else { continue }
//                
//                instances.append( instance )
//                break
//                
//            }
//            
//        }
//        
//        return instances
//        
//    }
//    
//    private func instances_from_promises( of classes:[PasteboardReading.Type], using requester:NSDraggingInfo? ) -> [Any] {
//        
//        guard
//            let requester = requester,
//            let class_type = self.appropriate_promise_capable_class( of: classes )
//            else { return [] }
//        
//        let temp_dir = URL( fileURLWithPath: NSTemporaryDirectory() ) // TODO: Use more specific Temp folder
//        
//        var instances = [Any]()
//        
//        // Request the promised URLs from the dragboard
//        for url in requester.get_promised_urls( parent: temp_dir ) {
//            
//            guard let instance = class_type.init( from: url ) else { continue }
//            
//            instances.append( instance )
//            
//        }
//        
//        return instances
//        
//    }
//    
//    private func instances_from_urls( of classes:[PasteboardReading.Type] ) -> [Any] {
//        
//        let url_capable_classes = get_classes( classes, conforming_to: URLReading.Type.self )
//        
//        var instances = [Any]()
//        
//        for url in self.read_urls( file_urls_only: true, allowed_utis: [] ) {
//            
//            for url_capable_class in url_capable_classes {
//                
//                guard let instance = url_capable_class.init( from: url ) else { continue }
//                
//                instances.append( instance )
//                break
//                
//            }
//            
//        }
//        
//        return instances
//        
//    }
//    
//}
//
//extension NSPasteboard {
//    
//    fileprivate func appropriate_promise_capable_class( of classes:[PasteboardReading.Type] ) -> PromiseReading.Type? {
//        
//        let promise_capable_classes = get_classes( classes, conforming_to: PromiseReading.Type.self )
//        
//        // Check the UTI of the files on the dragboard
//        
//        guard let promises_uti = self.promises_uti
//            else { return nil }
//        
//        // find the best Class (we'll send all the URLs to this one Class)
//        
//        for each_class in promise_capable_classes {
//            
//            let as_pboard_class = each_class as PasteboardReading.Type
//            
//            if let _ /*uti*/ = Cat.first_match( of: promises_uti, in: as_pboard_class.readable_utis as! [String] ) {
//                return each_class
//            }
//            
//        }
//        
//        return nil
//        
//    }
//    
//}
//
//extension PasteboardWriting {
//    
//    public func writable_utis( for pasteboard: NSPasteboard ) -> [String] {
//        
//        return self.writable_utis( [.add_proto,.add_dyn,.dedupe] )
//        
//    }
//    
//    func writable_utis( _ options:UTIsOptions ) -> [String] {
//        
//        let is_uw = (self as? URLWriting) != nil
//        let is_pw = (self as? PromiseWriting) != nil
//        return tailor_utis( self.writable_utis, to: options, supports_urls: is_uw, supports_promise: is_pw )
//        
//    }
//    
//    func resolve( writable_uti:String ) -> String? {
//        return Cat.first_match( of: writable_uti, in: self.writable_utis as! [String] )
//    }
//    
//}
//
//extension PasteboardReading {
//    
//    public static func readable_utis( for pasteboard: NSPasteboard ) -> [String] {
//        
//        return self.readable_utis( [.add_proto,.add_dyn,.dedupe] )
//        
//    }
//    
//    static func readable_utis( _ options:UTIsOptions ) -> [String] {
//        
//        let is_ur = (self as? URLReading.Type) != nil
//        let is_pr = (self as? PromiseReading.Type) != nil
//        return tailor_utis( self.readable_utis, to: options, supports_urls: is_ur, supports_promise: is_pr )
//        
//    }
//    
//    static func resolve( readable_uti:String ) -> String? {
//        return Cat.first_match( of: readable_uti, in: self.readable_utis as! [String] )
//    }
//    
//}
