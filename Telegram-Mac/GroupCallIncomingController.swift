import TelegramCore
import SwiftSignalKit
import Postbox
import TGUIKit

//
//final class GroupCallIncomingController : ViewController {
//    fileprivate let context: AccountContext
//    fileprivate let conferenceSource: InternalGroupCallReference
//    fileprivate let otherParticipants: [EnginePeer]
//    init(context: AccountContext, otherParticipants: [EnginePeer], conferenceSource: InternalGroupCallReference) {
//        self.context = context
//        self.conferenceSource = conferenceSource
//        self.otherParticipants = otherParticipants
//        super.init()
//    }
//    
//    override func viewClass() -> AnyClass {
//        return GroupCallIncomingView.self
//    }
//    
//    var genericView: GroupCallIncomingView {
//        return self.view as! GroupCallIncomingView
//    }
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        genericView.update(participants: otherParticipants, context: context, animated: false)
//        
//    }
//}
