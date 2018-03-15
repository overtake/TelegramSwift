//
//  VideoCameraStructures.swift
//  Telegram
//
//  Created by keepcoder on 02/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

enum VideoCameraRecordingStatus : Equatable {
    case idle
    case startingRecording
    case recording
    case madeThumbnail(CGImage)
    case stoppingRecording
    case stopped(thumb: CGImage?)
    case finishRecording(path:String, duration:Int, id: Int64?, thumb: CGImage?)
}

func ==(lhs: VideoCameraRecordingStatus, rhs: VideoCameraRecordingStatus) -> Bool {
    switch lhs {
    case .idle:
        if case .idle = rhs {
            return true
        } else {
            return false
        }
    case .startingRecording:
        if case .startingRecording = rhs {
            return true
        } else {
            return false
        }
    case .recording:
        if case .recording = rhs {
            return true
        } else {
            return false
        }
    case .stoppingRecording:
        if case .stoppingRecording = rhs {
            return true
        } else {
            return false
        }
    case .madeThumbnail:
        if case .madeThumbnail = rhs {
            return true
        } else {
            return false
        }
    case .stopped:
        if case .stopped = rhs {
            return true
        } else {
            return false
        }
    case .finishRecording:
        if case .finishRecording = rhs {
            return true
        } else {
            return false
        }
    }
}
