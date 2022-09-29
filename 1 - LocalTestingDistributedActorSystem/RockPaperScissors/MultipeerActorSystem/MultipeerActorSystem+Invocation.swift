import Foundation
import Distributed

extension MultipeerActorSystem {
    
    struct MessageContainer: Codable, Sendable {
        struct Header: Codable, Sendable {
            var recipientID: MultipeerActorSystem.ActorID
            var targetIdentifier: String
        }
        
        struct Body: Codable, Sendable {
            var genericSubstitutions: [String] = []
            var arguments: [Data] = []
            var errorType: String?
            var returnType: String?
        }
        
        var header: Header
        var body: Body
    }

    struct MultipeerInvocationDecoder: DistributedTargetInvocationDecoder {
        typealias SerializationRequirement = MultipeerActorSystem.SerializationRequirement
        
        let system: MultipeerActorSystem
        var container: MessageContainer
        var nextArgIndex = 0
        
        init(system: MultipeerActorSystem, container: MessageContainer) {
            self.system = system
            self.container = container
        }
        
        mutating func decodeGenericSubstitutions() throws -> [Any.Type] {
            try container.body.genericSubstitutions.map(system.summonType(byName:))
        }
        
        mutating func decodeNextArgument<Value: SerializationRequirement>() throws -> Value {
            let argData = container.body.arguments[nextArgIndex]
            nextArgIndex += 1
            return try system.decoder.decode(Value.self, from: argData)
        }
        
        mutating func decodeErrorType() throws -> Any.Type? {
            try container.body.errorType.map(system.summonType(byName:))
        }
        
        mutating func decodeReturnType() throws -> Any.Type? {
            try container.body.returnType.map(system.summonType(byName:))
        }
    }

    struct MultipeerInvocationEncoder: DistributedTargetInvocationEncoder {
        typealias SerializationRequirement = MultipeerActorSystem.SerializationRequirement
        
        let system: MultipeerActorSystem
        var messageBody: MessageContainer.Body
        
        init(system: MultipeerActorSystem) {
            self.system = system
            self.messageBody = MessageContainer.Body()
        }
        
        mutating func recordGenericSubstitution<T>(_ type: T.Type) throws {
            messageBody.genericSubstitutions.append(String(reflecting: T.self))
        }
        
        mutating func recordErrorType<E>(_ type: E.Type) throws where E : Error {
            messageBody.errorType = String(reflecting: type)
        }
        
        mutating func recordReturnType<R>(_ type: R.Type) throws where R : SerializationRequirement {
            messageBody.returnType = String(reflecting: type)
        }
        
        mutating func recordArgument<Value: SerializationRequirement>(
            _ argument: RemoteCallArgument<Value>
        ) throws {
            let argData = try system.encoder.encode(argument.value)
            messageBody.arguments.append(argData)
        }
        
        func doneRecording() throws {
            // generate MessageContainer.Body if needed -- nothing to do here
        }
    }
    
    final class MultipeerResultHandler: DistributedTargetInvocationResultHandler { // class, not struct, because protocol doesn't declare mutating
        private(set) var result: Result<Data?, any Error>?
        
        func onThrow<Err>(error: Err) async throws where Err : Error {
            result = .failure(error)
        }
        
        typealias SerializationRequirement = MultipeerActorSystem.SerializationRequirement
        
        func onReturn<Success>(value: Success) async throws where Success: SerializationRequirement {
            result = Result { try JSONEncoder().encode(value) }
        }
        
        func onReturnVoid() async throws { // not documented in the SE proposal, needs to be implemented anyway
            result = .success(nil)
        }
    }
    
    func makeInvocationEncoder() -> InvocationEncoder {
        MultipeerInvocationEncoder(system: self)
    }
}
