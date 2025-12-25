//
//  welink
//
//  Created by Zahra on 24/12/2025.
//

import Foundation

struct CreateBookingRequest: Encodable {
    let service_id: String
    let user_id: String
    let status: String
    let booked_date: String
}

struct BookingRequest: Encodable {
    let service_id: String
    let user_id: String
    let status: String
    let booked_date: String
}
