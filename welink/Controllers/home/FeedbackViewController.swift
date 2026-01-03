//
//  FeedbackViewController.swift
//  welink
//
//  Created by Zahra on 25/12/2025.
//

import UIKit
import Supabase

struct NewRating: Encodable {
    let service_id: String
    let user_id: String
    let stars_count: Int
    let review_content: String
}

class FeedbackViewController: UIViewController {
    
    @IBOutlet weak var starsStackView: UIStackView!
    @IBOutlet weak var reviewTextView: UITextView!
    @IBOutlet weak var submitButton: UIButton!
    
    var serviceId: String!
    var serviceName: String!
    var currentUserId: String!
    weak var delegate: HistoryFeedBackDelegate?
    var selectedStars: Int = 0
    var starButtons: [UIButton] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Navigation bar
        navigationController?.setNavigationBarHidden(false, animated: false)
        self.title = "Feedback"
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = UIColor(hex: "2D493A")
          
        createStarButtons()
        setupUI()
        setupTextView()
    }
    
    func createStarButtons() {
        starsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        starsStackView.axis = .horizontal
        starsStackView.distribution = .fill
        starsStackView.spacing = 8
        starsStackView.alignment = .center
        
        // Create 5 star buttons
        for i in 1...5 {
            let button = UIButton(type: .system)
            button.tag = i
            button.setTitle("☆", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 44)
            button.setTitleColor(UIColor(hex: "2D493A"), for: .normal)
            button.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
            
            button.widthAnchor.constraint(equalToConstant: 50).isActive = true
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true
            
            starButtons.append(button)
            starsStackView.addArrangedSubview(button)
            
            print("Created star button \(i)")
        }
    }
    
    func setupUI() {
        // Style submit button
        submitButton.applyAppStyle()
        submitButton.backgroundColor = UIColor(hex: "2D493A")
        submitButton.setTitleColor(.white, for: .normal)
    }
    
    func setupTextView() {
        reviewTextView.layer.cornerRadius = 12
        reviewTextView.layer.borderWidth = 0
//        reviewTextView.layer.borderColor = UIColor.lightGray.cgColor
        reviewTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        reviewTextView.font = UIFont.systemFont(ofSize: 16)
        
        // Placeholder
        reviewTextView.text = "Share your experience..."
        reviewTextView.textColor = .lightGray
        reviewTextView.delegate = self
    }
    
    @objc func starTapped(_ sender: UIButton) {
        print("⭐ Star \(sender.tag) tapped!")
        
        selectedStars = sender.tag
        updateStarDisplay()
        
        // Add animation
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = .identity
            }
        }
    }
    
    func updateStarDisplay() {
        for (index, button) in starButtons.enumerated() {
            // Fill stars up to the selected number
            if index < selectedStars {
                button.setTitle("★", for: .normal)  // Filled star
            } else {
                button.setTitle("☆", for: .normal)  // Empty star
            }
        }
    }
    
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard selectedStars > 0 else {
            showAlert(title: "Missing Rating", message: "Please select a star rating")
            return
        }
        
        let reviewText = reviewTextView.text == "Share your experience..." || reviewTextView.text.isEmpty ?
            "" : reviewTextView.text ?? ""
        
        submitReview(stars: selectedStars, review: reviewText)
    }
    
    func submitReview(stars: Int, review: String) {
        submitButton.isEnabled = false
        submitButton.alpha = 0.5
        
        Task {
            do {
                let client = SupabaseClientManager.shared.client
                
                // Get current user ID
                let session = try await client.auth.session
                let userId = session.user.id.uuidString
                
                // Create rating
                let newRating = NewRating(
                    service_id: serviceId!,
                    user_id: userId,
                    stars_count: stars,
                    review_content: review
                )
                
                // Insert rating
                try await client.database
                    .from("ratings")
                    .insert(newRating)
                    .execute()
                
                await MainActor.run {
                    // Notify delegate about the new feedback
                    self.delegate?.didSubmitFeedback(
                        serviceId: self.serviceId ?? "",
                        stars: stars,
                        review: review
                    )
                    
                    // Show success
                    let alert = UIAlertController(
                        title: "Thank You!",
                        message: "Your review has been submitted successfully.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                        // Go back
                        self?.navigationController?.popViewController(animated: true)
                    })
                    self.present(alert, animated: true)
                    
                    print("Review submitted: \(stars) stars")
                }
                
            } catch {
                print("Error submitting review: \(error)")
                await MainActor.run {
                    self.submitButton.isEnabled = true
                    self.submitButton.alpha = 1.0
                    self.showAlert(title: "Error", message: "Failed to submit review. Please try again.")
                }
            }
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextViewDelegate
extension FeedbackViewController: UITextViewDelegate {
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "Share your experience..." {
            textView.text = ""
            textView.textColor = .black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Share your experience..."
            textView.textColor = .lightGray
        }
    }
}
