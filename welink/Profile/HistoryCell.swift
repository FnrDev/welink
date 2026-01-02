//
//  HistoryCell.swift
//  welink
//
//  Created by Ali Matar on 01/01/2026.
//

import UIKit

protocol HistoryCellDelegate: AnyObject {
    func didTapFeedbackButton(bookingId: String, serviceId: String, serviceName: String)
}

class HistoryCell: UITableViewCell {

    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var feedbackbtn: UIButton!
    @IBOutlet weak var price: UILabel!
    @IBOutlet weak var historyImage: UIImageView!
    @IBOutlet weak var containerView: UIView!
    
    weak var delegate: HistoryCellDelegate?
    private var bookingId: String = ""
    private var serviceId: String = ""
    private var serviceName: String = ""
    
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
    }
    
    // MARK: - Configure Cell
    
    func configure(with booking: HistoryBookingData, hasFeedback: Bool) {
        bookingId = booking.id
        serviceId = booking.serviceId
        serviceName = booking.serviceName
        
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
