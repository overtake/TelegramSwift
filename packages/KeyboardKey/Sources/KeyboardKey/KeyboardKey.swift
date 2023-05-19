
import Cocoa

public enum KeyboardKey : UInt16  {
    case Zero = 29
    case One = 18
    case Two = 19
    case Three = 20
    case Four = 21
    case Five = 23
    case Six = 22
    case Seven = 26
    case Eight = 28
    case Nine = 25
    case A = 0
    case B = 11
    case C = 8
    case D = 2
    case E = 14
    case F = 3
    case G = 5
    case H = 4
    case I = 34
    case J = 38
    case K = 40
    case L = 37
    case M = 46
    case N = 45
    case O = 31
    case P = 35
    case Q = 12
    case R = 15
    case S = 1
    case T = 17
    case U = 32
    case V = 9
    case W = 13
    case X = 7
    case Y = 16
    case Z = 6
    case SectionSign = 10
    case Grave = 50
    case Minus = 27
    case Equal = 24
    case LeftBracket = 33
    case RightBracket = 30
    case Semicolon = 41
    case Quote = 39
    case Comma = 43
    case Period = 47
    case Slash = 44
    case Backslash = 42
    case Keypad0  = 82
    case Keypad1 = 83
    case Keypad2 = 84
    case Keypad3 = 85
    case Keypad4 = 86
    case Keypad5 = 87
    case Keypad6 = 88
    case Keypad7 = 89
    case Keypad8 = 91
    case Keypad9 = 92
    case KeypadDecimal = 65
    case KeypadMultiply = 67
    case KeypadPlus = 69
    case KeypadDivide = 75
    case KeypadMinus = 78
    case KeypadEquals = 81
    case KeypadClear = 71
    case KeypadEnter = 76
    case Space = 49
    case Return = 36
    case Tab = 48
    case Delete = 51
    case ForwardDelete = 117
    case Linefeed = 52
    case Escape = 53
    case Command = 55
    case Shift = 56
    case CapsLock = 57
    case Option = 58
    case Control = 59
    case RightShift = 60
    case RightOption = 61
    case RightControl = 62
    case Function = 63
    
    case Help = 114
    case Home = 115
    case End = 119
    case PageUp = 116
    case PageDown = 121
    case LeftArrow = 123
    case RightArrow = 124
    case DownArrow = 125
    case UpArrow = 126
    case All = 1000
    case Undefined = 1001
    public var isFlagKey: Bool {
        return self == .Shift || self == .CapsLock || self == .Command || self == .Option || self == .Control || self == .RightShift || self == .RightOption || self == .RightControl || self == .Function
    }
    
    public static func keyboardKey(_ number: Int) -> KeyboardKey? {
        switch number {
        case 0:
            return .Zero
        case 1:
            return .One
        case 2:
            return .Two
        case 3:
            return .Three
        case 4:
            return .Four
        case 5:
            return .Five
        case 6:
            return .Six
        case 7:
            return .Seven
        case 8:
            return .Eight
        case 9:
            return .Nine
        default:
            return nil
        }
    }
    
    public var number: UInt16? {
        switch self {
        case .Zero, .Keypad0:
            return 0
        case .One, .Keypad1:
            return 1
        case .Two, .Keypad2:
            return 2
        case .Three, .Keypad3:
            return 3
        case .Four, .Keypad4:
            return 4
        case .Five, .Keypad5:
            return 5
        case .Six, .Keypad6:
            return 6
        case .Seven, .Keypad7:
            return 7
        case .Eight, .Keypad8:
            return 8
        case .Nine, .Keypad9:
            return 9
        default:
            return nil
        }
    }
}
