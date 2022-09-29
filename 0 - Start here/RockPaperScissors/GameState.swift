import Foundation

enum Shape: CaseIterable {
    case rock
    case paper
    case scissors
}

enum Outcome {
    case win
    case loss
    case draw
}

extension Shape {
    var value: Int {
        switch self {
        case .rock:
            return 0
        case .paper:
            return 1
        case .scissors:
            return 2
        }
    }
}

extension Shape {
    var icon: String {
        switch self {
        case .rock:
            return "🪨"
        case .paper:
            return "📄"
        case .scissors:
            return "✂️"
        }
    }
}

@MainActor
protocol GameState: AnyObject {
    func setPlayers(local: Player, opponent: Player)
    func playerDidPlay(_ move: Shape)
    func opponentDidPlay(_ move: Shape)
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published var playerName = ""
    @Published var opponentName = ""
    
    var playerMove: Shape?
    private var hiddenOpponentMove: Shape?
    
    var opponentMove: Shape? {
        guard playerMove != nil, hiddenOpponentMove != nil else { return nil }
        return hiddenOpponentMove
    }
    
    var outcome: Outcome? {
        guard let playerMove, let opponentMove else { return nil }
        switch (playerMove.value - opponentMove.value + 3) % 3 {
        case 1:
            return .win
        case 2:
            return .loss
        default:
            return .draw
        }
    }
    
    var outcomeText: String {
        switch outcome {
        case nil:
            return "Outcome not known yet"
        case .win:
            return "You win!"
        case .loss:
            return "You lose!"
        case .draw:
            return "It's a draw!"
        }
    }
}

extension GameViewModel: GameState {
    func setPlayers(local: Player, opponent: Player) {
        Task {
            self.playerName = await local.name
            self.opponentName = await opponent.name
        }
    }

    func playerDidPlay(_ move: Shape) {
        playerMove = move
        objectWillChange.send()
    }
    
    func opponentDidPlay(_ move: Shape) {
        hiddenOpponentMove = move
        if playerMove != nil {
            objectWillChange.send()
        }
    }
}
