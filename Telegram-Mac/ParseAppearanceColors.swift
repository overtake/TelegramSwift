//
//  ParseAppearanceColors.swift
//  Telegram
//
//  Created by keepcoder on 01/12/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


private let colors: [UInt32: String] = [
    0x8e0000: "Berry",
    0xdec196: "Brandy",
    0x800b47: "Cherry",
    0xff7f50: "Coral",
    0xdb5079: "Cranberry",
    0xdc143c: "Crimson",
    0xe0b0ff: "Mauve",
    0xffc0cb: "Pink",
    0xff0000: "Red",
    0xff007f: "Rose",
    0x80461b: "Russet",
    0xff2400: "Scarlet",
    0xf1f1f1: "Seashell",
    0xff3399: "Strawberry",
    0xffbf00: "Amber",
    0xeb9373: "Apricot",
    0xfbe7b2: "Banana",
    0xa1c50a: "Citrus",
    0xb06500: "Ginger",
    0xffd700: "Gold",
    0xfde910: "Lemon",
    0xffa500: "Orange",
    0xffe5b4: "Peach",
    0xff6b53: "Persimmon",
    0xe4d422: "Sunflower",
    0xf28500: "Tangerine",
    0xffc87c: "Topaz",
    0xffff00: "Yellow",
    0x384910: "Clover",
    0x83aa5d: "Cucumber",
    0x50c878: "Emerald",
    0xb5b35c: "Olive",
    0x00ff00: "Green",
    0x00a86b: "Jade",
    0x29ab87: "Jungle",
    0xbfff00: "Lime",
    0x0bda51: "Malachite",
    0x98ff98: "Mint",
    0xaddfad: "Moss",
    0x315ba1: "Azure",
    0x0000ff: "Blue",
    0x0047ab: "Cobalt",
    0x4f69c6: "Indigo",
    0x017987: "Lagoon",
    0x71d9e2: "Aquamarine",
    0x120a8f: "Ultramarine",
    0x000080: "Navy",
    0x2f519e: "Sapphire",
    0x76d7ea: "Sky",
    0x008080: "Teal",
    0x40e0d0: "Turquoise",
    0x9966cc: "Amethyst",
    0x4d0135: "Blackberry",
    0x614051: "Eggplant",
    0xc8a2c8: "Lilac",
    0xb57edc: "Lavender",
    0xccccff: "Periwinkle",
    0x843179: "Plum",
    0x660099: "Purple",
    0xd8bfd8: "Thistle",
    0xda70d6: "Orchid",
    0x240a40: "Violet",
    0x3f2109: "Bronze",
    0x370202: "Chocolate",
    0x7b3f00: "Cinnamon",
    0x301f1e: "Cocoa",
    0x706555: "Coffee",
    0x796989: "Rum",
    0x4e0606: "Mahogany",
    0x782d19: "Mocha",
    0xc2b280: "Sand",
    0x882d17: "Sienna",
    0x780109: "Maple",
    0xf0e68c: "Khaki",
    0xb87333: "Copper",
    0xb94e48: "Chestnut",
    0xeed9c4: "Almond",
    0xfffdd0: "Cream",
    0xb9f2ff: "Diamond",
    0xa98307: "Honey",
    0xfffff0: "Ivory",
    0xeae0c8: "Pearl",
    0xeff2f3: "Porcelain",
    0xd1bea8: "Vanilla",
    0xffffff: "White",
    0x808080: "Gray",
    0x000000: "Black",
    0xe8f1d4: "Chrome",
    0x36454f: "Charcoal",
    0x0c0b1d: "Ebony",
    0xc0c0c0: "Silver",
    0xf5f5f5: "Smoke",
    0x262335: "Steel",
    0x4fa83d: "Apple",
    0x80b3c4: "Glacier",
    0xfebaad: "Melon",
    0xc54b8c: "Mulberry",
    0xa9c6c2: "Opal",
    0x54a5f8: "Blue"
]

private let adjectives = [
    "Ancient",
    "Antique",
    "Autumn",
    "Baby",
    "Barely",
    "Baroque",
    "Blazing",
    "Blushing",
    "Bohemian",
    "Bubbly",
    "Burning",
    "Buttered",
    "Classic",
    "Clear",
    "Cool",
    "Cosmic",
    "Cotton",
    "Cozy",
    "Crystal",
    "Dark",
    "Daring",
    "Darling",
    "Dawn",
    "Dazzling",
    "Deep",
    "Deepest",
    "Delicate",
    "Delightful",
    "Divine",
    "Double",
    "Downtown",
    "Dreamy",
    "Dusky",
    "Dusty",
    "Electric",
    "Enchanted",
    "Endless",
    "Evening",
    "Fantastic",
    "Flirty",
    "Forever",
    "Frigid",
    "Frosty",
    "Frozen",
    "Gentle",
    "Heavenly",
    "Hyper",
    "Icy",
    "Infinite",
    "Innocent",
    "Instant",
    "Luscious",
    "Lunar",
    "Lustrous",
    "Magic",
    "Majestic",
    "Mambo",
    "Midnight",
    "Millenium",
    "Morning",
    "Mystic",
    "Natural",
    "Neon",
    "Night",
    "Opaque",
    "Paradise",
    "Perfect",
    "Perky",
    "Polished",
    "Powerful",
    "Rich",
    "Royal",
    "Sheer",
    "Simply",
    "Sizzling",
    "Solar",
    "Sparkling",
    "Splendid",
    "Spicy",
    "Spring",
    "Stellar",
    "Sugared",
    "Summer",
    "Sunny",
    "Super",
    "Sweet",
    "Tender",
    "Tenacious",
    "Tidal",
    "Toasted",
    "Totally",
    "Tranquil",
    "Tropical",
    "True",
    "Twilight",
    "Twinkling",
    "Ultimate",
    "Ultra",
    "Velvety",
    "Vibrant",
    "Vintage",
    "Virtual",
    "Warm",
    "Warmest",
    "Whipped",
    "Wild",
    "Winsome"
]

private let subjectives = [
    "Ambrosia",
    "Attack",
    "Avalanche",
    "Blast",
    "Bliss",
    "Blossom",
    "Blush",
    "Burst",
    "Butter",
    "Candy",
    "Carnival",
    "Charm",
    "Chiffon",
    "Cloud",
    "Comet",
    "Delight",
    "Dream",
    "Dust",
    "Fantasy",
    "Flame",
    "Flash",
    "Fire",
    "Freeze",
    "Frost",
    "Glade",
    "Glaze",
    "Gleam",
    "Glimmer",
    "Glitter",
    "Glow",
    "Grande",
    "Haze",
    "Highlight",
    "Ice",
    "Illusion",
    "Intrigue",
    "Jewel",
    "Jubilee",
    "Kiss",
    "Lights",
    "Lollypop",
    "Love",
    "Luster",
    "Madness",
    "Matte",
    "Mirage",
    "Mist",
    "Moon",
    "Muse",
    "Myth",
    "Nectar",
    "Nova",
    "Parfait",
    "Passion",
    "Pop",
    "Rain",
    "Reflection",
    "Rhapsody",
    "Romance",
    "Satin",
    "Sensation",
    "Silk",
    "Shine",
    "Shadow",
    "Shimmer",
    "Sky",
    "Spice",
    "Star",
    "Sugar",
    "Sunrise",
    "Sunset",
    "Sun",
    "Twist",
    "Unbound",
    "Velvet",
    "Vibrant",
    "Waters",
    "Wine",
    "Wink",
    "Wonder",
    "Zone"
]

private extension NSColor {
    var colorComponents: (r: Int32, g: Int32, b: Int32) {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        self.getRed(&r, green: &g, blue: &b, alpha: nil)
        return (Int32(max(0.0, r) * 255.0), Int32(max(0.0, g) * 255.0), Int32(max(0.0, b) * 255.0))
    }
    
    func distance(to other: NSColor) -> Int32 {
        let e1 = self.colorComponents
        let e2 = other.colorComponents
        let rMean = (e1.r + e2.r) / 2
        let r = e1.r - e2.r
        let g = e1.g - e2.g
        let b = e1.b - e2.b
        return ((512 + rMean) * r * r) >> 8 + 4 * g * g + ((767 - rMean) * b * b) >> 8
    }
}


private func generateThemeName(_ accentColor: NSColor) -> String {
    var nearest: (color: UInt32, distance: Int32)?
    for (color, _) in colors {
        let distance = accentColor.distance(to: NSColor(rgb: color))
        if let currentNearest  = nearest {
            if distance < currentNearest.distance {
                nearest = (color, distance)
            }
        } else {
            nearest = (color, distance)
        }
    }
    
    if let color = nearest?.color, let colorName = colors[color]?.capitalized {
        return "\(adjectives[Int(arc4random()) % adjectives.count].capitalized) \(colorName)"
    } else {
        return ""
    }
}


func importPalette(_ path: String) -> ColorPalette? {
    if let fs = fs(path), fs <= 30 * 1014 * 1024, let data = try? String(contentsOf: URL(fileURLWithPath: path)) {
        let lines = data.components(separatedBy: "\n").filter({!$0.isEmpty})
        
        var isDark: Bool = false
        var tinted: Bool = false
        var paletteName: String? = nil
        var copyright: String = "Telegram"
        var wallpaper: PaletteWallpaper?
        var parent: TelegramBuiltinTheme = .dayClassic
        var accentList:[PaletteAccentColor] = []
        var colors:[String: NSColor] = [:]
        
        /*
         else if name == "accentList" {
         accentList = value.components(separatedBy: ",").compactMap { NSColor(hexString: $0) }
         }
 */
        
        for line in lines {
            if !line.trimmed.hasPrefix("//") {
                var components = line.components(separatedBy: "=")
                if components.count > 2 {
                    components[1] = components[1..<components.count].joined(separator: "=")
                    components = Array(components[0..<2])
                }
                if components.count == 2 {
                    let name = components[0].trimmed
                    let value = components[1].trimmed
                    
                    if name == "name" {
                        paletteName = value
                    } else if name == "isDark" {
                        isDark = Int32(value) == 1
                    } else if name == "tinted" {
                        tinted = Int32(value) == 1
                    } else if name == "copyright" {
                        copyright = value
                    } else if name == "wallpaper" {
                        wallpaper = PaletteWallpaper(value)
                    } else if name == "parent" {
                        parent = TelegramBuiltinTheme(rawValue: value) ?? .dayClassic
                    } else {
                        let components = value.components(separatedBy: ":")
                        var hex:UInt32?
                        var alpha: Float = 1.0
                        
                        if components.count == 1 {
                            hex = UInt32(String(components[0].trimmed.suffix(6)), radix: 16)
                        } else if components.count == 2, let alphaValue = Float(components[1].trimmed) {
                            hex = UInt32(String(components[0].trimmed.suffix(6)), radix: 16)
                            alpha = max(0, min(1, alphaValue))
                        }
                        if let hex = hex {
                            colors[name] = NSColor(hex, CGFloat(alpha))
                        }
                    }
                }
            }
        }
        
        if let name = paletteName {
            return ColorPalette(isNative: false, isDark: isDark,
                                tinted: tinted,
                                name: name,
                                parent: parent,
                                wallpaper: wallpaper ?? parent.palette.wallpaper,
                                copyright: copyright,
                                accentList: accentList,
                                basicAccent: colors["basicAccent"] ?? parent.palette.basicAccent,
                                background: colors["background"] ?? parent.palette.background,
                                text: colors["text"] ?? parent.palette.text,
                                grayText: colors["grayText"] ?? parent.palette.grayText,
                                link: colors["link"] ?? parent.palette.link,
                                accent: colors["accent"] ?? parent.palette.accent,
                                redUI: colors["redUI"] ?? parent.palette.redUI,
                                greenUI: colors["greenUI"] ?? parent.palette.greenUI,
                                blackTransparent: colors["blackTransparent"] ?? parent.palette.blackTransparent,
                                grayTransparent: colors["grayTransparent"] ?? parent.palette.grayTransparent,
                                grayUI: colors["grayUI"] ?? parent.palette.grayUI,
                                darkGrayText: colors["darkGrayText"] ?? parent.palette.darkGrayText,
                                accentSelect: colors["accentSelect"] ?? parent.palette.accentSelect,
                                selectText: colors["selectText"] ?? parent.palette.selectText,
                                border: colors["border"] ?? parent.palette.border,
                                grayBackground: colors["grayBackground"] ?? parent.palette.grayBackground,
                                grayForeground: colors["grayForeground"] ?? parent.palette.grayForeground,
                                grayIcon: colors["grayIcon"] ?? parent.palette.grayIcon,
                                accentIcon: colors["accentIcon"] ?? colors["blueIcon"] ?? parent.palette.accentIcon,
                                badgeMuted: colors["badgeMuted"] ?? parent.palette.badgeMuted,
                                badge: colors["badge"] ?? parent.palette.badge,
                                indicatorColor: colors["indicatorColor"] ?? parent.palette.indicatorColor,
                                selectMessage: colors["selectMessage"] ?? parent.palette.selectMessage,
                                monospacedPre: colors["monospacedPre"] ?? parent.palette.monospacedPre,
                                monospacedCode: colors["monospacedCode"] ?? parent.palette.monospacedCode,
                                monospacedPreBubble_incoming: colors["monospacedPreBubble_incoming"] ?? parent.palette.monospacedPreBubble_incoming,
                                monospacedPreBubble_outgoing: colors["monospacedPreBubble_outgoing"] ?? parent.palette.monospacedPreBubble_outgoing,
                                monospacedCodeBubble_incoming: colors["monospacedCodeBubble_incoming"] ?? parent.palette.monospacedCodeBubble_incoming,
                                monospacedCodeBubble_outgoing: colors["monospacedCodeBubble_outgoing"] ?? parent.palette.monospacedCodeBubble_outgoing,
                                selectTextBubble_incoming: colors["selectTextBubble_incoming"] ?? parent.palette.selectTextBubble_incoming,
                                selectTextBubble_outgoing: colors["selectTextBubble_outgoing"] ?? parent.palette.selectTextBubble_outgoing,
                                bubbleBackground_incoming: colors["bubbleBackgroundTop_incoming"] ?? parent.palette.bubbleBackground_incoming,
                                bubbleBackgroundTop_outgoing: colors["bubbleBackgroundBottom_outgoing"] ?? parent.palette.bubbleBackgroundTop_outgoing,
                                bubbleBackgroundBottom_outgoing: colors["bubbleBackgroundBottom_outgoing"] ?? parent.palette.bubbleBackgroundTop_outgoing,
                                bubbleBorder_incoming: colors["bubbleBorder_incoming"] ?? parent.palette.bubbleBorder_incoming,
                                bubbleBorder_outgoing: colors["bubbleBorder_outgoing"] ?? parent.palette.bubbleBorder_outgoing,
                                grayTextBubble_incoming: colors["grayTextBubble_incoming"] ?? parent.palette.grayTextBubble_incoming,
                                grayTextBubble_outgoing: colors["grayTextBubble_outgoing"] ?? parent.palette.grayTextBubble_outgoing,
                                grayIconBubble_incoming: colors["grayIconBubble_incoming"] ?? parent.palette.grayIconBubble_incoming,
                                grayIconBubble_outgoing: colors["grayIconBubble_outgoing"] ?? parent.palette.grayIconBubble_outgoing,
                                accentIconBubble_incoming: colors["accentIconBubble_incoming"] ?? colors["blueIconBubble_incoming"] ?? parent.palette.accentIconBubble_incoming,
                                accentIconBubble_outgoing: colors["accentIconBubble_outgoing"] ?? colors["blueIconBubble_outgoing"] ?? parent.palette.accentIconBubble_outgoing,
                                linkBubble_incoming: colors["linkBubble_incoming"] ?? parent.palette.linkBubble_incoming,
                                linkBubble_outgoing: colors["linkBubble_outgoing"] ?? parent.palette.linkBubble_outgoing,
                                textBubble_incoming: colors["textBubble_incoming"] ?? parent.palette.textBubble_incoming,
                                textBubble_outgoing: colors["textBubble_outgoing"] ?? parent.palette.textBubble_outgoing,
                                selectMessageBubble: colors["selectMessageBubble"] ?? parent.palette.selectMessageBubble,
                                fileActivityBackground: colors["fileActivityBackground"] ?? parent.palette.fileActivityBackground,
                                fileActivityForeground: colors["fileActivityForeground"] ?? parent.palette.fileActivityForeground,
                                fileActivityBackgroundBubble_incoming: colors["fileActivityBackgroundBubble_incoming"] ?? parent.palette.fileActivityBackgroundBubble_incoming,
                                fileActivityBackgroundBubble_outgoing: colors["fileActivityBackgroundBubble_outgoing"] ?? parent.palette.fileActivityBackgroundBubble_outgoing,
                                fileActivityForegroundBubble_incoming: colors["fileActivityForegroundBubble_incoming"] ?? parent.palette.fileActivityForegroundBubble_incoming,
                                fileActivityForegroundBubble_outgoing: colors["fileActivityForegroundBubble_outgoing"] ?? parent.palette.fileActivityForegroundBubble_outgoing,
                                waveformBackground: colors["waveformBackground"] ?? parent.palette.waveformBackground,
                                waveformForeground: colors["waveformForeground"] ?? parent.palette.waveformForeground,
                                waveformBackgroundBubble_incoming: colors["waveformBackgroundBubble_incoming"] ?? parent.palette.waveformBackgroundBubble_incoming,
                                waveformBackgroundBubble_outgoing: colors["waveformBackgroundBubble_outgoing"] ?? parent.palette.waveformBackgroundBubble_outgoing,
                                waveformForegroundBubble_incoming: colors["waveformForegroundBubble_incoming"] ?? parent.palette.waveformForegroundBubble_incoming,
                                waveformForegroundBubble_outgoing: colors["waveformForegroundBubble_outgoing"] ?? parent.palette.waveformForegroundBubble_outgoing,
                                webPreviewActivity: colors["webPreviewActivity"] ?? parent.palette.webPreviewActivity,
                                webPreviewActivityBubble_incoming: colors["webPreviewActivityBubble_incoming"] ?? parent.palette.webPreviewActivityBubble_incoming,
                                webPreviewActivityBubble_outgoing: colors["webPreviewActivityBubble_outgoing"] ?? parent.palette.webPreviewActivityBubble_outgoing,
                                redBubble_incoming: colors["redBubble_incoming"] ?? parent.palette.redBubble_incoming,
                                redBubble_outgoing: colors["redBubble_outgoing"] ?? parent.palette.redBubble_outgoing,
                                greenBubble_incoming: colors["greenBubble_incoming"] ?? parent.palette.greenBubble_incoming,
                                greenBubble_outgoing: colors["greenBubble_outgoing"] ?? parent.palette.greenBubble_outgoing,
                                chatReplyTitle: colors["chatReplyTitle"] ?? parent.palette.chatReplyTitle,
                                chatReplyTextEnabled: colors["chatReplyTextEnabled"] ?? parent.palette.chatReplyTextEnabled,
                                chatReplyTextDisabled: colors["chatReplyTextDisabled"] ?? parent.palette.chatReplyTextDisabled,
                                chatReplyTitleBubble_incoming: colors["chatReplyTitleBubble_incoming"] ?? parent.palette.chatReplyTitleBubble_incoming,
                                chatReplyTitleBubble_outgoing: colors["chatReplyTitleBubble_outgoing"] ?? parent.palette.chatReplyTitleBubble_outgoing,
                                chatReplyTextEnabledBubble_incoming: colors["chatReplyTextEnabledBubble_incoming"] ?? parent.palette.chatReplyTextEnabledBubble_incoming,
                                chatReplyTextEnabledBubble_outgoing: colors["chatReplyTextEnabledBubble_outgoing"] ?? parent.palette.chatReplyTextEnabledBubble_outgoing,
                                chatReplyTextDisabledBubble_incoming: colors["chatReplyTextDisabledBubble_incoming"] ?? parent.palette.chatReplyTextDisabledBubble_incoming,
                                chatReplyTextDisabledBubble_outgoing: colors["chatReplyTextDisabledBubble_outgoing"] ?? parent.palette.chatReplyTextDisabledBubble_outgoing,
                                groupPeerNameRed: colors["groupPeerNameRed"] ?? parent.palette.groupPeerNameRed,
                                groupPeerNameOrange: colors["groupPeerNameOrange"] ?? parent.palette.groupPeerNameOrange,
                                groupPeerNameViolet: colors["groupPeerNameViolet"] ?? parent.palette.groupPeerNameViolet,
                                groupPeerNameGreen: colors["groupPeerNameGreen"] ?? parent.palette.groupPeerNameGreen,
                                groupPeerNameCyan: colors["groupPeerNameCyan"] ?? parent.palette.groupPeerNameCyan,
                                groupPeerNameLightBlue: colors["groupPeerNameLightBlue"] ?? parent.palette.groupPeerNameLightBlue,
                                groupPeerNameBlue: colors["groupPeerNameBlue"] ?? parent.palette.groupPeerNameBlue,
                                peerAvatarRedTop: colors["peerAvatarRedTop"] ?? parent.palette.peerAvatarRedTop,
                                peerAvatarRedBottom: colors["peerAvatarRedBottom"] ?? parent.palette.peerAvatarRedBottom,
                                peerAvatarOrangeTop: colors["peerAvatarOrangeTop"] ?? parent.palette.peerAvatarOrangeTop,
                                peerAvatarOrangeBottom: colors["peerAvatarOrangeBottom"] ?? parent.palette.peerAvatarOrangeBottom,
                                peerAvatarVioletTop: colors["peerAvatarVioletTop"] ?? parent.palette.peerAvatarVioletTop,
                                peerAvatarVioletBottom: colors["peerAvatarVioletBottom"] ?? parent.palette.peerAvatarVioletBottom,
                                peerAvatarGreenTop: colors["peerAvatarGreenTop"] ?? parent.palette.peerAvatarGreenTop,
                                peerAvatarGreenBottom: colors["peerAvatarGreenBottom"] ?? parent.palette.peerAvatarGreenBottom,
                                peerAvatarCyanTop: colors["peerAvatarCyanTop"] ?? parent.palette.peerAvatarCyanTop,
                                peerAvatarCyanBottom: colors["peerAvatarCyanBottom"] ?? parent.palette.peerAvatarCyanBottom,
                                peerAvatarBlueTop: colors["peerAvatarBlueTop"] ?? parent.palette.peerAvatarBlueTop,
                                peerAvatarBlueBottom: colors["peerAvatarBlueBottom"] ?? parent.palette.peerAvatarBlueBottom,
                                peerAvatarPinkTop: colors["peerAvatarPinkTop"] ?? parent.palette.peerAvatarPinkTop,
                                peerAvatarPinkBottom: colors["peerAvatarPinkBottom"] ?? parent.palette.peerAvatarPinkBottom,
                                bubbleBackgroundHighlight_incoming: colors["bubbleBackgroundHighlight_incoming"] ?? parent.palette.bubbleBackgroundHighlight_incoming,
                                bubbleBackgroundHighlight_outgoing: colors["bubbleBackgroundHighlight_outgoing"] ?? parent.palette.bubbleBackgroundHighlight_outgoing,
                                chatDateActive: colors["chatDateActive"] ?? parent.palette.chatDateActive,
                                chatDateText: colors["chatDateText"] ?? parent.palette.chatDateText,
                                revealAction_neutral1_background: colors["revealAction_neutral1_background"] ?? parent.palette.revealAction_neutral1_background,
                                revealAction_neutral1_foreground: colors["revealAction_neutral1_foreground"] ?? parent.palette.revealAction_neutral1_foreground,
                                revealAction_neutral2_background: colors["revealAction_neutral2_background"] ?? parent.palette.revealAction_neutral2_background,
                                revealAction_neutral2_foreground: colors["revealAction_neutral2_foreground"] ?? parent.palette.revealAction_neutral2_foreground,
                                revealAction_destructive_background: colors["revealAction_destructive_background"] ?? parent.palette.revealAction_destructive_background,
                                revealAction_destructive_foreground: colors["revealAction_destructive_foreground"] ?? parent.palette.revealAction_destructive_foreground,
                                revealAction_constructive_background: colors["revealAction_constructive_background"] ?? parent.palette.revealAction_constructive_background,
                                revealAction_constructive_foreground: colors["revealAction_constructive_foreground"] ?? parent.palette.revealAction_constructive_foreground,
                                revealAction_accent_background: colors["revealAction_accent_background"] ?? parent.palette.revealAction_accent_background,
                                revealAction_accent_foreground: colors["revealAction_accent_foreground"] ?? parent.palette.revealAction_accent_foreground,
                                revealAction_warning_background: colors["revealAction_warning_background"] ?? parent.palette.revealAction_warning_background,
                                revealAction_warning_foreground: colors["revealAction_warning_foreground"] ?? parent.palette.revealAction_warning_foreground,
                                revealAction_inactive_background: colors["revealAction_inactive_background"] ?? parent.palette.revealAction_inactive_background,
                                revealAction_inactive_foreground: colors["revealAction_inactive_foreground"] ?? parent.palette.revealAction_inactive_foreground,
                                chatBackground: colors["chatBackground"] ?? parent.palette.chatBackground,
                                listBackground: colors["listBackground"] ?? parent.palette.listBackground,
                                listGrayText: colors["listGrayText"] ?? parent.palette.listGrayText,
                                grayHighlight: colors["grayHighlight"] ?? parent.palette.grayHighlight,
                                focusAnimationColor: colors["focusAnimationColor"] ?? parent.palette.focusAnimationColor)
        }
        
    }
    
    return nil
}


func exportPalette(palette: ColorPalette, completion:((String?)->Void)? = nil) -> Void {
    let string = palette.toString
    let temp = NSTemporaryDirectory() + "tmac.palette"
    try? string.write(to: URL(fileURLWithPath: temp), atomically: true, encoding: .utf8)
    savePanel(file: temp, ext: "palette", for: mainWindow, defaultName: "\(palette.name).palette", completion: completion)
}



func findBestNameForPalette(_ palette: ColorPalette) -> String {
    return generateThemeName(palette.accent)
}


//
//    let readList = Bundle.main.path(forResource: "theme-names-tree", ofType: nil)
//
//    if let readList = readList, let string = try? String(contentsOfFile: readList) {
//        let lines = string.components(separatedBy: "\n")
//
//        var list:[(String, NSColor)] = []
//
//        for line in lines {
//            let value = line.components(separatedBy: "=")
//            if value.count == 2 {
//                if let color = NSColor(hexString: value[1]) {
//                    let name = value[0].components(separatedBy: " ").map({ $0.capitalizingFirstLetter() }).joined(separator: " ")
//                    list.append((name, color))
//                }
//            }
//        }
//
//        if list.count > 0 {
//
//            let first = pow(palette.accent.hsv.0 - list[0].1.hsv.0, 2) + pow(palette.accent.hsv.1 - list[0].1.hsv.1, 2) + pow(palette.accent.hsv.2 - list[0].1.hsv.2, 2)
//            var closest: (Int, CGFloat) = (0, first)
//
//
//            for i in 0 ..< list.count {
//                let distance = pow(palette.accent.hsv.0 - list[i].1.hsv.0, 2) + pow(palette.accent.hsv.1 - list[i].1.hsv.1, 2) + pow(palette.accent.hsv.2 - list[i].1.hsv.2, 2)
//                if distance < closest.1 {
//                    closest = (i, distance)
//                }
//            }
//
//            if let animalsPath = Bundle.main.path(forResource: "animals", ofType: nil), let string = try? String(contentsOfFile: animalsPath) {
//                let animals = string.components(separatedBy: "\n").filter { !$0.isEmpty }
//                let animal = animals[Int(arc4random()) % animals.count].capitalizingFirstLetter()
//                return list[closest.0].0 + " " + animal
//            }
//            return list[closest.0].0
//        }
//
//    }
//
//    return palette.name

