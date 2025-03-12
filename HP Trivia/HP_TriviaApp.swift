//
//  HP_TriviaApp.swift
//  HP Trivia
//
//  Created by Alberto Aragón Peci on 25/10/24.
//

import SwiftUI

@main
struct HP_TriviaApp: App {
    @StateObject private var store = Store()
    @StateObject private var game = Game()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(game)
                .task {
                    await store.loadProducts()
                    game.loadScores()
                    store.loadStatus()
                }
        }
    }
}
