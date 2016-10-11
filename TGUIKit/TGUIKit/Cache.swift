import Foundation
import SwiftSignalKitMac
import TelegramCoreMac

let threadPool = ThreadPool(threadCount: 4, threadPriority: 0.2)

func cachedCloudFileLocation(_ location: TelegramCloudMediaLocation) -> Signal<Data, NoError> {
    return Signal { subscriber in
        switch location.apiInputLocation {
            case let .inputFileLocation(volumeId, localId, _):
                let path = NSTemporaryDirectory() + "/\(location.datacenterId)_\(volumeId)_\(localId)"
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                    subscriber.putNext(data)
                    subscriber.putCompletion()
                } catch {
                    subscriber.putError(NoError())
                }
            
            case _:
                subscriber.putError(NoError())
        }
        return ActionDisposable {
            
        }
    }
}

func cacheCloudFileLocation(_ location: TelegramCloudMediaLocation, data: Data) {
    switch location.apiInputLocation {
        case let .inputFileLocation(volumeId, localId, _):
            let path = NSTemporaryDirectory() + "/\(location.datacenterId)_\(volumeId)_\(localId)"
            let _ = try? data.write(to: URL(fileURLWithPath: path), options: [.atomicWrite])
        case _:
            break
    }
}
