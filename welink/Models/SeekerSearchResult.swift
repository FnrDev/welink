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
    let providerName: String?
    let providerImage: String?
    let startDate: String?
    let endDate: String?
    let categories: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case pricePerHour = "price_per_hour"
        case image
        case userId = "user_id"
        case providerName = "provider_name"
        case providerImage = "provider_image"
        case startDate = "start_date"
        case endDate = "end_date"
        case categories
    }
}

// Helper struct for parsing Supabase response
struct ServiceWithUser: Codable {
    let id: String
    let name: String
    let description: String
    let price_per_hour: Double
    let image: String?
    let user_id: String?
    let start_date: String?    
    let end_date: String?
    let categories: [String]?
    let users: UserInfo?
    
    struct UserInfo: Codable {
        let name: String
        let image: String?
    }
}
