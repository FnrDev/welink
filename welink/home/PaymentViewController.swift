//
//  PaymentViewController.swift
//  welink
//
//  Created by Zahra on 22/12/2025.
//

import UIKit

class PaymentViewController: UIViewController {
    
    
    @IBOutlet weak var creditCardButton: UIButton!
    @IBOutlet weak var applePayButton: UIButton!
    @IBOutlet weak var cardHolderNameField: UITextField!
    @IBOutlet weak var cardNumberField: UITextField!
    @IBOutlet weak var cvvField: UITextField!
    @IBOutlet weak var expiryDateField: UITextField!
    @IBOutlet weak var totalAmountLabel: UILabel!
    @IBOutlet weak var payButton: UIButton!
    
    // MARK: - Properties
       var servicePrice: Double = 0.0
       var serviceName: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Payment Details"
                view.backgroundColor = .white
                
                print("✅ Payment screen loaded")
        updateTotalAmount()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
    }
    
    func updateTotalAmount() {
        totalAmountLabel.text = String(format: "%.0f BD", servicePrice)
    }

}
