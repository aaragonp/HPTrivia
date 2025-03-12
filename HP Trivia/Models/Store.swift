//
//  Store.swift
//  HP Trivia
//
//  Created by Alberto Aragón Peci on 3/11/24.
//

import Foundation
import StoreKit

enum BookStatus: Codable {
    case active, inactive, locked
}

@MainActor
class Store: ObservableObject {
    @Published var books: [BookStatus] = [
        .active, .active, .inactive, .locked, .locked, .locked, .locked
    ]
    @Published var products: [Product] = []
    @Published var purchaseIDs = Set<String>()

    private var productIDs = ["hp4", "hp5", "hp6", "hp7"]
    private var updates: Task<Void, Never>? = nil
    private let savePath = FileManager.documentsDirectory.appending(path: "SavedBookStatus")

    init() {
        updates = watchForUpdates()
    }
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Couldn't fetch thos products")
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):      // Purchase successful, but now we have to verify receipt
                switch verificationResult {
                case .unverified(let signedType, let verificationError):
                    print("Error on \(signedType): \(verificationError)")
                case .verified(let signedType):
                    purchaseIDs.insert(signedType.productID)
                }

            case .pending:              // Waiting for approval
                break

            case .userCancelled:        // User cancelled or parent disapproved child's purchase request
                break
            @unknown default:
                break
            }
        } catch {
            print("Couldn't purchase that product: \(error)")
        }
    }

    func saveStatus() {
        do {
            let data = try JSONEncoder().encode(books)
            try data.write(to: savePath)
        } catch {
            print("Unable to save data.")
        }
    }

    func loadStatus() {
        do {
            let data = try Data(contentsOf: savePath)
            books = try JSONDecoder().decode([BookStatus].self, from: data)
        } catch {
            print("Couldn't load book statuses")
        }
    }

    private func checkPurchased() async {
        for product in products {
            guard let state = await product.currentEntitlement else { return }

            switch state {
            case .unverified(let signedType, let verificationError):
                print("Error on \(signedType): \(verificationError)")
            case .verified(let signedType):
                if signedType.revocationReason == nil {
                    purchaseIDs.insert(signedType.productID)
                } else {
                    purchaseIDs.remove(signedType.productID)
                }
            }
        }
    }

    private func watchForUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await _ in Transaction.updates {
                await checkPurchased()
            }
        }
    }
}
