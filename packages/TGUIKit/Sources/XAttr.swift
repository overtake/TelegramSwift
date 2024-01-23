
import Foundation

public struct XAttr {

    public struct Error: Swift.Error {
        public let localizedDescription = String(utf8String: strerror(errno))
    }

    public static func set(named name: String, data: Data, atPath path: String) throws {
        if setxattr(path, name, (data as NSData).bytes, data.count, 0, 0) == -1 {
            throw Error()
        }
    }

    public static func remove(named name: String, atPath path: String) throws {
        if removexattr(path, name, 0) == -1 {
            throw Error()
        }
    }

    public static func get(named name: String, atPath path: String) throws -> Data {
        let bufLength = getxattr(path, name, nil, 0, 0, 0)

        guard bufLength != -1, let buf = malloc(bufLength), getxattr(path, name, buf, bufLength, 0, 0) != -1 else {
            throw Error()
        }
        return Data(bytes: buf, count: bufLength)
    }

}
