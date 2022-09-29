import SwiftUI
import MultipeerKit

struct ChooserView: View {
    @EnvironmentObject private var dataSource: MultipeerDataSource
    @State private var showActivityIndicator = false
    
    var body: some View {
        VStack {
            if showActivityIndicator {
                Text("Please wait")
            } else {
                Text("Choose an opponent")
            }
            List {
                ForEach(dataSource.availablePeers) { peer in
                    Text(peer.name)
                        .onTapGesture {
                            showActivityIndicator = true
                            dataSource.transceiver.invite(peer, with: nil, timeout: 10) { result in
                                showActivityIndicator = false
                                switch result {
                                case .success(let peer):
                                    print("connected to \(peer.name)")
                                case .failure(let error):
                                    print(error.localizedDescription)
                                }
                            }
                        }
                    
                }
            }
        }
    }
}
