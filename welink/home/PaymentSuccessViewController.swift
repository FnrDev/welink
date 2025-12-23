//
//  PaymentSuccessViewController.swift
//  welink
//
//  Created by Zahra on 23/12/2025.
//

import UIKit

class PaymentSuccessViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var successImageView: UIImageView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var backToHomeButton: UIButton!
    
    // MARK: - Properties
    var serviceName: String = ""
    var amountPaid: Double = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Payment Details"
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
    }
    
    func setupUI() {
        // Style button
        backToHomeButton.layer.cornerRadius = 12
        backToHomeButton.backgroundColor = UIColor(hex: "2D493A")
        backToHomeButton.setTitleColor(.white, for: .normal)
    
        messageLabel.text = "Your payment was completed successfully"
        
        // Set the success character image
        successImageView.image = UIImage(named: "character")
        successImageView.contentMode = .scaleAspectFit
        
        print("Payment success screen loaded")
        print("Service: \(serviceName)")
        print("Amount: \(amountPaid) BD")
    }
    
    // MARK: - Actions
    @IBAction func backToHomeButtonTapped(_ sender: UIButton) {
            // Get the tab bar controller
            guard let tabBarController = self.tabBarController else {
                print("❌ No tab bar controller found")
                return
            }
            
            // Switch to Home tab (index 0)
            tabBarController.selectedIndex = 0
            self.navigationController?.popToRootViewController(animated: false)
    }
    
}
