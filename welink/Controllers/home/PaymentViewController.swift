//
//  PaymentViewController.swift
//  welink
//
//  Created by Zahra on 22/12/2025.
//

import UIKit

class PaymentViewController: UIViewController, UITextFieldDelegate {
    
    
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
        setupTextFieldDelegates()
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
        
        // Set keyboard types
        cardNumberField.keyboardType = .numberPad
        cvvField.keyboardType = .numberPad
        cardHolderNameField.keyboardType = .default
        expiryDateField.keyboardType = .numberPad
        
        updatePaymentMethodButtons()
    }
    
    func setupTextFieldDelegates() {
        cardHolderNameField.delegate = self
        cardNumberField.delegate = self
        cvvField.delegate = self
        expiryDateField.delegate = self
    }
    
    // MARK: - UITextFieldDelegate
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        // Card Holder Name: Only letters and spaces
        if textField == cardHolderNameField {
            let allowedCharacters = CharacterSet.letters.union(.whitespaces)
            let characterSet = CharacterSet(charactersIn: string)
            return allowedCharacters.isSuperset(of: characterSet)
        }
        
        // Card Number: Only numbers, max 16 digits, auto-format with spaces
        if textField == cardNumberField {
            // Remove spaces for counting
            let digitsOnly = updatedText.replacingOccurrences(of: " ", with: "")
            
            // Only allow numbers
            let allowedCharacters = CharacterSet.decimalDigits
            let characterSet = CharacterSet(charactersIn: string)
            if !allowedCharacters.isSuperset(of: characterSet) {
                return false
            }
            
            // Max 16 digits
            if digitsOnly.count > 16 {
                return false
            }
            
            // Auto-format: Add space every 4 digits
            if digitsOnly.count > 0 {
                let formatted = formatCardNumber(digitsOnly)
                textField.text = formatted
                return false
            }
            
            return true
        }
        
        // CVV: Only numbers, max 3 digits
        if textField == cvvField {
            // Only allow numbers
            let allowedCharacters = CharacterSet.decimalDigits
            let characterSet = CharacterSet(charactersIn: string)
            if !allowedCharacters.isSuperset(of: characterSet) {
                return false
            }
            
            // Max 3 digits
            return updatedText.count <= 3
        }
        
        // Expiry Date: Only numbers, auto-format as MM/YY
        if textField == expiryDateField {
            // Remove slash for counting
            let digitsOnly = updatedText.replacingOccurrences(of: "/", with: "")
            
            // Only allow numbers
            let allowedCharacters = CharacterSet.decimalDigits
            let characterSet = CharacterSet(charactersIn: string)
            if !allowedCharacters.isSuperset(of: characterSet) {
                return false
            }
            
            // Max 4 digits (MMYY)
            if digitsOnly.count > 4 {
                return false
            }
            
            // Auto-format: Add slash after MM
            if digitsOnly.count >= 2 {
                let month = String(digitsOnly.prefix(2))
                let year = digitsOnly.count > 2 ? String(digitsOnly.suffix(from: digitsOnly.index(digitsOnly.startIndex, offsetBy: 2))) : ""
                textField.text = year.isEmpty ? month : "\(month)/\(year)"
                return false
            }
            
            return true
        }
        
        return true
    }
    
    // Format card number as: 1234 5678 9012 3456
    func formatCardNumber(_ number: String) -> String {
        var formatted = ""
        for (index, character) in number.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted.append(character)
        }
        return formatted
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
        
        // Check card number has 16 digits
        let digitsOnly = cardNumber.replacingOccurrences(of: " ", with: "")
        guard digitsOnly.count == 16 else {
            showAlert(message: "Card number must be 16 digits")
            return
        }
        
        guard let cvv = cvvField.text, !cvv.isEmpty else {
            showAlert(message: "Please enter CVV")
            return
        }
        
        guard cvv.count == 3 else {
            showAlert(message: "CVV must be 3 digits")
            return
        }
        
        guard let expiry = expiryDateField.text, !expiry.isEmpty else {
            showAlert(message: "Please enter expiry date")
            return
        }
        
        // Validate expiry format MM/YY
        let expiryDigits = expiry.replacingOccurrences(of: "/", with: "")
        guard expiryDigits.count == 4 else {
            showAlert(message: "Expiry date must be in MM/YY format")
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
        let alert = UIAlertController(title: "Invalid Input", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

}
