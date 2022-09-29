import SwiftUI

struct TwoPlayersView: View {
    @ObservedObject var localVM: GameViewModel
    @ObservedObject var opponentVM: GameViewModel
    let me: Player
    let opponent: Player
    
    var body: some View {
        HStack {
            Spacer()
            GameView(viewModel: localVM, player: me)
            Spacer()
            GameView(viewModel: opponentVM, player: opponent)
            Spacer()
        }.task {
            await me.setOpponent(opponent)
            await opponent.setOpponent(me)
        }
    }
}

struct TwoPlayersView_Previews: PreviewProvider {
    static var localVM = GameViewModel()
    static var opponentVM = GameViewModel()
    static var me = Player(name: "P1", gameState: localVM)
    static var opponent = Player(name: "P2", gameState: opponentVM)
    
    static var previews: some View {
        TwoPlayersView(localVM: localVM, opponentVM: opponentVM, me: me, opponent: opponent)
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
