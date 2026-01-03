//
//  ForgotPasswordController.swift
//  welink
//
//  Created by Ali Matar on 03/01/2026.
//

import UIKit

class ForgotPasswordController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var sendCodeButton: UIButton!
    
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup Navigation Bar
    
    private func setupNavigationBar() {
        title = "Forget Password"
        
        // Create back button with chevron and text
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.setTitle(" Back", for: .normal)
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
        
        // Add top padding
        additionalSafeAreaInsets.top = 20
    }
    
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        sendCodeButton.layer.cornerRadius = 12
        sendCodeButton.clipsToBounds = true
    }
    
    // MARK: - Send Code Button
    
    @IBAction func sendCodeButtonTapped(_ sender: UIButton) {
        guard !isLoading else { return }
        
        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            showAlert(title: "Error", message: "Please enter your email address")
            return
        }
        
        guard isValidEmail(email) else {
            showAlert(title: "Error", message: "Please enter a valid email address")
            return
        }
        
        sendOTPCode(email: email)
    }
    
    // MARK: - Send OTP Code
    
    private func sendOTPCode(email: String) {
        setLoading(true)
        
        Task {
            do {
                try await SupabaseClientManager.shared.client.auth.resetPasswordForEmail(email)
                
                await MainActor.run {
                    setLoading(false)
                    showSuccessAndNavigate(email: email)
                }
                
            } catch {
                await MainActor.run {
                    setLoading(false)
                    showAlert(title: "Error", message: "Unable to send reset code. Please try again.")
                }
                print("DEBUG: Reset password error - \(error)")
            }
        }
    }
    
    // MARK: - Show Success and Navigate
    
    private func showSuccessAndNavigate(email: String) {
        let alert = UIAlertController(
            title: "Code Sent",
            message: "If an account exists with this email, you will receive a reset code shortly.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigateToVerifyCode(email: email)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Set Loading State
    
    private func setLoading(_ loading: Bool) {
        isLoading = loading
        sendCodeButton.isEnabled = !loading
        sendCodeButton.setTitle(loading ? "Sending..." : "Send Code", for: .normal)
        sendCodeButton.alpha = loading ? 0.7 : 1.0
    }
    
    // MARK: - Navigate to Verify Code
    
    private func navigateToVerifyCode(email: String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let verifyVC = storyboard.instantiateViewController(withIdentifier: "VerifyCodeController") as? VerifyCodeController else {
            print("DEBUG: Failed to instantiate VerifyCodeController")
            showAlert(title: "Error", message: "Something went wrong. Please try again.")
            return
        }
        
        verifyVC.email = email
        navigationController?.pushViewController(verifyVC, animated: true)
    }
    
    // MARK: - Helpers
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
