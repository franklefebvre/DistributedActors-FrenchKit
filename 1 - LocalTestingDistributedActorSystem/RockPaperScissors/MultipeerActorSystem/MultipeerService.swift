import Foundation
import MultipeerKit
import MultipeerConnectivity

final class MultipeerService: ObservableObject, @unchecked Sendable {
    private var connectedPeers: [String: Peer] = [:]
    private let peerLock = NSLock()
    
    private var responseContinuations: [String: CheckedContinuation<Data?, Error>] = [:]
    private let continuationLock = NSLock()

    var receiveCallback: ((Data) async throws -> Data?)?
    
    var peerName: String {
        MultipeerConfiguration.default.peerName
    }

    var remotePeer: Peer? {
        peerLock.withLock {
            connectedPeers.first?.value
        }
    }
    
    func send(_ payload: Data, to peer: String) async throws -> Data? {
        guard let remotePeer = peerLock.withLock({ connectedPeers[peer] }) else {
            throw NSError()
        }
        let uuid = UUID().uuidString
        let message = RequestMessage(requestID: uuid, payload: payload)
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else { return }
            self.continuationLock.withLock {
                self.responseContinuations[uuid] = continuation
            }
            transceiver.send(message, to: [remotePeer]) // FIXME: don't ignore send errors, resume continuation with throwing arg instead
        }
    }

    struct RequestMessage: Codable {
        var requestID: String
        var payload: Data
    }
    
    struct ResponseMessage: Codable {
        var requestID: String
        var payload: Data?
    }
    
    private lazy var transceiver: MultipeerTransceiver = {
        var config = MultipeerConfiguration.default
        config.serviceType = "fk-dist-actors"
        config.invitation = .none
        config.security.encryptionPreference = .none
        config.security.invitationHandler = { [weak self] _, _, handler in
            handler(self?.connectedPeers.isEmpty ?? false)
        }

        var t = MultipeerTransceiver(configuration: config)
        t.peerConnected = { [weak self] peer in
            guard let self else { return }
            self.peerLock.withLock {
                self.connectedPeers[peer.id] = peer
            }
            self.objectWillChange.send()
        }
        t.peerDisconnected = { [weak self] peer in
            guard let self else { return }
            self.peerLock.withLock {
                self.connectedPeers[peer.id] = nil
            }
            self.objectWillChange.send()
        }

        t.receive(RequestMessage.self) { [weak self] message, peer in
            guard let self else { return }
            guard let receiveCallback = self.receiveCallback else { fatalError("MultipeerService.receiveCallback not set") }
            Task {
                do {
                    let payload = try await receiveCallback(message.payload)
                    let response = ResponseMessage(requestID: message.requestID, payload: payload)
                    self.transceiver.send(response, to: [peer])
                } catch {
                    print("error in receiveCallback: \(error.localizedDescription)")
                }
            }
        }

        t.receive(ResponseMessage.self) { [weak self] message, peer in
            guard let self else { return }
            let responseContinuation = self.continuationLock.withLock {
                self.responseContinuations[message.requestID]
            }
            guard let responseContinuation else { return }
            responseContinuation.resume(returning: message.payload)
            self.continuationLock.withLock {
                self.responseContinuations[message.requestID] = nil
            }
                
        }

        t.resume()
        return t
    }()

    lazy var dataSource: MultipeerDataSource = {
        MultipeerDataSource(transceiver: transceiver)
    }()
}
