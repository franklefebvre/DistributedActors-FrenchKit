import Foundation

actor Player {
    private let playerName: String
    private weak var gameState: GameState?
    private weak var opponent: Player?
    
    init(name: String, gameState: GameState?) {
        self.playerName = name
        self.gameState = gameState
    }

    var name: String {
        playerName
    }
    
    func setOpponent(_ opponent: Player) async {
        self.opponent = opponent
        await gameState?.setPlayers(local: self, opponent: opponent)
    }

    // Local API
    func play(move: Shape) async {
        guard let opponent else { return }
        await opponent.opponentDidPlay(move: move)
        await gameState?.playerDidPlay(move)
    }

    // Remote API
    private func opponentDidPlay(move: Shape) async {
        await gameState?.opponentDidPlay(move)
    }
}
