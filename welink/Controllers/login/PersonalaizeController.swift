//
//  PersonalaizeController.swift
//  welink
//
//  Created by Ali Matar on 11/12/2025.
//

import UIKit

// Updated struct to include services and skills
struct CreateUserRequestFull: Encodable {
    let id: String
    let name: String
    let phone: String
    let image: String?
    let role: String
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
    let serviceOptions = ["Cleaning", "Plumbing", "Electrical", "Painting", "Carpentry", "AC Repair", "Gardening", "Moving"]
    let skillOptions = ["Communication", "Problem Solving", "Time Management", "Teamwork", "Attention to Detail", "Customer Service"]
    
    // Selected items
    var selectedServices: Set<String> = []
    var selectedSkills: Set<String> = []
    
    // For image upload
    private var uploadedImageURL: String?
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
        
        // Update button title
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
        
        // Update button title
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
        print("=== createAccountTapped ===")
        print("userName: \(userName ?? "nil")")
        print("userEmail: \(userEmail ?? "nil")")
        print("userPhone: \(userPhone ?? "nil")")
        print("userPassword: \(userPassword ?? "nil")")
        print("selectedServices: \(selectedServices)")
        print("selectedSkills: \(selectedSkills)")
        
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
            print("=== FAILED: Missing data ===")
            showAlert(title: "Error", message: "Missing account information")
            return
        }
        
        print("=== All validation passed, creating account ===")
        
        setLoading(true)
        
        Task {
            await createAccount(name: name, email: email, phone: phone, password: password)
        }
    }
    
    private func createAccount(name: String, email: String, phone: String, password: String) async {
        do {
            // Step 1: Sign up with Supabase Auth
            let authResponse = try await SupabaseClientManager.shared.client.auth.signUp(
                email: email,
                password: password
            )
            
            let userId = authResponse.user.id.uuidString
            
            // Step 2: Upload image if selected
            if let image = userImage {
                await uploadImageToSupabase(image: image, userId: userId)
            }
            
            // Step 3: Insert profile into users table with services and skills
            let userRequest = CreateUserRequestFull(
                id: userId,
                name: name,
                phone: phone,
                image: uploadedImageURL,
                role: "provider",
                services: Array(selectedServices),
                skills: Array(selectedSkills)
            )
            
            try await SupabaseClientManager.shared.client.database
                .from("users")
                .insert(userRequest)
                .execute()
            
            await MainActor.run {
                setLoading(false)
                showAlert(title: "Success", message: "Account created successfully!") { [weak self] in
                    self?.navigateToHome()
                }
            }
            
        } catch {
            print("Error creating account: \(error)")
            await MainActor.run {
                setLoading(false)
                showAlert(title: "Error", message: "Failed to create account: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadImageToSupabase(image: UIImage, userId: String) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to process image")
            return
        }
        
        let fileName = "\(userId).jpg"
        let filePath = "profiles/\(fileName)"
        
        do {
            try await SupabaseClientManager.shared.client.storage
                .from("images")
                .upload(
                    path: filePath,
                    file: imageData,
                    options: .init(contentType: "image/jpeg")
                )
            
            let publicURL = try SupabaseClientManager.shared.client.storage
                .from("images")
                .getPublicURL(path: filePath)
            
            uploadedImageURL = publicURL.absoluteString
            print("Image uploaded successfully: \(publicURL)")
            
        } catch {
            print("Upload error: \(error)")
        }
    }
    
    private func navigateToHome() {
        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "Home")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = homeVC
            window.makeKeyAndVisible()
            
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
    }
    
    private func setLoading(_ loading: Bool) {
        isLoading = loading
        createAccount.isEnabled = !loading
        createAccount.setTitle(loading ? "Creating..." : "Create Account", for: .normal)
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}
