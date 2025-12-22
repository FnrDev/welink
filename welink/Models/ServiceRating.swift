//
//  ServiceRating.swift
//  welink
//
//  Created by Zahra on 19/12/2025.
//

import Foundation

struct ServiceRating: Codable {
    let id: String
    let serviceId: String
    let userId: String
    let reviewContent: String
    let starsCount: Int
    let createdAt: String?
    
    var userName: String?
    var userImage: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case serviceId = "service_id"
        case userId = "user_id"
        case reviewContent = "review_content"
        case starsCount = "stars_count"
        case createdAt = "created_at"
    }
}

struct RatingWithUser: Codable {
    let id: String
    let service_id: String
    let user_id: String
    let review_content: String
    let stars_count: Int
    let created_at: String?
    let users: UserInfo?
    
    struct UserInfo: Codable {
        let name: String
        let image: String?
    }
}
