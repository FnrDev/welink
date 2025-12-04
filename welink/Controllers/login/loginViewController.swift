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
        // Do any additional setup after loading the view.
    }

    @IBAction func loginBTN(_ sender: Any) {
        Task {
            await login()
        }
    }
    
    @IBAction func createAccBTN(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "createaccVC")
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }
    @IBAction func forgetBTN(_ sender: Any) {
    }
    
    func login() async {
            guard let email = emailField.text, !email.isEmpty,
                  let password = passwordField.text, !password.isEmpty else {
                showAlert("username & password required")
                return
            }
            
            do {
                let session = try await SupabaseClientManager.shared.client.auth.signIn(email: email, password: password)
                showAlert("Logged in as \(session.user.email ?? "unknown")")
                
                // Redirect to home page after successful login
                await MainActor.run {
                    redirectToHome()
                }
            } catch {
                showAlert("Login failed: \(error.localizedDescription)")
            }
        }
        
        func showAlert(_ msg: String) {
            let alert = UIAlertController(title: "Info", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    
    private func redirectToHome() {
        let storyboard = UIStoryboard(name: "ProviderDashboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ProviderDashboardVC") as! ProviderDashboardViewController
        
        // Set it as root view controller
        guard let window = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        window.windows.first?.rootViewController = vc
    }
}
