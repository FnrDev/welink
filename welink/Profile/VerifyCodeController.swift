//
//  VerifyCodeController.swift
//  welink
//
//  Created by Ali Matar on 03/01/2026.
//

import UIKit

class VerifyCodeController: UIViewController {

    @IBOutlet weak var codeTextField: UITextField!
    @IBOutlet weak var verifyButton: UIButton!
    @IBOutlet weak var resendButton: UIButton!
    
    var email: String = ""
    private var isResending = false
    private var isVerifying = false
    private var cooldownTimer: Timer?
    private var cooldownSeconds = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startCooldown() // Start cooldown when screen loads (code was just sent)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    deinit {
        cooldownTimer?.invalidate()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        title = "Verify Code"
        navigationItem.backButtonTitle = "Back"
        
        verifyButton.layer.cornerRadius = 12
        verifyButton.clipsToBounds = true
                
        codeTextField.keyboardType = .numberPad
        codeTextField.textAlignment = .center
    }
    
    // MARK: - Cooldown Timer
    
    private func startCooldown() {
        cooldownSeconds = 60
        resendButton.isEnabled = false
        updateResendButtonTitle()
        
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.cooldownSeconds -= 1
            self.updateResendButtonTitle()
            
            if self.cooldownSeconds <= 0 {
                self.cooldownTimer?.invalidate()
                self.cooldownTimer = nil
                self.resendButton.isEnabled = true
                self.resendButton.setTitle("Resend Code", for: .normal)
                self.resendButton.alpha = 1.0
            }
        }
    }
    
    private func updateResendButtonTitle() {
        resendButton.setTitle("Resend Code (\(cooldownSeconds)s)", for: .normal)
        resendButton.alpha = 0.7
    }
    
    // MARK: - Verify Button
    
    @IBAction func verifyButtonTapped(_ sender: UIButton) {
        guard !isVerifying else { return }
        
        guard let code = codeTextField.text, !code.isEmpty else {
            showAlert(title: "Error", message: "Please enter the verification code")
            return
        }
        
        verifyOTP(code: code)
    }
    
    // MARK: - Resend Button
    
    @IBAction func resendButtonTapped(_ sender: UIButton) {
        guard !isResending else { return }
        guard cooldownSeconds <= 0 else { return }
        
        guard !email.isEmpty else {
            showAlert(title: "Error", message: "Email not found. Please go back and try again.")
            return
        }
        
        setResendLoading(true)
        
        Task {
            do {
                try await SupabaseClientManager.shared.client.auth.resetPasswordForEmail(email)
                
                await MainActor.run {
                    setResendLoading(false)
                    showAlert(title: "Success", message: "Code resent to \(email)")
                    startCooldown() // Start cooldown after successful resend
                }
            } catch {
                print("DEBUG: Resend error - \(error)")
                await MainActor.run {
                    setResendLoading(false)
                    showAlert(title: "Error", message: "Please wait before requesting another code.")
                }
            }
        }
    }
    
    // MARK: - Set Resend Loading State
    
    private func setResendLoading(_ loading: Bool) {
        isResending = loading
        resendButton.isEnabled = !loading
        if loading {
            resendButton.setTitle("Sending...", for: .normal)
        }
        resendButton.alpha = loading ? 0.7 : 1.0
    }
    
    // MARK: - Set Verify Loading State
    
    private func setVerifyLoading(_ loading: Bool) {
        isVerifying = loading
        verifyButton.isEnabled = !loading
        verifyButton.setTitle(loading ? "Verifying..." : "Verify Code", for: .normal)
        verifyButton.alpha = loading ? 0.7 : 1.0
    }
    
    // MARK: - Verify OTP
    
    private func verifyOTP(code: String) {
        setVerifyLoading(true)
        
        Task {
            do {
                try await SupabaseClientManager.shared.client.auth.verifyOTP(
                    email: email,
                    token: code,
                    type: .recovery
                )
                
                await MainActor.run {
                    setVerifyLoading(false)
                    navigateToNewPassword()
                }
            } catch {
                print("DEBUG: Verify error - \(error)")
                await MainActor.run {
                    setVerifyLoading(false)
                    showAlert(title: "Error", message: "Invalid code. Please try again.")
                }
            }
        }
    }
    
    // MARK: - Navigate to New Password
    
    private func navigateToNewPassword() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let newPasswordVC = storyboard.instantiateViewController(withIdentifier: "NewPasswordController") as? NewPasswordController else {
            return
        }
        
        navigationController?.pushViewController(newPasswordVC, animated: true)
    }
    
    // MARK: - Helpers
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
