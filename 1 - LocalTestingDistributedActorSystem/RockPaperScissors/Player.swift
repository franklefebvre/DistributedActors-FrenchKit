import Foundation
import Distributed

distributed actor Player {
    typealias ActorSystem = LocalTestingDistributedActorSystem
    
    private let playerName: String
    private weak var gameState: GameState?
    private weak var opponent: Player?
    
    init(name: String, gameState: GameState?, actorSystem: ActorSystem) {
        self.playerName = name
        self.gameState = gameState
        self.actorSystem = actorSystem
    }

    distributed var name: String {
        playerName
    }
    
    distributed func setOpponent(_ opponent: Player) async {
        self.opponent = opponent
        await gameState?.setPlayers(local: self, opponent: opponent)
    }

    // Local API
    distributed func play(move: Shape) async throws {
        guard let opponent else { return }
        try await opponent.opponentDidPlay(move: move)
        await gameState?.playerDidPlay(move)
    }

    // Remote API
    private distributed func opponentDidPlay(move: Shape) async {
        await gameState?.opponentDidPlay(move)
    }
}
