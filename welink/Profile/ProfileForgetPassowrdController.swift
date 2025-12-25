//
//  ProfileForgetPassowrdController.swift
//  welink
//
//  Created by Ali Matar on 24/12/2025.
//

import UIKit

class ProfileForgetPassowrdController: UIViewController {

    @IBOutlet weak var backBTN: UIBarButtonItem!
    @IBOutlet weak var resetPasswordBTN: UIButton!
    @IBOutlet weak var emailFiled: UITextField!
    
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        fetchUserEmail()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        resetPasswordBTN.layer.cornerRadius = 12
        resetPasswordBTN.addTarget(self, action: #selector(resetPasswordTapped), for: .touchUpInside)
    }
    
    // MARK: - Fetch User Email
    
    private func fetchUserEmail() {
        Task {
            do {
                let session = try await SupabaseClientManager.shared.client.auth.session
                await MainActor.run {
                    emailFiled.text = session.user.email
                }
            } catch {
                print("Error fetching email: \(error)")
            }
        }
    }
    
    // MARK: - Reset Password
    
    @objc private func resetPasswordTapped() {
        guard let email = emailFiled.text, !email.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter your email")
            return
        }
        
        setLoading(true)
        
        Task {
            await sendResetEmail(email: email)
        }
    }
    
    private func sendResetEmail(email: String) async {
        do {
            try await SupabaseClientManager.shared.client.auth.resetPasswordForEmail(email)
            
            await MainActor.run {
                setLoading(false)
                showAlert(title: "Email Sent", message: "Check your inbox for the password reset code.") {
                    self.showVerifyCodeAlert(email: email)
                }
            }
        } catch {
            print("Error sending reset email: \(error)")
            await MainActor.run {
                setLoading(false)
                showAlert(title: "Error", message: "Failed to send reset email: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Verify Code
    
    private func showVerifyCodeAlert(email: String) {
        let alert = UIAlertController(
            title: "Enter Code",
            message: "Enter the 6-digit code sent to \(email)",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "000000"
            textField.keyboardType = .numberPad
            textField.textAlignment = .center
        }
        
        let verifyAction = UIAlertAction(title: "Verify", style: .default) { _ in
            guard let code = alert.textFields?.first?.text, !code.isEmpty else {
                self.showAlert(title: "Error", message: "Please enter the code")
                return
            }
            
            Task {
                await self.verifyCode(email: email, code: code)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(verifyAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func verifyCode(email: String, code: String) async {
        do {
            try await SupabaseClientManager.shared.client.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )
            
            await MainActor.run {
                self.showNewPasswordAlert()
            }
        } catch {
            print("Error verifying code: \(error)")
            await MainActor.run {
                showAlert(title: "Error", message: "Invalid code: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - New Password
    
    private func showNewPasswordAlert() {
        let alert = UIAlertController(
            title: "New Password",
            message: "Enter your new password",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "New password"
            textField.isSecureTextEntry = true
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Confirm password"
            textField.isSecureTextEntry = true
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            guard let password = alert.textFields?[0].text, !password.isEmpty,
                  let confirmPassword = alert.textFields?[1].text, !confirmPassword.isEmpty else {
                self.showAlert(title: "Error", message: "Please enter password")
                return
            }
            
            guard password == confirmPassword else {
                self.showAlert(title: "Error", message: "Passwords don't match")
                return
            }
            
            guard password.count >= 6 else {
                self.showAlert(title: "Error", message: "Password must be at least 6 characters")
                return
            }
            
            Task {
                await self.updatePassword(newPassword: password)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func updatePassword(newPassword: String) async {
        do {
            try await SupabaseClientManager.shared.client.auth.update(user: .init(password: newPassword))
            
            await MainActor.run {
                showAlert(title: "Success", message: "Password updated successfully!") {
                    self.dismiss(animated: true)
                }
            }
        } catch {
            print("Error updating password: \(error)")
            await MainActor.run {
                showAlert(title: "Error", message: "Failed to update password: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Back Button
    
    @IBAction func backButtonTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
    
    // MARK: - Helpers
    
    private func setLoading(_ loading: Bool) {
        isLoading = loading
        resetPasswordBTN.isEnabled = !loading
        resetPasswordBTN.setTitle(loading ? "Sending..." : "Reset Password", for: .normal)
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}
