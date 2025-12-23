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
    @IBOutlet weak var cardHolderNameLabel: UILabel!
    @IBOutlet weak var cardHolderNameField: UITextField!
    @IBOutlet weak var cardNumberLabel: UILabel!
    @IBOutlet weak var cardNumberField: UITextField!
    @IBOutlet weak var cvvLabel: UILabel!
    @IBOutlet weak var cvvField: UITextField!
    @IBOutlet weak var expiryDateLabel: UILabel!
    @IBOutlet weak var expiryDateField: UITextField!
    @IBOutlet weak var totalAmountLabel: UILabel!
    @IBOutlet weak var payButton: UIButton!
    
    // MARK: - Properties
    var servicePrice: Double = 0.0
    var serviceName: String = ""
    
    private var selectedPaymentMethod: PaymentMethod = .creditCard
    
    enum PaymentMethod {
        case creditCard
        case applePay
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Payment Details"
                
        print("✅ Payment screen loaded")
        updateTotalAmount()
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
        creditCardButton.layer.cornerRadius = 12
        applePayButton.layer.cornerRadius = 12
        payButton.layer.cornerRadius = 12
        
        cvvField.isSecureTextEntry = true
        
        updatePaymentMethodButtons()
    }
    
    func updateTotalAmount() {
        totalAmountLabel.text = String(format: "%.0f BD", servicePrice)
    }
    
    func updatePaymentMethodButtons() {
        // Create configurations
        var creditConfig = UIButton.Configuration.filled()
        var appleConfig = UIButton.Configuration.filled()
        
        if selectedPaymentMethod == .creditCard {
            // Credit Card selected
            creditConfig.baseBackgroundColor = UIColor(hex: "2D493A")
            creditConfig.baseForegroundColor = .white
            creditConfig.title = "Credit/Debit Card"
            creditCardButton.configuration = creditConfig
            
            // Apple Pay unselected
            appleConfig.baseBackgroundColor = UIColor(hex: "E8E8E8")
            appleConfig.baseForegroundColor = .black
            appleConfig.title = "Apple Pay"
            applePayButton.configuration = appleConfig
            
            // Show form fields
            cardHolderNameLabel.isHidden = false
            cardHolderNameField.isHidden = false
            cardNumberLabel.isHidden = false
            cardNumberField.isHidden = false
            cvvLabel.isHidden = false
            cvvField.isHidden = false
            expiryDateLabel.isHidden = false
            expiryDateField.isHidden = false
            
        } else {
            // Apple Pay selected
            appleConfig.baseBackgroundColor = UIColor(hex: "2D493A")
            appleConfig.baseForegroundColor = .white
            appleConfig.title = "Apple Pay"
            applePayButton.configuration = appleConfig
            
            // Credit Card unselected
            creditConfig.baseBackgroundColor = UIColor(hex: "E8E8E8")
            creditConfig.baseForegroundColor = .black
            creditConfig.title = "Credit/Debit Card"
            creditCardButton.configuration = creditConfig
            
            // Hide form fields
            cardHolderNameLabel.isHidden = true
            cardHolderNameField.isHidden = true
            cardNumberLabel.isHidden = true
            cardNumberField.isHidden = true
            cvvLabel.isHidden = true
            cvvField.isHidden = true
            expiryDateLabel.isHidden = true
            expiryDateField.isHidden = true
        }
    }
    
    // MARK: - Actions
        @IBAction func creditCardButtonTapped(_ sender: UIButton) {
            selectedPaymentMethod = .creditCard
            updatePaymentMethodButtons()
            print("Credit Card selected")
        }
        
        @IBAction func applePayButtonTapped(_ sender: UIButton) {
            selectedPaymentMethod = .applePay
            updatePaymentMethodButtons()
            print("Apple Pay selected")
        }
        
        @IBAction func payButtonTapped(_ sender: UIButton) {
            print("Pay button tapped")
                
                // If Apple Pay is selected, skip validation
                if selectedPaymentMethod == .applePay {
                    processPayment()
                    return
                }
                
                // Validate form fields - For Credit Card
                guard let cardHolder = cardHolderNameField.text, !cardHolder.isEmpty else {
                    showAlert(message: "Please enter card holder name")
                    return
                }
                
                guard let cardNumber = cardNumberField.text, !cardNumber.isEmpty else {
                    showAlert(message: "Please enter card number")
                    return
                }
                
                guard let cvv = cvvField.text, !cvv.isEmpty else {
                    showAlert(message: "Please enter CVV")
                    return
                }
                
                guard let expiry = expiryDateField.text, !expiry.isEmpty else {
                    showAlert(message: "Please enter expiry date")
                    return
                }
                
                processPayment()
        }
        
        func processPayment() {
            // Navigate to success screen
            let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
            guard let successVC = storyboard.instantiateViewController(withIdentifier: "PaymentSuccessVC") as? PaymentSuccessViewController else {
                print("Could not load success screen")
                return
            }
            
            successVC.serviceName = serviceName
            successVC.amountPaid = servicePrice
            
            navigationController?.pushViewController(successVC, animated: true)
        }
        
        func showAlert(message: String) {
            let alert = UIAlertController(title: "Missing Information", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }

}
