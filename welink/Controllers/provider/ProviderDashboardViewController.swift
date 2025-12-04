import UIKit
import Supabase

struct Service: Decodable {
    let id: Int
    let price_per_hour: Double?
}

struct Booking: Decodable {
    let id: Int
    let service_id: Int
    let created_at: Date?
}

class ProviderDashboardViewController: UIViewController {
    
    @IBOutlet weak var todayBookingsField: UILabel!
    @IBOutlet weak var todayReveune: UILabel!
    @IBOutlet weak var totalBookingField: UILabel!
    @IBOutlet weak var totalReveune: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        todayBookingsField.text = "0"
        todayReveune.text = "0"
        totalBookingField.text = "0"
        totalReveune.text = "0"
        
        Task {
            await loadDashboard()
        }
    }
    
    private func loadDashboard() async {
        let client = SupabaseClientManager.shared.client
        
        do {
            // ====== FETCH ALL SERVICES ======
            let services: [Service] = try await client.database
                .from("services")
                .select("id, price_per_hour")
                .execute()
                .value
            
            // ====== FETCH ALL BOOKINGS ======
            let bookings: [Booking] = try await client.database
                .from("bookings")
                .select("id, service_id, created_at")
                .execute()
                .value
            
            let totalBookings = bookings.count
            
            let totalRevenue = bookings.reduce(0.0) { sum, booking in
                if let service = services.first(where: { $0.id == booking.service_id }) {
                    return sum + (service.price_per_hour ?? 0)
                }
                return sum
            }
            
            let today = Calendar.current.startOfDay(for: Date())
            let todaysBookings = bookings.filter {
                guard let created = $0.created_at else { return false }
                return created >= today
            }
            
            let todaysRevenue = todaysBookings.reduce(0.0) { sum, booking in
                if let service = services.first(where: { $0.id == booking.service_id }) {
                    return sum + (service.price_per_hour ?? 0)
                }
                return sum
            }
            
            await MainActor.run {
                totalBookingField.text = "\(totalBookings)"
                totalReveune.text = formatCurrency(totalRevenue)
                todayBookingsField.text = "\(todaysBookings.count)"
                todayReveune.text = formatCurrency(todaysRevenue)
            }
            
        } catch {
            print("Dashboard load error:", error.localizedDescription)
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "0" }
        return String(format: "%.2f", value)
    }
}
