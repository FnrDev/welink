//
//  ViewController.swift
//  welink
//
//  Created by Ahmed on 17/11/2025.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func loginBTN(_ sender: Any) {
        Task {
            await login()
        }
    }
    
    @IBAction func forgetBTN(_ sender: Any) {
        showForgotPasswordAlert()
    }
    
    // MARK: - Forgot Password Flow
    
    private func showForgotPasswordAlert() {
        let alert = UIAlertController(
            title: "Reset Password",
            message: "Enter your email address to receive a reset code.",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Email"
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
            textField.text = self.emailField.text
        }
        
        let sendAction = UIAlertAction(title: "Send Code", style: .default) { _ in
            guard let email = alert.textFields?.first?.text, !email.isEmpty else {
                self.showAlert("Please enter your email address")
                return
            }
            
            Task {
                await self.sendOTPCode(email: email)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(sendAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func sendOTPCode(email: String) async {
        do {
            try await SupabaseClientManager.shared.client.auth.resetPasswordForEmail(email)
            
            await MainActor.run {
                self.showVerifyCodeAlert(email: email)
            }
        } catch {
            await MainActor.run {
                showAlert("Failed to send code: \(error.localizedDescription)")
            }
        }
    }
    
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
                self.showAlert("Please enter the code")
                return
            }
            
            Task {
                await self.verifyOTP(email: email, code: code)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(verifyAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func verifyOTP(email: String, code: String) async {
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
            await MainActor.run {
                showAlert("Invalid code: \(error.localizedDescription)")
            }
        }
    }
    
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
                self.showAlert("Please enter password")
                return
            }
            
            guard password == confirmPassword else {
                self.showAlert("Passwords don't match")
                return
            }
            
            guard password.count >= 6 else {
                self.showAlert("Password must be at least 6 characters")
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
                showAlert("Password updated successfully! You can now login.")
            }
        } catch {
            await MainActor.run {
                showAlert("Failed to update password: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Login
    
    func login() async {
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showAlert("Username & password required")
            return
        }
        
        do {
            let session = try await SupabaseClientManager.shared.client.auth.signIn(email: email, password: password)
           
            
            await MainActor.run {
                redirectToHome()
            }
        } catch {
            showAlert("Login failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    func showAlert(_ msg: String) {
        let alert = UIAlertController(title: "Info", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func redirectToHome() {
        let storyboard = UIStoryboard(name: "ProviderDashboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ProviderDashboardVC") as! ProviderDashboardViewController
        
        guard let window = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        window.windows.first?.rootViewController = vc
    }
}
