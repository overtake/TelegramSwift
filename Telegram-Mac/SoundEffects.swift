//
//  SoundEffects.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 10.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa

enum SoundEffect {
    case quizCorrect
    case quizIncorrect
    case confetti
    var name: String {
        switch self {
        case .quizCorrect:
            return "quiz-correct"
        case .quizIncorrect:
            return "quiz-incorrect"
        case .confetti:
            return "confetti"
        }
    }
    var ext: String {
        switch self {
        case .quizCorrect, .quizIncorrect, .confetti:
            return "mp3"
        }
    }
}


func playSoundEffect(_ sound: SoundEffect) {
    let afterSentSound:NSSound? = {
        
        let p = Bundle.main.path(forResource: sound.name, ofType: sound.ext)
        var sound:NSSound?
        if let p = p {
            sound = NSSound(contentsOfFile: p, byReference: true)
            sound?.volume = 0.1
        }
        
        return sound
    }()
    afterSentSound?.play()
}
