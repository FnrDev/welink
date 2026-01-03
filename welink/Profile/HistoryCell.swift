//
//  HistoryCell.swift
//  welink
//
//  Created by Ali Matar on 01/01/2026.
//

import UIKit

protocol HistoryCellDelegate: AnyObject {
    func didTapFeedbackButton(bookingId: String, serviceId: String, serviceName: String)
    func showToast(message: String)
}

class HistoryCell: UITableViewCell {

    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var feedbackbtn: UIButton!
    @IBOutlet weak var price: UILabel!
    @IBOutlet weak var favouriteBTN: UIButton!
    @IBOutlet weak var historyImage: UIImageView!
    @IBOutlet weak var containerView: UIView!
    
    weak var delegate: HistoryCellDelegate?
    private var bookingId: String = ""
    private var serviceId: String = ""
    private var serviceName: String = ""
    private var providerName: String = ""
    private var currentUserId: String = ""
    private var serviceImageURL: String? = nil
    private var isFavourite: Bool = false
    private var favouriteId: Int64? = nil
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        historyImage.image = nil
        bookingId = ""
        serviceId = ""
        serviceName = ""
        providerName = ""
        serviceImageURL = nil
        isFavourite = false
        favouriteId = nil
        updateFavouriteButtonAppearance()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        // Image styling
        historyImage.layer.cornerRadius = 12
        historyImage.clipsToBounds = true
        historyImage.contentMode = .scaleAspectFill
        
        // Container styling
        containerView?.layer.cornerRadius = 12
        containerView?.clipsToBounds = true
        
        // Cell styling
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        // Favourite button styling
        favouriteBTN.tintColor = .gray
    }
    
    // MARK: - Configure Cell
    
    func configure(with booking: HistoryBookingData, hasFeedback: Bool, userId: String, providerName: String = "") {
        bookingId = booking.id
        serviceId = booking.serviceId
        serviceName = booking.serviceName
        self.providerName = providerName
        self.currentUserId = userId
        self.serviceImageURL = booking.serviceImage
        
        title.text = booking.serviceName
        date.text = "Order date: \(formatDate(booking.createdAt))"
        price.text = "\(Int(booking.price)) BHD"
        
        loadImage(from: booking.serviceImage)
        
        // Update button based on feedback status
        if hasFeedback {
            feedbackbtn.setTitle("View Feedback", for: .normal)
        } else {
            feedbackbtn.setTitle("Give Feedback", for: .normal)
        }
        
        // Check if this service is in favourites
        checkIfFavourite()
    }
    
    // MARK: - Check If Favourite
    
    private func checkIfFavourite() {
        Task {
            do {
                let response: [FavouriteData] = try await SupabaseClientManager.shared.client.database
                    .from("favourite")
                    .select()
                    .eq("user_id", value: currentUserId)
                    .eq("service_name", value: serviceName)
                    .execute()
                    .value
                
                await MainActor.run {
                    if let favourite = response.first {
                        isFavourite = true
                        favouriteId = favourite.id
                    } else {
                        isFavourite = false
                        favouriteId = nil
                    }
                    updateFavouriteButtonAppearance()
                }
            } catch {
                print("Error checking favourite: \(error)")
            }
        }
    }
    
    // MARK: - Update Favourite Button Appearance
    
    private func updateFavouriteButtonAppearance() {
        if isFavourite {
            favouriteBTN.setImage(UIImage(systemName: "heart.fill"), for: .normal)
            favouriteBTN.tintColor = .systemRed
        } else {
            favouriteBTN.setImage(UIImage(systemName: "heart"), for: .normal)
            favouriteBTN.tintColor = .gray
        }
    }
    
    // MARK: - Favourite Button Action
    
    @IBAction func favouriteButtonTapped(_ sender: UIButton) {
        if isFavourite {
            removeFromFavourites()
        } else {
            addToFavourites()
        }
    }
    
    // MARK: - Add to Favourites
    
    private func addToFavourites() {
        Task {
            do {
                let request = CreateFavouriteRequest(
                    service_name: serviceName,
                    provider_name: providerName,
                    rate: nil,
                    user_id: currentUserId,
                    service_image: serviceImageURL
                )
                
                let response: FavouriteData = try await SupabaseClientManager.shared.client.database
                    .from("favourite")
                    .insert(request)
                    .select()
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    isFavourite = true
                    favouriteId = response.id
                    updateFavouriteButtonAppearance()
                    delegate?.showToast(message: "Added to favourites ❤️")
                }
            } catch {
                print("Error adding to favourites: \(error)")
                await MainActor.run {
                    delegate?.showToast(message: "Failed to add to favourites")
                }
            }
        }
    }
    
    // MARK: - Remove from Favourites
    
    private func removeFromFavourites() {
        guard let favouriteId = favouriteId else { return }
        
        Task {
            do {
                try await SupabaseClientManager.shared.client.database
                    .from("favourite")
                    .delete()
                    .eq("id", value: String(favouriteId))
                    .execute()
                
                await MainActor.run {
                    self.isFavourite = false
                    self.favouriteId = nil
                    updateFavouriteButtonAppearance()
                    delegate?.showToast(message: "Removed from favourites")
                }
            } catch {
                print("Error removing from favourites: \(error)")
                await MainActor.run {
                    delegate?.showToast(message: "Failed to remove from favourites")
                }
            }
        }
    }
    
    // MARK: - Format Date
    
    private func formatDate(_ dateString: String) -> String {
        // Try parsing with fractional seconds
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = inputFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy/MM/dd"
            return outputFormatter.string(from: date)
        }
        
        // Try without fractional seconds
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = inputFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy/MM/dd"
            return outputFormatter.string(from: date)
        }
        
        // Try ISO8601
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy/MM/dd"
            return outputFormatter.string(from: date)
        }
        
        // Return first 10 characters (yyyy-MM-dd) as fallback
        if dateString.count >= 10 {
            let index = dateString.index(dateString.startIndex, offsetBy: 10)
            let dateOnly = String(dateString[..<index])
            return dateOnly.replacingOccurrences(of: "-", with: "/")
        }
        
        return dateString
    }
    
    // MARK: - Load Image
    
    private func loadImage(from urlString: String?) {
        guard let urlString = urlString, !urlString.isEmpty, let url = URL(string: urlString) else {
            historyImage.image = UIImage(systemName: "photo")
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        historyImage.image = image
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
                await MainActor.run {
                    historyImage.image = UIImage(systemName: "photo")
                }
            }
        }
    }
    
    // MARK: - Feedback Button Action
    
    @IBAction func feedbackButtonTapped(_ sender: UIButton) {
        delegate?.didTapFeedbackButton(bookingId: bookingId, serviceId: serviceId, serviceName: serviceName)
    }
}

// MARK: - Favourite Data Structs

struct FavouriteData: Decodable {
    let id: Int64
    let created_at: String?
    let service_name: String?
    let provider_name: String?
    let rate: String?
    let user_id: String?
    let service_image: String?
}

struct CreateFavouriteRequest: Encodable {
    let service_name: String
    let provider_name: String
    let rate: String?
    let user_id: String
    let service_image: String?
}
