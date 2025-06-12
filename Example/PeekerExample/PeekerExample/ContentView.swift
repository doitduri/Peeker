//
//  ContentView.swift
//  PeekerExample
//
//  Created by duri on 5/22/25.
//

import SwiftUI
import Peeker

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Peeker Demo")
                .font(.title)

            Button("Start Peeking") {
                Peeker.shared.start()
            }

            Button("Stop Peeking") {
                Peeker.shared.stop()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
