//
//  ChatUserInfoRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.02.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//
import TGUIKit
import TelegramCore
import Postbox

final class ChatUserInfoRowItem : ChatRowItem {
    
    
    fileprivate var attributes: ChatServiceItem.GiftData.UniqueAttributes
    fileprivate var settings: PeerStatusSettings
    
    fileprivate let commontGroups: TextViewLayout
    private let _peer: EnginePeer
    let groupsCount: Int
    
    init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ entry: ChatHistoryEntry, settings: PeerStatusSettings, peer: EnginePeer, commonGroups: GroupsInCommonState?, theme: TelegramPresentationTheme) {
        self.settings = settings
        self._peer = peer
        
        let context = chatInteraction.context
        
        let countries = context.currentCountriesConfiguration.with { $0 }
        
        var attrs: [ChatServiceItem.GiftData.UniqueAttributes.Attribute] = []
        let textColor: NSColor = isLite(.blur) ? theme.colors.text : theme.chatServiceItemTextColor

        
        let groupsCount: Int
        if let commonGroups {
            groupsCount = commonGroups.count ?? 0
        } else {
            groupsCount = 0
        }
        
        self.groupsCount = groupsCount
        
        
        commontGroups = .init(.initialize(string: strings().chatServiceNotOfficial , color: textColor.withAlphaComponent(0.8), font: .normal(.text)))

        
        if let registrationDate = settings.registrationDate {
            attrs.append(.init(name: .init(.initialize(string: strings().chatEmptyUserInfoRegistration, color: textColor.withAlphaComponent(0.8), font: .normal(.text))),
                               value: .init(.initialize(string: formatMonthYear(registrationDate, locale: appAppearance.locale), color: textColor, font: .medium(.text)))))
        }
        
        if let phoneCountry = settings.phoneCountry, let country = countries.countries.first(where: { $0.id == phoneCountry}) {
            attrs.append(.init(name: .init(.initialize(string: strings().chatEmptyUserInfoPhoneNumber, color: textColor.withAlphaComponent(0.8), font: .normal(.text))),
                               value: .init(.initialize(string: emojiFlagForISOCountryCode(phoneCountry) + " " +  country.name, color: textColor, font: .medium(.text)))))
        }
        if groupsCount > 0 {
            attrs.append(.init(name: .init(.initialize(string: strings().chatEmptyUserInfoCommonGroups, color: textColor.withAlphaComponent(0.8), font: .normal(.text))),
                               value: .init(.initialize(string: strings().chatServiceGroupsInCommonCountable(groupsCount), color: textColor, font: .medium(.text)))))
        }

        
        self.attributes = .init(header: .init(.initialize(string: peer._asPeer().displayTitle, color: textColor, font: .medium(.header)), maximumNumberOfLines: 1), attributes: attrs)
        
        super.init(initialSize, chatInteraction, entry, theme: theme)
    }
    
    override var shouldBlurService: Bool {
        if context.isLite(.blur) {
            return false
        }
        return presentation.shouldBlurService
    }
    
    override func viewClass() -> AnyClass {
        return ChatUserInfoRowView.self
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        attributes.makeSize(width: 260)
        
        commontGroups.measure(width: 260)
        
        return true
    }
    
    override var height: CGFloat {
        return attributes.height + 10 + commontGroups.layoutSize.height + 10
    }
    
    func openCommonGroups() {
        if groupsCount > 0 {
            context.bindings.rootNavigation().push(GroupsInCommonViewController(context: context, peerId: _peer.id, standalone: true))
        }
    }
}


private final class ChatUserInfoRowView : TableRowView {
    
    private class ContainerView : Control {
        
        
        private var visualEffect: VisualEffect?
        private let commontGroupsView = TextView()
        
        private var attributesView: UniqueAttributesView = .init(frame: .zero)
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            self.scaleOnClick = true
            layer?.cornerRadius = 12
                        
            addSubview(attributesView)
            addSubview(commontGroupsView)
        }
        
        func update(item: ChatUserInfoRowItem, animated: Bool) {
                        
            if item.shouldBlurService {
                let current: VisualEffect
                if let view = self.visualEffect {
                    current = view
                } else {
                    current = VisualEffect(frame: bounds)
                    self.visualEffect = current
                    addSubview(current, positioned: .below, relativeTo: self.subviews.first)
                }
                current.bgColor = item.presentation.blurServiceColor
                
                self.backgroundColor = .clear
                
            } else {
                if let view = visualEffect {
                    performSubviewRemoval(view, animated: animated)
                    self.visualEffect = nil
                }
                self.backgroundColor = item.presentation.chatServiceItemColor
            }
           
            attributesView.set(attributes: item.attributes, animated: animated)
            attributesView.setFrameSize(NSMakeSize(260, item.attributes.height))
            
            setSingle(handler: { [weak item] _ in
                item?.openCommonGroups()
            }, for: .Click)
            
            self.scaleOnClick = item.groupsCount > 0
            
            commontGroupsView.update(item.commontGroups)
            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            visualEffect?.frame = bounds
            attributesView.frame = bounds.focusX(attributesView.frame.size, y: 5)
            
            commontGroupsView.centerX(y: attributesView.frame.maxY - 5)
        }
        
        deinit {
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    override var backdorColor: NSColor {
        return .clear
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private let containerView = ContainerView(frame: .zero)
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatUserInfoRowItem else {
            return
        }
        
        
        containerView.setFrameSize(NSMakeSize(260, item.height - 10))
        containerView.update(item: item, animated: animated)
    }
    
    override func layout() {
        super.layout()
        containerView.center()
    }
}
