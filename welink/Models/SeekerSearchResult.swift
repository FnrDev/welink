//
//  SeekerSearchResult.swift
//  welink
//
//  Created by Zahra on 15/12/2025.
//

import Foundation
struct SeekerSearchResult: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let pricePerHour: Double
    let image: String?
    let userId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case pricePerHour = "price_per_hour"
        case image
        case userId = "user_id"
    }
}
