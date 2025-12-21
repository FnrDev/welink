//
//  PersonalaizeController.swift
//  welink
//
//  Created by Ali Matar on 11/12/2025.
//

import UIKit

// Struct for applications table
struct CreateApplicationRequest: Encodable {
    let user_id: String
    let full_name: String
    let email: String
    let phone: String
    let image_path: String
    let services: [String]
    let skills: [String]
}

class PersonalaizeController: UIViewController {

    @IBOutlet weak var createAccount: UIButton!
    @IBOutlet weak var selectSkills: UIButton!
    @IBOutlet weak var selectService: UIButton!
    
    // Data passed from CreateAccountController
    var userName: String?
    var userEmail: String?
    var userPhone: String?
    var userPassword: String?
    var userImage: UIImage?
    
    // Multi-select options
    let serviceOptions = ["Home", "Tutoring", "Design"]
    let skillOptions = ["Communication", "Problem Solving", "Time Management", "Teamwork", "Attention to Detail", "Customer Service"]
    
    // Selected items
    var selectedServices: Set<String> = []
    var selectedSkills: Set<String> = []
    
    // For image upload
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupServiceMenu()
        setupSkillsMenu()
    }
    
    // MARK: - Setup Multi-Select Menus
    
    func setupServiceMenu() {
        updateServiceMenu()
    }
    
    func updateServiceMenu() {
        let actions = serviceOptions.map { service in
            let isSelected = selectedServices.contains(service)
            return UIAction(
                title: service,
                state: isSelected ? .on : .off
            ) { [weak self] _ in
                self?.toggleService(service)
            }
        }
        
        selectService.menu = UIMenu(title: "Select Services", children: actions)
        selectService.showsMenuAsPrimaryAction = true
        
        if selectedServices.isEmpty {
            selectService.setTitle("Select Services", for: .normal)
        } else {
            selectService.setTitle("\(selectedServices.count) selected", for: .normal)
        }
    }
    
    func toggleService(_ service: String) {
        if selectedServices.contains(service) {
            selectedServices.remove(service)
        } else {
            selectedServices.insert(service)
        }
        updateServiceMenu()
    }
    
    func setupSkillsMenu() {
        updateSkillsMenu()
    }
    
    func updateSkillsMenu() {
        let actions = skillOptions.map { skill in
            let isSelected = selectedSkills.contains(skill)
            return UIAction(
                title: skill,
                state: isSelected ? .on : .off
            ) { [weak self] _ in
                self?.toggleSkill(skill)
            }
        }
        
        selectSkills.menu = UIMenu(title: "Select Skills", children: actions)
        selectSkills.showsMenuAsPrimaryAction = true
        
        if selectedSkills.isEmpty {
            selectSkills.setTitle("Select Skills", for: .normal)
        } else {
            selectSkills.setTitle("\(selectedSkills.count) selected", for: .normal)
        }
    }
    
    func toggleSkill(_ skill: String) {
        if selectedSkills.contains(skill) {
            selectedSkills.remove(skill)
        } else {
            selectedSkills.insert(skill)
        }
        updateSkillsMenu()
    }
    
    // MARK: - Create Account
    
    @IBAction func createAccountTapped(_ sender: UIButton) {
        // Validate selections
        guard !selectedServices.isEmpty else {
            showAlert(title: "Missing Information", message: "Please select at least one service")
            return
        }
        
        guard !selectedSkills.isEmpty else {
            showAlert(title: "Missing Information", message: "Please select at least one skill")
            return
        }
        
        guard let name = userName,
              let email = userEmail,
              let phone = userPhone,
              let password = userPassword else {
            showAlert(title: "Error", message: "Missing account information")
            return
        }
        
        setLoading(true)
        
        Task {
            await submitApplication(name: name, email: email, phone: phone, password: password)
        }
    }
    
    private func submitApplication(name: String, email: String, phone: String, password: String) async {
        do {
            // Step 1: Sign up with Supabase Auth
            let authResponse = try await SupabaseClientManager.shared.client.auth.signUp(
                email: email,
                password: password
            )
            
            let userId = authResponse.user.id.uuidString
            
            // Step 2: Upload image if selected
            var imagePath = ""
            if let image = userImage {
                imagePath = await uploadImageToSupabase(image: image, userId: userId) ?? ""
            }
            
            // Step 3: Create user in users table with services and skills
            let userRequest = CreateUserRequest(
                id: userId,
                name: name,
                phone: phone,
                image: imagePath.isEmpty ? nil : imagePath,
                role: "provider",
                services: Array(selectedServices),
                skills: Array(selectedSkills)
            )
            
            try await SupabaseClientManager.shared.client.database
                .from("users")
                .insert(userRequest)
                .execute()
            
            // Step 4: Insert application into applications table (pending review)
            let applicationRequest = CreateApplicationRequest(
                user_id: userId,
                full_name: name,
                email: email,
                phone: phone,
                image_path: imagePath,
                services: Array(selectedServices),
                skills: Array(selectedSkills)
            )
            
            try await SupabaseClientManager.shared.client.database
                .from("applications")
                .insert(applicationRequest)
                .execute()
            
            await MainActor.run {
                setLoading(false)
                showAlert(title: "Application Submitted", message: "Your application has been submitted for review. We'll notify you once it's approved.") { [weak self] in
                    self?.navigateToPendingRequest()
                }
            }
            
        } catch {
            print("Error submitting application: \(error)")
            await MainActor.run {
                setLoading(false)
                showAlert(title: "Error", message: "Failed to submit application: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadImageToSupabase(image: UIImage, userId: String) async -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to process image")
            return nil
        }
        
        let fileName = "\(userId).jpg"
        let filePath = "applications/\(fileName)"
        
        do {
            try await SupabaseClientManager.shared.client.storage
                .from("images")
                .upload(
                    path: filePath,
                    file: imageData,
                    options: .init(contentType: "image/jpeg")
                )
            
            print("Image uploaded successfully: \(filePath)")
            return filePath
            
        } catch {
            print("Upload error: \(error)")
            return nil
        }
    }
    
    private func navigateToPendingRequest() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let pendingVC = storyboard.instantiateViewController(withIdentifier: "PendingRequest")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = pendingVC
            window.makeKeyAndVisible()
            
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
    }
    
    private func setLoading(_ loading: Bool) {
        isLoading = loading
        createAccount.isEnabled = !loading
        createAccount.setTitle(loading ? "Submitting..." : "Create Account", for: .normal)
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}
