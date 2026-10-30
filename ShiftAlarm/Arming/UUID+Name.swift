import CryptoKit
import Foundation

extension UUID {
    /// A name-based (version 5, RFC 4122) UUID: the same name in the same namespace always gives the same UUID.
    nonisolated init(name: String, namespace: UUID) {
        var bytes = withUnsafeBytes(of: namespace.uuid) { Array($0) }
        bytes.append(contentsOf: Array(name.utf8))
        var hash = Array(Insecure.SHA1.hash(data: bytes).prefix(16))
        hash[6] = (hash[6] & 0x0F) | 0x50
        hash[8] = (hash[8] & 0x3F) | 0x80
        self = hash.withUnsafeBytes { UUID(uuid: $0.load(as: uuid_t.self)) }
    }
}
