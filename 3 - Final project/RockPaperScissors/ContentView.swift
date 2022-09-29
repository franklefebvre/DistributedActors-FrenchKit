import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var service: MultipeerService

    var body: some View {
        if let remotePeer = service.remotePeer {
            let actorSystem = MultipeerActorSystem(service: service, acceptedTypes: [String.self])
            let viewModel = GameViewModel()
            let player = Player(name: service.peerName, gameState: viewModel, actorSystem: actorSystem)
            let opponentID = MultipeerActorSystem.ActorID(peer: remotePeer, type: Player.self)
            let opponent = try? Player.resolve(id: opponentID, using: actorSystem)
            GameView(viewModel: viewModel, player: player)
                .task {
                    if let opponent {
                        do {
                            try await player.setOpponent(opponent)
                        } catch {
                            print("setOpponent failed: \(error.localizedDescription)")
                        }
                    }
                }
        } else {
            ChooserView()
                .environmentObject(service.dataSource)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
