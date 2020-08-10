import SyncCore

struct VideoCallsConfiguration: Equatable {
    enum VideoCallsSupport {
        case disabled
        case full
        case onlyVideo
    }
    
    var videoCallsSupport: VideoCallsSupport
    
    init(appConfiguration: AppConfiguration) {
        var videoCallsSupport: VideoCallsSupport = .full
        if let data = appConfiguration.data, let value = data["video_calls_support"] as? String {
            switch value {
            case "disabled":
                videoCallsSupport = .disabled
            case "full":
                videoCallsSupport = .full
            case "only_video":
                videoCallsSupport = .onlyVideo
            default:
                videoCallsSupport = .full
            }
        }
        self.videoCallsSupport = videoCallsSupport
    }
}

extension VideoCallsConfiguration {
    var areVideoCallsEnabled: Bool {
        switch self.videoCallsSupport {
        case .disabled:
            return false
        case .full, .onlyVideo:
            return true
        }
    }
}
