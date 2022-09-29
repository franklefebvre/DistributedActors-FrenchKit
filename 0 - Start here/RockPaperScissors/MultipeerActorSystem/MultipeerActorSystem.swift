import Foundation
import Distributed
import MultipeerKit

final class MultipeerActorSystem: DistributedActorSystem {
    
    typealias SerializationRequirement = Codable
    typealias ActorID = MultipeerActorID
    typealias InvocationDecoder = MultipeerInvocationDecoder
    typealias InvocationEncoder = MultipeerInvocationEncoder
    typealias ResultHandler = MultipeerResultHandler

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    
    let registry = ActorRegistry()
    
    let service: MultipeerService
    let registeredTypes: [String: Any.Type]
    
    init(service: MultipeerService, acceptedTypes: [Any.Type]) {
        self.service = service
        self.registeredTypes = acceptedTypes.reduce(into: [:]) { partialResult, type in
            partialResult[String(reflecting: type)] = type
        }
        service.receiveCallback = handleReceivedMessage
    }
}

extension MultipeerActorSystem {
    enum RemoteCallError: Error {
        case missingResult
    }

    func remoteCall<Actor, Failure, Success>(
        on actor: Actor,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder, // inout not in SE proposal
        throwing: Failure.Type,
        returning: Success.Type
    ) async throws -> Success
        where Actor: DistributedActor,
              Actor.ID == ActorID,
              Failure: Error,
              Success: SerializationRequirement {
                  let messageHeader = MessageContainer.Header(recipientID: actor.id, targetIdentifier: target.identifier)
                  let container = MessageContainer(header: messageHeader, body: invocation.messageBody)
                  let encodedContainer = try self.encoder.encode(container)
                  guard let encodedResponse = try await service.send(encodedContainer, to: actor.id.encodedPeerID) else {
                      throw RemoteCallError.missingResult
                  }
                  return try self.decoder.decode(Success.self, from: encodedResponse)
    }

    func remoteCallVoid<Actor, Failure>(
        on actor: Actor,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder, // inout not in SE proposal
        throwing: Failure.Type
    ) async throws
        where Actor: DistributedActor,
              Actor.ID == ActorID,
              Failure: Error {
                  let messageHeader = MessageContainer.Header(recipientID: actor.id, targetIdentifier: target.identifier)
                  let container = MessageContainer(header: messageHeader, body: invocation.messageBody)
                  let encodedContainer = try self.encoder.encode(container)
                  _ = try await service.send(encodedContainer, to: actor.id.encodedPeerID)
    }
}

extension MultipeerActorSystem {
    enum MessageHandlerError: Error {
        case recipientNotFound
        case missingResult
    }

    func handleReceivedMessage(_ data: Data) async throws -> Data? {
        // Called by the transport layer when a message is received.
        // data is the JSON-encoded message container sent through the Multipeer connection.
        
        // 1 - decode it into a MessageContainer instance
        
        // 2 - resolve the recipient (a distributed actor instance) from the recipientID contained in the message header
        
        // 3 - create a RemoteCallTarget using the target identifier from the message header
        
        // 4 - instantiate an InvocationDecoder and a ResultHandler
        
        // 5 - call the target method on the recipient (use executeDistributedTarget)
        
        // 6 - retrieve and return the encoded results (see MultipeerResultHandler implementation)
        
        return nil // this line is here to keep the compiler happy, must be removed when this methos is implemented
    }
}
