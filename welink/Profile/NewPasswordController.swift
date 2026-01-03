//
//  NewPasswordController.swift
//  welink
//
//  Created by Ali Matar on 03/01/2026.
//

import UIKit

class NewPasswordController: UIViewController {

    @IBOutlet weak var newPasswordTextField: UITextField!
    @IBOutlet weak var confirmPasswordTextField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        title = "New Password"
        
        navigationItem.backButtonTitle = "Back"
        saveButton.layer.cornerRadius = 12
        saveButton.clipsToBounds = true
        
        newPasswordTextField.isSecureTextEntry = true
        confirmPasswordTextField.isSecureTextEntry = true
    }
    
    // MARK: - Save Button
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        guard !isLoading else { return }
        
        guard let password = newPasswordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please enter a new password")
            return
        }
        
        guard let confirmPassword = confirmPasswordTextField.text, !confirmPassword.isEmpty else {
            showAlert(title: "Error", message: "Please confirm your password")
            return
        }
        
        guard password == confirmPassword else {
            showAlert(title: "Error", message: "Passwords don't match")
            return
        }
        
        guard password.count >= 6 else {
            showAlert(title: "Error", message: "Password must be at least 6 characters")
            return
        }
        
        updatePassword(newPassword: password)
    }
    
    // MARK: - Update Password
    
    private func updatePassword(newPassword: String) {
        setLoading(true)
        
        Task {
            do {
                try await SupabaseClientManager.shared.client.auth.update(user: .init(password: newPassword))
                
                await MainActor.run {
                    setLoading(false)
                    showSuccessAndNavigateToLogin()
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    showAlert(title: "Error", message: "Failed to update password. Please try again.")
                }
                print("DEBUG: Update password error - \(error)")
            }
        }
    }
    
    // MARK: - Set Loading State
    
    private func setLoading(_ loading: Bool) {
        isLoading = loading
        saveButton.isEnabled = !loading
        saveButton.setTitle(loading ? "Saving..." : "Save", for: .normal)
        saveButton.alpha = loading ? 0.7 : 1.0
    }
    
    // MARK: - Success and Navigate to Login
    
    private func showSuccessAndNavigateToLogin() {
        let alert = UIAlertController(
            title: "Success",
            message: "Password updated successfully! You can now login.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            // Dismiss the entire navigation controller to go back to login
            self?.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Helpers
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
