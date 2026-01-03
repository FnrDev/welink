//
//  HistoryFeedBackController.swift
//  welink
//
//  Created by Ali Matar on 01/01/2026.
//

import UIKit

protocol HistoryFeedBackDelegate: AnyObject {
    func didSubmitFeedback(serviceId: String, stars: Int, review: String)
}

class HistoryFeedBackController: UIViewController {

    @IBOutlet weak var star1: UIButton!
    @IBOutlet weak var star2: UIButton!
    @IBOutlet weak var star3: UIButton!
    @IBOutlet weak var star4: UIButton!
    @IBOutlet weak var star5: UIButton!
    @IBOutlet weak var feedbackTextView: UITextView!
    @IBOutlet weak var submitButton: UIButton!
    
    weak var delegate: HistoryFeedBackDelegate?
    
    var serviceId: String = ""
    var serviceName: String = ""
    var currentUserId: String = ""
    
    private var selectedStars: Int = 0
    private var starButtons: [UIButton] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide the programmatic navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        setupUI()
        setupStars()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        // Style the text view
        feedbackTextView.layer.borderWidth = 1
        feedbackTextView.layer.borderColor = UIColor.lightGray.cgColor
        feedbackTextView.layer.cornerRadius = 8
        
        // Style submit button
        submitButton.layer.cornerRadius = 8
    }
    
    // MARK: - Setup Stars
    
    private func setupStars() {
        starButtons = [star1, star2, star3, star4, star5]
        
        for (index, button) in starButtons.enumerated() {
            button.tag = index + 1
            button.setImage(UIImage(systemName: "star"), for: .normal)
            button.tintColor = .systemYellow
            button.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
        }
    }
    
    // MARK: - Star Tapped
    
    @objc private func starTapped(_ sender: UIButton) {
        selectedStars = sender.tag
        updateStarDisplay()
    }
    
    // MARK: - Update Star Display
    
    private func updateStarDisplay() {
        for (index, button) in starButtons.enumerated() {
            if index < selectedStars {
                button.setImage(UIImage(systemName: "star.fill"), for: .normal)
            } else {
                button.setImage(UIImage(systemName: "star"), for: .normal)
            }
        }
    }
    
    // MARK: - Back Button Action (Connect in Storyboard)
    
    @IBAction func backButtonTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Submit Button Action
    
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard selectedStars > 0 else {
            showAlert(title: "Error", message: "Please select a star rating.")
            return
        }
        
        let review = feedbackTextView.text ?? ""
        submitFeedback(stars: selectedStars, review: review)
    }
    
    // MARK: - Submit Feedback
    
    private func submitFeedback(stars: Int, review: String) {
        Task {
            do {
                let request = CreateRatingRequest(
                    service_id: serviceId,
                    user_id: currentUserId,
                    review_content: review,
                    stars_count: stars
                )
                
                let _: RatingData = try await SupabaseClientManager.shared.client.database
                    .from("ratings")
                    .insert(request)
                    .select()
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    delegate?.didSubmitFeedback(serviceId: serviceId, stars: stars, review: review)
                    showSuccessAndDismiss()
                }
                
            } catch {
                print("Error submitting feedback: \(error)")
                await MainActor.run {
                    showAlert(title: "Error", message: "Failed to submit feedback. Please try again.")
                }
            }
        }
    }
    
    // MARK: - Show Success and Dismiss
    
    private func showSuccessAndDismiss() {
        let alert = UIAlertController(title: "Thank You!", message: "Your feedback has been submitted.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
    
    // MARK: - Show Alert
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
