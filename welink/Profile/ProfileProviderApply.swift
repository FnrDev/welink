//
//  ProfileProviderApply.swift
//  welink
//
//  Created by Ali Matar on 28/12/2025.
//

import UIKit

class ProfileProviderApply: UIViewController {

    @IBOutlet weak var applyToProviderBTN: UIButton!
    @IBOutlet weak var selectSkills: UIButton!
    @IBOutlet weak var selectService: UIButton!
    
    // Multi-select options
    let serviceOptions = ["Home", "Tutoring", "Design"]
    let skillOptions = ["Communication", "Problem Solving", "Time Management", "Teamwork", "Attention to Detail", "Customer Service"]
    
    // Selected items
    var selectedServices: Set<String> = []
    var selectedSkills: Set<String> = []
    
    // Loading state
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupServiceMenu()
        setupSkillsMenu()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        applyToProviderBTN.layer.cornerRadius = 12
        applyToProviderBTN.clipsToBounds = true
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
    
    // MARK: - Apply Button Action
    
    @IBAction func applyButtonTapped(_ sender: UIButton) {
        // Validate selections
        guard !selectedServices.isEmpty else {
            showAlert(title: "Missing Information", message: "Please select at least one service")
            return
        }
        
        guard !selectedSkills.isEmpty else {
            showAlert(title: "Missing Information", message: "Please select at least one skill")
            return
        }
        
        setLoading(true)
        
        Task {
            await submitApplication()
        }
    }
    
    // MARK: - Submit Application
    
    private func submitApplication() async {
        do {
            let session = try await SupabaseClientManager.shared.client.auth.session
            let userId = session.user.id.uuidString
            
            // Fetch current user data
            let userResponse: [ProfileUserData] = try await SupabaseClientManager.shared.client.database
                .from("users")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            guard let user = userResponse.first else {
                await MainActor.run {
                    setLoading(false)
                    showAlert(title: "Error", message: "Could not fetch user data")
                }
                return
            }
            
            // Update user with services and skills (keep role as seeker until approved)
            try await SupabaseClientManager.shared.client.database
                .from("users")
                .update([
                    "services": Array(selectedServices),
                    "skills": Array(selectedSkills)
                ])
                .eq("id", value: userId)
                .execute()
            
            // Create application request
            let applicationRequest = CreateApplicationRequest(
                user_id: userId,
                full_name: user.name,
                email: session.user.email ?? "",
                phone: user.phone,
                image_path: user.image ?? "",
                services: Array(selectedServices),
                skills: Array(selectedSkills)
            )
            
            // Insert into applications table
            try await SupabaseClientManager.shared.client.database
                .from("applications")
                .insert(applicationRequest)
                .execute()
            
            await MainActor.run {
                setLoading(false)
                navigateToSuccess()
            }
            
        } catch {
            print("Error submitting application: \(error)")
            await MainActor.run {
                setLoading(false)
                showAlert(title: "Error", message: "Failed to submit application: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Navigate to Success
    
    private func navigateToSuccess() {
        // Navigate using storyboard segue or programmatically
        if let successVC = storyboard?.instantiateViewController(withIdentifier: "ProviderApplySuccess") {
            successVC.modalPresentationStyle = .fullScreen
            present(successVC, animated: true)
        }
    }
    
    // MARK: - Loading State
    
    private func setLoading(_ loading: Bool) {
        isLoading = loading
        applyToProviderBTN.isEnabled = !loading
        applyToProviderBTN.setTitle(loading ? "Submitting..." : "Apply To Be Provider", for: .normal)
    }
    
    // MARK: - Show Alert
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}
