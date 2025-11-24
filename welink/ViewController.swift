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
            } catch {
                showAlert("Login failed: \(error.localizedDescription)")
            }
        }
        
        func showAlert(_ msg: String) {
            let alert = UIAlertController(title: "Info", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
}

