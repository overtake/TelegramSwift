//
//  SlotMachineValue.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 15/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa

struct SlotMachineValue : Equatable {
    enum ReelValue : Int32 {
        case rolling
        case bar
        case berries
        case lemon
        case seven
        case sevenWin
    }
    
    let left: ReelValue
    let center: ReelValue
    let right: ReelValue
    
    init(rawValue: Int32?) {
        if let rawValue = rawValue, rawValue > 0 {
            let rawValue = rawValue - 1
            
            let leftRawValue = rawValue & 3
            let centerRawValue = rawValue >> 2 & 3
            let rightRawValue = rawValue >> 4
            
            func reelValue(for rawValue: Int32) -> ReelValue {
                switch rawValue {
                case 0:
                    return .bar
                case 1:
                    return .berries
                case 2:
                    return .lemon
                case 3:
                    return .seven
                default:
                    return .rolling
                }
            }
            var leftReelValue = reelValue(for: leftRawValue)
            var centerReelValue = reelValue(for: centerRawValue)
            var rightReelValue = reelValue(for: rightRawValue)
            
            
            if leftReelValue == .seven && centerReelValue == .seven && rightReelValue == .seven {
                leftReelValue = .sevenWin
                centerReelValue = .sevenWin
                rightReelValue = .sevenWin
            }
            
            self.left = leftReelValue
            self.center = centerReelValue
            self.right = rightReelValue
        } else {
            self.left = .rolling
            self.center = .rolling
            self.right = .rolling
        }
    }
    
    var is777: Bool {
        return self.left == .sevenWin && self.center == .sevenWin && self.right == .sevenWin
    }
    var jackpot: Bool {
        switch self.left {
        case .sevenWin:
            return center == .sevenWin && right == .sevenWin
        case .berries:
            return center == .berries && right == .berries
        case .lemon:
            return center == .lemon && right == .lemon
        case .bar:
            return center == .bar && right == .bar
        default:
            return false
        }
    }
    
    var packIndex: [Int] {
        
        let leftIndex: Int
        let centerIndex: Int
        let rightIndex: Int
        
        if (left == .bar) {
            leftIndex = 5
        } else if (left == .berries) {
            leftIndex = 6
        } else if (left == .lemon) {
            leftIndex = 7
        } else if (left == .seven) {
            leftIndex = 4
        } else if (left == .sevenWin) {
            leftIndex = 3
        } else {
            leftIndex = 8
        }
        
        if (center == .bar) {
            centerIndex = 11
        } else if (center == .berries) {
            centerIndex = 12
        } else if (center == .lemon) {
            centerIndex = 13
        } else if (center == .seven) {
            centerIndex = 10
        }  else if (center == .sevenWin) {
            centerIndex = 9
        } else {
            centerIndex = 14
        }
        
        if (right == .bar) {
            rightIndex = 17
        } else if (right == .berries) {
            rightIndex = 18
        } else if (right == .lemon) {
            rightIndex = 19
        } else if (right == .seven) {
            rightIndex = 16
        } else if (right == .sevenWin) {
            rightIndex = 15
        } else {
            rightIndex = 20
        }
        
        return [leftIndex, centerIndex, rightIndex]
    }
}


let slotsEmoji: String = "🎰"
