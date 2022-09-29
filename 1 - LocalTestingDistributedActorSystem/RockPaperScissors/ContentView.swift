import SwiftUI

struct ContentView: View {
    @StateObject var localVM = GameViewModel()
    @StateObject var opponentVM = GameViewModel()
    @State private var me: Player?
    @State private var opponent: Player?

    var body: some View {
        if let me, let opponent {
            TwoPlayersView(localVM: localVM, opponentVM: opponentVM, me: me, opponent: opponent)
        } else {
            Text("initializing")
                .task {
                    let actorSystem = Player.ActorSystem()
                    let me = Player(name: "player 1", gameState: localVM, actorSystem: actorSystem)
                    let opponent = Player(name: "player 2", gameState: opponentVM, actorSystem: actorSystem)
                    try? await me.setOpponent(opponent)
                    try? await opponent.setOpponent(me)
                    self.me = me
                    self.opponent = opponent
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
