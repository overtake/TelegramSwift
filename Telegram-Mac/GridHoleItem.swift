//
//  GridHoleItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 26/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
final class GridHoleItem: GridItem {
    func update(node: GridItemNode) {
        
    }

    let section: GridSection? = nil
    
    func node(layout: GridNodeLayout, gridNode:GridNode) -> GridItemNode {
        return GridHoleItemNode(gridNode)
    }
}

class GridHoleItemNode: GridItemNode {
//    private let activityIndicatorView: UIActivityIndicatorView
//    
//    override init() {
//        self.activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .gray)
//        
//        super.init()
//        
//        self.view.addSubview(self.activityIndicatorView)
//        self.activityIndicatorView.startAnimating()
//    }
//    
//    override func layout() {
//        super.layout()
//        
//        let size = self.bounds.size
//        let activityIndicatorSize = self.activityIndicatorView.bounds.size
//        self.activityIndicatorView.frame = CGRect(origin: CGPoint(x: floor((size.width - activityIndicatorSize.width) / 2.0), y: floor((size.height - activityIndicatorSize.height) / 2.0)), size: activityIndicatorSize)
//    }
}
