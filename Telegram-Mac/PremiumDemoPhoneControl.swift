//
//  PremiumDemoPhoneController.swift
//  Telegram
//
//  Created by Mike Renoir on 13.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramMedia

let demoPhoneSize = CGSize(width: 262.0, height: 539.0)
private var phoneBorderImage = {
    return generateImage(demoPhoneSize, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        context.setFillColor(NSColor(rgb: 0x000000, alpha: 0.5).cgColor)
        try? drawSvgPath(context, path: "M203.506,7.0 C211.281,0.0 217.844,0.0 223.221,0.439253 C228.851,0.899605 234.245,1.90219 239.377,4.51905 C247.173,8.49411 253.512,14.8369 257.484,22.6384 C260.099,27.7743 261.101,33.1718 261.561,38.8062 C262.0,44.1865 262.0,50.754 262.0,58.5351 V480.465 C262.0,488.246 262.0,494.813 261.561,500.194 C261.101,505.828 260.099,511.226 257.484,516.362 C253.512,524.163 247.173,530.506 239.377,534.481 C234.245,537.098 228.851,538.1 223.221,538.561 C217.844,539.0 211.281,539.0 203.506,539.0 H58.4942 C50.7185,539 44.1556,539.0 38.7791,538.561 C33.1486,538.1 27.7549,537.098 22.6226,534.481 C14.8265,530.506 8.48817,524.163 4.51589,516.362 C1.90086,511.226 0.898976,505.828 0.438946,500.194 C0.0,494.813 0.0,488.246 7.0,480.465 V58.5354 C0.0,50.7541 0.0,44.1866 0.438946,38.8062 C0.898976,33.1718 1.90086,27.7743 4.51589,22.6384 C8.48817,14.8369 14.8265,8.49411 22.6226,4.51905 C27.7549,1.90219 33.1486,0.899605 38.7791,0.439253 C44.1557,-0.0 50.7187,0.0 58.4945,7.0 H203.506 Z ")
        context.setBlendMode(.copy)
        context.fill(CGRect(origin: CGPoint(x: 43.0, y: 1), size: CGSize(width: 175.0, height: 8.0)))
        context.fill(CGRect(origin: CGPoint(x: 0, y: 43.0), size: CGSize(width: 8.0, height: 452.0)))
        
        context.setBlendMode(.clear)
        try? drawSvgPath(context, path: "M15.3737,28.1746 C12.1861,34.4352 12.1861,42.6307 12.1861,59.0217 V479.978 C12.1861,496.369 12.1861,504.565 15.3737,510.825 C18.1777,516.332 22.6518,520.81 28.1549,523.615 C34.4111,526.805 42.6009,526.805 58.9805,526.805 H203.02 C219.399,526.805 227.589,526.805 233.845,523.615 C239.348,520.81 243.822,516.332 246.626,510.825 C249.814,504.565 249.814,496.369 249.814,479.978 V59.0217 C249.814,42.6307 249.814,34.4352 246.626,28.1746 C243.822,22.6677 239.348,18.1904 233.845,15.3845 C227.589,12.1946 219.399,12.1946 203.02,12.1946 H58.9805 C42.6009,12.1946 34.4111,12.1946 28.1549,15.3845 C22.6518,18.1904 18.1777,22.6677 15.3737,28.1746 Z ")
        
        context.setBlendMode(.copy)
        context.setFillColor(NSColor.black.cgColor)
        try? drawSvgPath(context, path: "M222.923,4.08542 C217.697,3.65815 211.263,3.65823 203.378,3.65833 H58.6219 C50.7366,3.65823 44.3026,3.65815 39.0768,4.08542 C33.6724,4.52729 28.8133,5.46834 24.2823,7.77863 C17.1741,11.4029 11.395,17.1861 7.77325,24.2992 C5.46457,28.8334 4.52418,33.6959 4.08262,39.1041 C3.65565,44.3336 3.65573,50.7721 3.65583,58.6628 V480.337 C3.65573,488.228 3.65565,494.666 4.08262,499.896 C4.52418,505.304 5.46457,510.167 7.77325,514.701 C11.395,521.814 17.1741,527.597 24.2823,531.221 C28.8133,533.532 33.6724,534.473 39.0768,534.915 C44.3028,535.342 50.737,535.342 58.6226,535.342 H203.377 C211.263,535.342 217.697,535.342 222.923,534.915 C228.328,534.473 233.187,533.532 237.718,531.221 C244.826,527.597 250.605,521.814 254.227,514.701 C256.535,510.167 257.476,505.304 257.917,499.896 C258.344,494.667 258.344,488.228 258.344,480.338 V58.6617 C258.344,50.7714 258.344,44.3333 257.917,39.1041 C257.476,33.6959 256.535,28.8334 254.227,24.2992 C250.605,17.1861 244.826,11.4029 237.718,7.77863 C233.187,5.46834 228.328,4.52729 222.923,4.08542 Z ")
        
        context.setBlendMode(.clear)
        try? drawSvgPath(context, path: "M12.1861,59.0217 C12.1861,42.6306 12.1861,34.4351 15.3737,28.1746 C18.1777,22.6676 22.6519,18.1904 28.1549,15.3844 C34.4111,12.1945 42.6009,12.1945 58.9805,12.1945 H76.6868 L76.8652,12.1966 C78.1834,12.2201 79.0316,12.4428 79.7804,12.8418 C80.5733,13.2644 81.1963,13.8848 81.6226,14.6761 C81.9735,15.3276 82.1908,16.0553 82.2606,17.1064 C82.3128,22.5093 82.9306,24.5829 84.0474,26.6727 C85.2157,28.8587 86.9301,30.5743 89.1145,31.7434 C91.299,32.9124 93.4658,33.535 99.441,33.535 H162.561 C168.537,33.535 170.703,32.9124 172.888,31.7434 C175.072,30.5743 176.787,28.8587 177.955,26.6727 C179.072,24.5829 179.69,22.5093 179.742,17.1051 C179.812,16.0553 180.029,15.3276 180.38,14.6761 C180.806,13.8848 181.429,13.2644 182.222,12.8418 C182.971,12.4428 183.819,12.2201 185.137,12.1966 L185.316,12.1945 H203.02 C219.399,12.1945 227.589,12.1945 233.845,15.3844 C239.348,18.1904 243.822,22.6676 246.626,28.1746 C249.814,34.4351 249.814,42.6306 249.814,59.0217 V479.978 C249.814,496.369 249.814,504.565 246.626,510.825 C243.822,516.332 239.348,520.81 233.845,523.615 C227.589,526.805 219.399,526.805 203.02,526.805 H58.9805 C42.6009,526.805 34.4111,526.805 28.1549,523.615 C22.6519,520.81 18.1777,516.332 15.3737,510.825 C12.1861,504.565 12.1861,496.369 12.1861,479.978 V59.0217 Z ")
    })
}()

private var phoneBorderMaskImage = {
    generateImage(demoPhoneSize, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.0)
        
        context.translateBy(x: 12.0, y: 12.0 - .borderSize)
        
        try? drawSvgPath(context, path: "M1.17188,47.3156 C1.17188,39.1084 1.17265,33.013 1.56706,28.1857 C1.96052,23.3701 2.74071,19.9044 4.25094,16.9404 C6.95936,11.6248 11.2811,7.30311 16.5966,4.59469 C19.5606,3.08446 23.0263,2.30427 27.842,1.91081 C32.6693,1.5164 38.7646,1.51562 46.9719,1.51562 H64.6745 H64.6803 L64.8409,1.51754 C64.8419,1.51756 64.8429,1.51758 64.8439,1.5176 C66.0418,1.53925 66.7261,1.73731 67.3042,2.04519 L67.7736,1.16377 L67.3042,2.04519 C67.9232,2.37486 68.4036,2.8529 68.7364,3.47024 C69.0069,3.97209 69.1915,4.54972 69.2551,5.46352 C69.3102,10.9333 69.9419,13.1793 71.16,15.457 C72.4216,17.816 74.2789,19.6733 76.6379,20.9349 C79.0269,22.2126 81.3803,22.8438 87.4372,22.8438 H150.565 C156.622,22.8438 158.976,22.2126 161.364,20.9349 C163.723,19.6733 165.581,17.816 166.842,15.457 C168.061,13.1793 168.692,10.9334 168.747,5.46231 C168.811,4.54985 168.995,3.97217 169.266,3.47025 C169.599,2.8529 170.079,2.37486 170.698,2.04519 C171.276,1.7373 171.961,1.53925 173.159,1.5176 C173.16,1.51758 173.161,1.51756 173.162,1.51754 L173.322,1.51562 H173.328 H191.028 C199.235,1.51562 205.331,1.5164 210.158,1.91081 C214.974,2.30427 218.439,3.08446 221.403,4.59469 C226.719,7.30311 231.041,11.6248 233.749,16.9404 C235.259,19.9044 236.039,23.3701 236.433,28.1857 C236.827,33.013 236.828,39.1084 236.828,47.3156 V468.028 C236.828,476.235 236.827,482.331 236.433,487.158 C236.039,491.974 235.259,495.439 233.749,498.403 C231.041,503.719 226.719,508.041 221.403,510.749 C218.439,512.259 214.974,513.039 210.158,513.433 C205.331,513.827 199.235,513.828 191.028,513.828 H46.9719 C38.7646,513.828 32.6693,513.827 27.842,513.433 C23.0263,513.039 19.5606,512.259 16.5966,510.749 C11.2811,508.041 6.95936,503.719 4.25094,498.403 C2.74071,495.439 1.96052,491.974 1.56706,487.158 C1.17265,482.331 1.17188,476.235 1.17188,468.028 V47.3156 S ")
    })
}()

let demoStartMaskSize = NSMakeSize(88, 84)
private var starMaskImage = {
    return generateImage(demoStartMaskSize, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
      
        context.setFillColor(NSColor.white.cgColor)
        
        try? drawSvgPath(context, path: "M41.7419,71.1897 L22.1639,83.1833 C20.1282,84.4304 17.4669,83.7911 16.2198,81.7553 C15.6107,80.7611 15.4291,79.5629 15.7162,78.4328 L18.7469,66.504 C19.8409,62.1979 22.7876,58.5983 26.7928,56.6754 L48.1514,46.4207 C49.1472,45.9426 49.5668,44.7479 49.0887,43.7521 C48.7016,42.9457 47.826,42.4945 46.9446,42.6471 L23.1697,46.7631 C18.3368,47.5998 13.3807,46.2653 9.62146,43.1149 L2.11077,36.8207 C0.28097,35.2873 0.0407101,32.5609 1.57413,30.7311 C2.31994,29.8411 3.39241,29.2886 4.55001,29.198 L27.4974,27.4022 C29.1186,27.2753 30.5314,26.2494 31.1537,24.747 L40.0064,3.37722 C40.9201,1.17161 43.4488,0.124313 45.6544,1.03801 C46.7135,1.47673 47.5549,2.31816 47.9936,3.37722 L56.8463,24.747 C57.4686,26.2494 58.8815,27.2753 60.5026,27.4022 L83.5761,29.2079 C85.9562,29.3942 87.7347,31.4746 87.5484,33.8547 C87.4588,34.9997 86.9172,36.0619 86.0433,36.807 L68.4461,51.809 C67.2073,52.8651 66.6669,54.5275 67.0478,56.1102 L72.4577,78.5841 C73.0165,80.9052 71.5878,83.2397 69.2667,83.7985 C68.1515,84.0669 66.9752,83.8811 65.997,83.2818 L46.2581,71.1897 C44.8724,70.3408 43.1277,70.3408 41.7419,71.1897 Z ")
    })
}()



final class PremiumPhoneDemoView: View {
    
    enum Position {
        case top
        case bottom
    }
    
    var position: Position = .top



    
    let contentContainerView: View
    
    let overlayView: View
    let borderView: ImageView
    
    let backShimmerView: View
    let backShimmerEffectView: ShimmerEffectForegroundView
    let backShimmerFadeView: View
    
    let frontShimmerView: View
    let shimmerEffectView: ShimmerEffectForegroundView
    let shimmerMaskView: View
    let shimmerBorderView: ImageView
    let shimmerStarView: ImageView
    
    fileprivate var videoView: MediaPlayerView?
    
    var playbackStatus: Signal<MediaPlayerStatus?, NoError> {
        return self.playbackStatusPromise.get()
    }
    private var playbackStatusPromise = ValuePromise<MediaPlayerStatus?>(nil)
    private var playbackStatusValue: MediaPlayerStatus?
    private var statusDisposable = MetaDisposable()
    
    var screenRotation: CGFloat = 0.0 {
        didSet {
            if self.screenRotation > 0.0 {
                self.overlayView.backgroundColor = .white
            } else {
                self.overlayView.backgroundColor = .black
            }
            self.overlayView.layer?.opacity = Float(self.screenRotation > 0.0 ? self.screenRotation * 0.5 : self.screenRotation * -1.0)
        }
    }
    
    required init(frame: CGRect) {
        self.contentContainerView = View()
        self.contentContainerView.backgroundColor = .darkGray
        self.contentContainerView.layer?.cornerRadius = 10.0
        self.contentContainerView.layer?.allowsGroupOpacity = true
        
        self.overlayView = View()
        self.overlayView.backgroundColor = .black
        
        self.borderView = ImageView()
        self.borderView.image = phoneBorderImage
//        self.borderView.sizeToFit()
            
        self.shimmerMaskView = View()
        self.shimmerBorderView = ImageView()
        self.shimmerBorderView.image = phoneBorderMaskImage
//        self.shimmerBorderView.sizeToFit()

        self.shimmerStarView = ImageView()
        self.shimmerStarView.image = starMaskImage
//        self.shimmerStarView.sizeToFit()
        
        self.shimmerStarView.layer?.opacity = 0.7
        
        self.backShimmerView = View()
        self.backShimmerView.layer?.opacity = 0.0
        
        self.backShimmerEffectView = ShimmerEffectForegroundView()
        self.backShimmerFadeView = View()
        self.backShimmerFadeView.backgroundColor = NSColor(rgb: 0x000000, alpha: 0.2)
        
        self.frontShimmerView = View()
        self.frontShimmerView.layer?.opacity = 0.0
        self.shimmerEffectView = ShimmerEffectForegroundView()
        
        super.init(frame: frame)
        
        self.addSubview(self.contentContainerView)
        self.contentContainerView.addSubview(self.overlayView)
        self.contentContainerView.addSubview(self.backShimmerView)
        self.addSubview(self.borderView)
        self.addSubview(self.frontShimmerView)

        self.backShimmerView.addSubview(self.backShimmerEffectView)
        self.backShimmerView.addSubview(self.backShimmerFadeView)

        self.shimmerMaskView.addSubview(self.shimmerBorderView)
        self.shimmerMaskView.addSubview(self.shimmerStarView)

        self.frontShimmerView.layer?.mask = self.shimmerMaskView.layer
        self.frontShimmerView.addSubview(self.shimmerEffectView)

        self.backShimmerEffectView.update(backgroundColor: .clear, foregroundColor: NSColor.white.withAlphaComponent(0.35), horizontal: true)
        self.backShimmerEffectView.layer?.compositingFilter = "overlayBlendMode"

        self.shimmerEffectView.update(backgroundColor: .clear, foregroundColor: NSColor.white.withAlphaComponent(0.5), horizontal: true)
        self.shimmerEffectView.layer?.compositingFilter = "overlayBlendMode"
    }
    
    deinit {
        self.statusDisposable.dispose()
    }
    
    
    func setup(context: AccountContext, videoFile: TelegramMediaFile?) {
        
        guard self.videoView == nil, let file = videoFile else {
            return
        }
        
        self.contentContainerView.backgroundColor = .clear
//
//
//        videoView.canAttachContent = true
//        self.videoView = videoView
//
//        let status = videoView.status
//        |> mapToSignal { status -> Signal<MediaPlayerStatus?, NoError> in
//            var isLoading = false
//            if let status = status {
//                if case .buffering = status.status {
//                    isLoading = true
//                } else if status.duration.isZero {
//                    isLoading = true
//                }
//            }
//            if isLoading {
//                return .single(status) |> delay(0.6, queue: Queue.mainQueue())
//            } else {
//                return .single(status)
//            }
//        }
//
//        self.statusDisposable.set((status |> deliverOnMainQueue).start(next: { [weak self] status in
//            if let strongSelf = self {
//                strongSelf.playbackStatusValue = status
//                strongSelf.playbackStatusPromise.set(status)
//                strongSelf.updatePlaybackStatus()
//            }
//        }))
//
//        self.contentContainerView.insertSubview(videoView.view, at: 0)
//
//        videoView.pause()
        
    }
    
    private func updatePlaybackStatus() {
        var isDisplayingProgress = false
        if let playbackStatus = self.playbackStatusValue {
            if case .buffering = playbackStatus.status {
                isDisplayingProgress = true
            } else if playbackStatus.status == .playing {
                isDisplayingProgress = playbackStatus.duration.isZero
            }
        } else {
            isDisplayingProgress = true
        }
        
        let targetAlpha: Float = isDisplayingProgress ? 1.0 : 0.0
        if self.frontShimmerView.layer?.opacity != targetAlpha {
            let sourceAlpha = self.frontShimmerView.layer?.opacity ?? 0
            self.frontShimmerView.layer?.opacity = targetAlpha
            self.frontShimmerView.layer?.animateAlpha(from: CGFloat(sourceAlpha), to: CGFloat(targetAlpha), duration: 0.2)
            
            self.backShimmerView.layer?.opacity = targetAlpha
            self.backShimmerView.layer?.animateAlpha(from: CGFloat(sourceAlpha), to: CGFloat(targetAlpha), duration: 0.2)
        }
    }
    
    private var isPlaying = false
    func play() {
        if let videoView = self.videoView, !self.isPlaying {
            self.isPlaying = true
          //  videoView.play()
        }
    }
    
    func reset() {
        if let videoView = self.videoView {
            self.isPlaying = false
//            videoView.pause()
//            videoView.seek(0.0)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func layout() {
        super.layout()
        
        let phoneBounds = CGRect(origin: .zero, size: demoPhoneSize)
        self.borderView.frame = phoneBounds
        
        self.contentContainerView.frame = CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: CGSize(width: demoPhoneSize.width - 24.0, height: demoPhoneSize.height - 24.0))
        self.overlayView.frame = self.contentContainerView.bounds
        
        let videoSize = CGSize(width: self.contentContainerView.frame.width, height: 354.0)
//            if let videoView = self.videoView {
//                videoView.view.frame = CGRect(origin: CGPoint(x: 0.0, y: self.position == .top ? 0.0 : self.contentContainerView.frame.height - videoSize.height), size: videoSize)
//                videoView.updateLayout(size: videoSize, transition: .immediate)
//            }
        
        self.backShimmerView.frame = phoneBounds.insetBy(dx: -12.0, dy: -12.0)
        self.backShimmerEffectView.frame = phoneBounds
        self.backShimmerFadeView.frame = phoneBounds
        
        self.frontShimmerView.frame = phoneBounds
        self.shimmerEffectView.frame = phoneBounds
        self.shimmerMaskView.frame = phoneBounds
        self.shimmerBorderView.frame = phoneBounds
        
        self.backShimmerEffectView.updateAbsoluteRect(CGRect(origin: CGPoint(x: phoneBounds.width * 12.0, y: 0.0), size: phoneBounds.size), within: CGSize(width: phoneBounds.width * 25.0, height: phoneBounds.height))
        self.shimmerEffectView.updateAbsoluteRect(CGRect(origin: CGPoint(x: phoneBounds.width * 12.0, y: 0.0), size: phoneBounds.size), within: CGSize(width: phoneBounds.width * 25.0, height: phoneBounds.height))
        
        let notchHeight: CGFloat = 20.0

        let starSize = demoStartMaskSize
        self.shimmerStarView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((demoPhoneSize.width - starSize.width) / 2.0, System.backingScale), y: self.position == .top ? notchHeight + floor((videoSize.height - notchHeight - starSize.height) / 2.0) : self.contentContainerView.frame.height - videoSize.height + floor((videoSize.height - starSize.height) / 2.0)), size: starSize)
    }
}
