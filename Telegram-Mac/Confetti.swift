//
//  Confetti.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import CoreGraphics
import QuartzCore


private enum Colors {
    static var red: NSColor {
        return theme.colors.redUI
    }
    static var blue: NSColor {
        return theme.colors.accent
    }
    static var green: NSColor {
        return theme.colors.greenUI
    }
    static var yellow: NSColor {
        return theme.colors.peerAvatarOrangeTop
    }
}

private enum Images {
    static let box = NSImage(named: "Confetti_Box")!
    static let triangle = NSImage(named: "Confetti_Triangle")!
    static let circle = NSImage(named: "Confetti_Circle")!
    static let swirl = NSImage(named: "Confetti_Spiral")!
}

private let colors:[NSColor] = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow
]

private let images:[NSImage] = [
    Images.box,
    Images.triangle,
    Images.circle,
    Images.swirl
]

private let velocities:[Int] = [
    150,
    135,
    200,
    250
]

private func getRandomVelocity() -> Int {
    return velocities[getRandomNumber()] * 2
}

private func getRandomNumber() -> Int {
    return Int(arc4random_uniform(4))
}

private func getNextColor(i:Int) -> CGColor {
    if i <= 4 {
        return colors[0].cgColor
    } else if i <= 8 {
        return colors[1].cgColor
    } else if i <= 12 {
        return colors[2].cgColor
    } else {
        return colors[3].cgColor
    }
}

private func getNextImage(i:Int) -> NSImage {
    return images[i % 4]
}


func PlayConfetti(for window: Window, playEffect: Bool = false) {
    let contentView = window.contentView!
    
    
    let rightBottomView = View(frame: contentView.bounds)
    rightBottomView.isEventLess = true
    let rightEmitter = CAEmitterLayer()
    rightEmitter.emitterPosition = CGPoint(x: contentView.frame.size.width , y: contentView.frame.size.height)
    rightEmitter.emitterShape = .point
    rightEmitter.emitterSize = CGSize(width: contentView.frame.size.width, height: 2.0)
    rightEmitter.emitterCells = generateEmitterCells(left: false)
    
    rightBottomView.layer = rightEmitter
    contentView.addSubview(rightBottomView)
    
    let leftBottomView = View(frame: contentView.bounds)
    leftBottomView.isEventLess = true
    let leftEmitter = CAEmitterLayer()
    leftEmitter.emitterPosition = CGPoint(x: 0, y: contentView.frame.size.height)
    leftEmitter.emitterShape = .point
    leftEmitter.emitterSize = CGSize(width: contentView.frame.size.width, height: 2.0)
    leftEmitter.emitterCells = generateEmitterCells(left: true)
    
    leftBottomView.layer = leftEmitter
    contentView.addSubview(leftBottomView)
    
    
    delay(0.1, closure: {
        rightEmitter.birthRate = 0
        leftEmitter.birthRate = 0
    })
    
    delay(2.0, closure: {
        rightBottomView.removeFromSuperview()
        leftBottomView.removeFromSuperview()
    })
}
private func generateEmitterCells(left: Bool) -> [CAEmitterCell] {
    var cells:[CAEmitterCell] = [CAEmitterCell]()
    for index in 0 ..< 16 {
        let cell = CAEmitterCell()
        cell.birthRate = 20
        cell.lifetime = 2.0
        cell.lifetimeRange = 0
        cell.velocity = CGFloat(getRandomVelocity()) * 1.5
        cell.velocityRange = -CGFloat(arc4random() % 300)
        
        cell.alphaSpeed = -1.0/4.0
        cell.alphaRange = cell.lifetime * cell.alphaSpeed
        
     //   cell.emissionRange = CGFloat.pi / 8
      //  cell.emissionLongitude = CGFloat.pi * 2
        
        cell.emissionLongitude = left ? -60 * (.pi / 180) : CGFloat(-Double.pi + 1.0)
        cell.emissionRange = 30 * (.pi / 180)
        cell.yAcceleration = max(400, CGFloat(arc4random() % 1000))
        cell.spin = max(3.5, CGFloat(arc4random() % 14))
        cell.spinRange = 10
        cell.color = getNextColor(i: index)
        cell.contents = getNextImage(i: index).cgImage(forProposedRect: nil, context: nil, hints: nil)
        cell.scaleRange = 0.25
        cell.scale = 0.1
        cells.append(cell)
    }
    return cells
}
