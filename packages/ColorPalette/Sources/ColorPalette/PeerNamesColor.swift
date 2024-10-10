//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 01.02.2024.
//

import Foundation
import Cocoa

public class PeerNameColors: Equatable {
    public enum Subject {
        case background
        case palette
        case stories
    }
    
    public struct Colors: Equatable {
        public let main: NSColor
        public let secondary: NSColor?
        public let tertiary: NSColor?
        
        public init(main: NSColor, secondary: NSColor?, tertiary: NSColor?) {
            self.main = main
            self.secondary = secondary
            self.tertiary = tertiary
        }
        
        public init(main: NSColor) {
            self.main = main
            self.secondary = nil
            self.tertiary = nil
        }
        
        public init?(colors: [NSColor]) {
            guard let first = colors.first else {
                return nil
            }
            self.main = first
            if colors.count == 3 {
                self.secondary = colors[1]
                self.tertiary = colors[2]
            } else if colors.count == 2, let second = colors.last {
                self.secondary = second
                self.tertiary = nil
            } else {
                self.secondary = nil
                self.tertiary = nil
            }
        }
    }
    
    public static var defaultSingleColors: [Int32: Colors] {
        return [
            0: Colors(main: NSColor(rgb: 0xcc5049)),
            1: Colors(main: NSColor(rgb: 0xd67722)),
            2: Colors(main: NSColor(rgb: 0x955cdb)),
            3: Colors(main: NSColor(rgb: 0x40a920)),
            4: Colors(main: NSColor(rgb: 0x309eba)),
            5: Colors(main: NSColor(rgb: 0x368ad1)),
            6: Colors(main: NSColor(rgb: 0xc7508b))
        ]
    }
    
    public static var defaultValue: PeerNameColors {
        return PeerNameColors(
            colors: defaultSingleColors,
            darkColors: [:],
            displayOrder: [5, 3, 1, 0, 2, 4, 6],
            profileColors: [:],
            profileDarkColors: [:],
            profilePaletteColors: [:],
            profilePaletteDarkColors: [:],
            profileStoryColors: [:],
            profileStoryDarkColors: [:],
            profileDisplayOrder: [],
            nameColorsChannelMinRequiredBoostLevel: [:],
            nameColorsGroupMinRequiredBoostLevel: [:]
        )
    }
    
    public let colors: [Int32: Colors]
    public let darkColors: [Int32: Colors]
    public let displayOrder: [Int32]
    
    public let profileColors: [Int32: Colors]
    public let profileDarkColors: [Int32: Colors]
    public let profilePaletteColors: [Int32: Colors]
    public let profilePaletteDarkColors: [Int32: Colors]
    public let profileStoryColors: [Int32: Colors]
    public let profileStoryDarkColors: [Int32: Colors]
    public let profileDisplayOrder: [Int32]
    
    public let nameColorsChannelMinRequiredBoostLevel: [Int32: Int32]
    public let nameColorsGroupMinRequiredBoostLevel: [Int32: Int32]
    
    
    public init(
        colors: [Int32: Colors],
        darkColors: [Int32: Colors],
        displayOrder: [Int32],
        profileColors: [Int32: Colors],
        profileDarkColors: [Int32: Colors],
        profilePaletteColors: [Int32: Colors],
        profilePaletteDarkColors: [Int32: Colors],
        profileStoryColors: [Int32: Colors],
        profileStoryDarkColors: [Int32: Colors],
        profileDisplayOrder: [Int32],
        nameColorsChannelMinRequiredBoostLevel: [Int32: Int32],
        nameColorsGroupMinRequiredBoostLevel: [Int32: Int32]
    ) {
        self.colors = colors
        self.darkColors = darkColors
        self.displayOrder = displayOrder
        self.profileColors = profileColors
        self.profileDarkColors = profileDarkColors
        self.profilePaletteColors = profilePaletteColors
        self.profilePaletteDarkColors = profilePaletteDarkColors
        self.profileStoryColors = profileStoryColors
        self.profileStoryDarkColors = profileStoryDarkColors
        self.profileDisplayOrder = profileDisplayOrder
        self.nameColorsChannelMinRequiredBoostLevel = nameColorsChannelMinRequiredBoostLevel
        self.nameColorsGroupMinRequiredBoostLevel = nameColorsGroupMinRequiredBoostLevel
    }
    
    
    public static func == (lhs: PeerNameColors, rhs: PeerNameColors) -> Bool {
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.darkColors != rhs.darkColors {
            return false
        }
        if lhs.displayOrder != rhs.displayOrder {
            return false
        }
        if lhs.profileColors != rhs.profileColors {
            return false
        }
        if lhs.profileDarkColors != rhs.profileDarkColors {
            return false
        }
        if lhs.profilePaletteColors != rhs.profilePaletteColors {
            return false
        }
        if lhs.profilePaletteDarkColors != rhs.profilePaletteDarkColors {
            return false
        }
        if lhs.profileStoryColors != rhs.profileStoryColors {
            return false
        }
        if lhs.profileStoryDarkColors != rhs.profileStoryDarkColors {
            return false
        }
        if lhs.profileDisplayOrder != rhs.profileDisplayOrder {
            return false
        }
        return true
    }
}
