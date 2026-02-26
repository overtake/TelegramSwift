import TelegramCore
import Foundation
import AppKit
import Postbox
import SwiftSignalKit
import TGUIKit
import Localization

internal final class PeerCallParticipantsView : View {
    private let textView: TextView = TextView()
    private var avatars: NSView?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(participants: [EnginePeer], arguments: Arguments, animated: Bool) {
        
        self.background = NSColor.white.withAlphaComponent(0.15)
        
        let textLayout = TextViewLayout(.initialize(string: L10n.chatGroupCallMembersCountable(participants.count), color: .white, font: .medium(.text)))
        
        textLayout.measure(width: .greatestFiniteMagnitude)
        
        self.textView.update(textLayout)
        
        let avatars = arguments.makeParticipants(self.avatars, participants)
        addSubview(avatars)
        self.avatars = avatars
        
        self.setFrameSize(NSMakeSize(3 + avatars.frame.width + 5 + textLayout.layoutSize.width + 8, 30))
        
        layer?.cornerRadius = frame.height / 2
        
                
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        if let avatars {
            avatars.centerY(x: 3)
            self.textView.centerY(x: avatars.frame.maxX + 5)
        } else {
            self.textView.centerY(x: 5)
        }
    }
}
