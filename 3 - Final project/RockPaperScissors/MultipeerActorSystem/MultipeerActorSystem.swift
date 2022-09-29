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
        let container: MessageContainer = try decoder.decode(MessageContainer.self, from: data)

        guard let recipient = try resolve(id: container.header.recipientID) else {
            throw MessageHandlerError.recipientNotFound
        }
        
        var invocationDecoder = InvocationDecoder(system: self, container: container) // must be var because inout (not in SE proposal)
        let target = RemoteCallTarget(container.header.targetIdentifier)
        
        let resultHandler = ResultHandler()
        try await executeDistributedTarget(on: recipient, target: target, invocationDecoder: &invocationDecoder, handler: resultHandler)
        guard let result = resultHandler.result else {
            throw MessageHandlerError.missingResult
        }
        
        return try result.get()
    }
}
