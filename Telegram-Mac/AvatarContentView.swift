//
//  AvatarContentView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05.09.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


final class AvatarContentView: View {
    private let unclippedView: ImageView
    private let clippedView: ImageView

    private var disposable: Disposable?
    private var audioLevelView: VoiceBlobView?

    let peerId: PeerId

    private var scaleAnimator: DisplayLinkAnimator?
    private let inset: CGFloat
    init(context: AccountContext, peer: Peer, message: Message?, synchronousLoad: Bool, size: NSSize, inset: CGFloat = 3) {
        self.peerId = peer.id
        self.inset = inset
        self.unclippedView = ImageView()
        self.clippedView = ImageView()
        
        super.init(frame: CGRect(origin: .zero, size: size))
        
        self.addSubview(self.unclippedView)
        self.addSubview(self.clippedView)

        
        
        let signal = peerAvatarImage(account: context.account, photo: .peer(peer, peer.smallProfileImage, peer.displayLetters, nil), displayDimensions: size, scale: System.backingScale, font: .avatar(size.height / 3 + 3), genCap: true, synchronousLoad: synchronousLoad)
        
        let disposable = (signal
            |> deliverOnMainQueue).start(next: { [weak self] image in
                guard let strongSelf = self else {
                    return
                }
                if let image = image.0 {
                    strongSelf.updateImage(image: image)
                }
            })
        self.disposable = disposable
    }

    func updateAudioLevel(color: NSColor, value: Float) {
        if self.audioLevelView == nil, value > 0.0 {
            let blobFrame = NSMakeRect(0, 0, frame.width + 8, frame.height + 8)

            let audioLevelView = VoiceBlobView(
                frame: blobFrame,
                maxLevel: 0.3,
                smallBlobRange: (0, 0),
                mediumBlobRange: (0.7, 0.8),
                bigBlobRange: (0.8, 0.9)
            )


            audioLevelView.setColor(color)
            self.audioLevelView = audioLevelView
            self.addSubview(audioLevelView, positioned: .below, relativeTo: self.subviews.first)
            audioLevelView.center()
      }

      let level = min(1.0, max(0.0, CGFloat(value)))
      if let audioLevelView = self.audioLevelView {
          audioLevelView.updateLevel(CGFloat(value) * 2.0)

          let avatarScale: CGFloat
          let audioLevelScale: CGFloat
          if value > 0.0 {
              audioLevelView.startAnimating()
              avatarScale = 1.03 + level * 0.07
              audioLevelScale = 1.0
          } else {
              audioLevelView.stopAnimating()
              avatarScale = 1.0
              audioLevelScale = 0.01
          }
            let t = clippedView.layer!.transform
            let scale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
            self.scaleAnimator = DisplayLinkAnimator(duration: 0.1, from: scale, to: avatarScale, update: { [weak self] value in
                guard let `self` = self else {
                    return
                }

                let rect = self.clippedView.bounds

                var fr = CATransform3DIdentity
                fr = CATransform3DTranslate(fr, rect.width / 2, rect.width / 2, 0)
                fr = CATransform3DScale(fr, value, value, 1)
                fr = CATransform3DTranslate(fr, -(rect.width / 2), -(rect.height / 2), 0)

                self.clippedView.layer?.transform = fr
                self.unclippedView.layer?.transform = fr

            }, completion: {

            })
      }
  }

    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    private func updateImage(image: CGImage) {
        self.unclippedView.image = image
        let frameSize = NSMakeSize(frame.height, frame.height)
        self.clippedView.image = generateImage(frameSize, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            context.draw(image, in: CGRect(origin: CGPoint(), size: size))
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            
            context.setBlendMode(.copy)
            context.setFillColor(NSColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: -(inset / 2), dy: -(inset / 2)).offsetBy(dx: -(frameSize.width - inset), dy: 0.0))
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func updateLayout(size: CGSize, isClipped: Bool, animated: Bool) {
        self.unclippedView.frame = CGRect(origin: focus(size).origin, size: size)
        self.clippedView.frame = CGRect(origin: focus(size).origin, size: size)
        self.unclippedView.change(opacity: isClipped ? 0.0 : 1.0, animated: animated)
        self.clippedView.change(opacity: isClipped ? 1.0 : 0.0, animated: animated)
    }
}

