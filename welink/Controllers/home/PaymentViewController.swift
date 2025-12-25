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
    var serviceId: String = ""
    var selectedDate: String = ""
    var selectedTime: String = ""
    
    private var selectedPaymentMethod: PaymentMethod = .creditCard
    
    enum PaymentMethod {
        case creditCard
        case applePay
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Payment Details"
        
        creditCardButton.applyAppStyle()
        applePayButton.applyAppStyle()
        payButton.applyAppStyle()
                
        print("✅ Payment screen loaded")
        print("Service ID: \(serviceId)")
        print("Selected Date: \(selectedDate)")
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
        
        if textField == cardHolderNameField {
            let allowedCharacters = CharacterSet.letters.union(.whitespaces)
            let characterSet = CharacterSet(charactersIn: string)
            return allowedCharacters.isSuperset(of: characterSet)
        }
        
        if textField == cardNumberField {
            let digitsOnly = updatedText.replacingOccurrences(of: " ", with: "")
            let allowedCharacters = CharacterSet.decimalDigits
            let characterSet = CharacterSet(charactersIn: string)
            if !allowedCharacters.isSuperset(of: characterSet) {
                return false
            }
            if digitsOnly.count > 16 {
                return false
            }
            if digitsOnly.count > 0 {
                let formatted = formatCardNumber(digitsOnly)
                textField.text = formatted
                return false
            }
            return true
        }
        
        if textField == cvvField {
            let allowedCharacters = CharacterSet.decimalDigits
            let characterSet = CharacterSet(charactersIn: string)
            if !allowedCharacters.isSuperset(of: characterSet) {
                return false
            }
            return updatedText.count <= 3
        }
        
        if textField == expiryDateField {
            let digitsOnly = updatedText.replacingOccurrences(of: "/", with: "")
            let allowedCharacters = CharacterSet.decimalDigits
            let characterSet = CharacterSet(charactersIn: string)
            if !allowedCharacters.isSuperset(of: characterSet) {
                return false
            }
            if digitsOnly.count > 4 {
                return false
            }
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
        var creditConfig = UIButton.Configuration.filled()
        var appleConfig = UIButton.Configuration.filled()
        
        if selectedPaymentMethod == .creditCard {
            creditConfig.baseBackgroundColor = UIColor(hex: "2D493A")
            creditConfig.baseForegroundColor = .white
            creditConfig.title = "Credit/Debit Card"
            creditCardButton.configuration = creditConfig
            
            appleConfig.baseBackgroundColor = UIColor(hex: "E8E8E8")
            appleConfig.baseForegroundColor = .black
            appleConfig.title = "Apple Pay"
            applePayButton.configuration = appleConfig
            
            cardHolderNameLabel.isHidden = false
            cardHolderNameField.isHidden = false
            cardNumberLabel.isHidden = false
            cardNumberField.isHidden = false
            cvvLabel.isHidden = false
            cvvField.isHidden = false
            expiryDateLabel.isHidden = false
            expiryDateField.isHidden = false
            
        } else {
            appleConfig.baseBackgroundColor = UIColor(hex: "2D493A")
            appleConfig.baseForegroundColor = .white
            appleConfig.title = "Apple Pay"
            applePayButton.configuration = appleConfig
            
            creditConfig.baseBackgroundColor = UIColor(hex: "E8E8E8")
            creditConfig.baseForegroundColor = .black
            creditConfig.title = "Credit/Debit Card"
            creditCardButton.configuration = creditConfig
            
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

        // Validate date and time selection
        if selectedDate.isEmpty || selectedDate == "Available" || selectedDate.contains(" - ") {
            showAlert(message: "Please select a booking date")
            return
        }

        if selectedTime.isEmpty || selectedTime == "Select time" {
            showAlert(message: "Please select a booking time")
            return
        }

        if selectedPaymentMethod == .applePay {
            processPayment()
            return
        }
        
        guard let cardHolder = cardHolderNameField.text, !cardHolder.isEmpty else {
            showAlert(message: "Please enter card holder name")
            return
        }
        
        guard let cardNumber = cardNumberField.text, !cardNumber.isEmpty else {
            showAlert(message: "Please enter card number")
            return
        }
        
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
        
        let expiryDigits = expiry.replacingOccurrences(of: "/", with: "")
        guard expiryDigits.count == 4 else {
            showAlert(message: "Expiry date must be in MM/YY format")
            return
        }
        
        processPayment()
    }
    
    func processPayment() {
        // Show loading indicator
        payButton.isEnabled = false
        payButton.setTitle("Processing...", for: .normal)
        
        // Save booking to database
        Task {
            await saveBookingToDatabase()
        }
    }
    
    func saveBookingToDatabase() async {
        do {
            // Get current user ID
            let session = try await SupabaseClientManager.shared.client.auth.session
            let userId = session.user.id.uuidString

            // Parse the selected date or use current date
            let iso8601Formatter = ISO8601DateFormatter()
            var bookedDate: String

            // Try to parse the selected date (format: "dd MMM yyyy")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd MMM yyyy"

            if !selectedDate.isEmpty,
               selectedDate != "Available",
               let parsedDate = dateFormatter.date(from: selectedDate) {
                bookedDate = iso8601Formatter.string(from: parsedDate)
            } else {
                // Use current date if no valid date selected
                bookedDate = iso8601Formatter.string(from: Date())
            }
            
            // Create booking request
            let bookingRequest = CreateBookingRequest(
                service_id: serviceId,
                user_id: userId,
                status: "confirmed",  // or "pending", "completed", etc.
                booked_date: bookedDate
            )
            
            // Insert into database
            try await SupabaseClientManager.shared.client.database
                .from("bookings")
                .insert(bookingRequest)
                .execute()
            
            print("✅ Booking saved successfully")
            print("   Service ID: \(serviceId)")
            print("   User ID: \(userId)")
            print("   Date: \(bookedDate)")
            
            // Navigate to success screen
            await MainActor.run {
                navigateToSuccessScreen()
            }
            
        } catch {
            print("❌ Error saving booking: \(error)")
            
            await MainActor.run {
                payButton.isEnabled = true
                payButton.setTitle("Pay", for: .normal)
                showAlert(message: "Failed to complete booking. Please try again.")
            }
        }
    }
    
    func navigateToSuccessScreen() {
        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        guard let successVC = storyboard.instantiateViewController(withIdentifier: "PaymentSuccessVC") as? PaymentSuccessViewController else {
            print("Could not load success screen")
            payButton.isEnabled = true
            payButton.setTitle("Pay", for: .normal)
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
