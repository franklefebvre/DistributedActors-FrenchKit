import Foundation
import Distributed
import MultipeerKit

extension MultipeerActorSystem {
    
    struct MultipeerActorID: Codable, Equatable, Hashable {
        var encodedPeerID: String
        var actorType: String
        
        init(peerID: String, type: Any.Type) {
            self.encodedPeerID = peerID
            self.actorType = String(reflecting: type)
        }
        
        init(peer: Peer, type: Any.Type) {
            self.init(peerID: peer.id, type: type)
        }
    }
    
    final class ActorRegistry: @unchecked Sendable {
        struct WeakRef {
            weak var pointee: (any DistributedActor)?
        }
        
        private let lock = NSLock()
        private var registry: [ActorID: WeakRef] = [:]
        
        func get(_ id: ActorID) -> (any DistributedActor)? {
            lock.withLock {
                registry[id]?.pointee
            }
        }
        
        func add<Act>(_ actor: Act) where Act: DistributedActor, ActorID == Act.ID {
            lock.withLock {
                registry[actor.id] = WeakRef(pointee: actor)
            }
        }
        
        func remove(_ id: ActorID) {
            lock.withLock {
                registry[id] = nil
            }
        }
    }

    func resolve<Act>(id: ActorID, as actorType: Act.Type) throws -> Act? where Act : DistributedActor, ActorID == Act.ID {
        return registry.get(id) as? Act
    }
    
    func resolve(id: ActorID) throws -> (any DistributedActor)? {
        return registry.get(id)
    }
    
    func assignID<Act>(_ actorType: Act.Type) -> ActorID where Act : DistributedActor, ActorID == Act.ID {
        ActorID(peerID: service.dataSource.transceiver.localPeerId ?? "", type: actorType)
    }
    
    func actorReady<Act>(_ actor: Act) where Act : DistributedActor, ActorID == Act.ID {
        registry.add(actor)
    }
    
    func resignID(_ id: ActorID) {
        registry.remove(id)
    }
}

extension MultipeerActorSystem {
    enum InvocationDecodingError: Error {
        case invalidType
    }
    
    func summonType(byName name: String) throws -> Any.Type {
        guard let type = registeredTypes[name] else { throw InvocationDecodingError.invalidType }
        return type
    }
}
