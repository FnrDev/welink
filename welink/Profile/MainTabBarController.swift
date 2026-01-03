//
//  MainTabBarController.swift
//  welink
//
//  Created by Ali Matar on 03/01/2026.
//

import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadUserProfileImage()
    }
    
    // MARK: - Load User Profile Image
    
    private func loadUserProfileImage() {
        Task {
            do {
                let session = try await SupabaseClientManager.shared.client.auth.session
                let userId = session.user.id.uuidString
                
                let response: [ProfileUserData] = try await SupabaseClientManager.shared.client.database
                    .from("users")
                    .select()
                    .eq("id", value: userId)
                    .execute()
                    .value
                
                if let user = response.first, let imagePath = user.image, !imagePath.isEmpty {
                    await loadAndSetTabBarImage(imagePath: imagePath)
                }
                
            } catch {
                print("Error loading user profile for tab bar: \(error)")
            }
        }
    }
    
    // MARK: - Load and Set Tab Bar Image
    
    private func loadAndSetTabBarImage(imagePath: String) async {
        let imageURL: URL?
        
        if imagePath.starts(with: "http") {
            imageURL = URL(string: imagePath)
        } else {
            imageURL = try? SupabaseClientManager.shared.client.storage
                .from("images")
                .getPublicURL(path: imagePath)
        }
        
        guard let url = imageURL else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    // Resize and make circular
                    let resizedImage = resizeAndCircleImage(image: image, size: CGSize(width: 25, height: 25))
                    
                    // Find the Profile tab (last tab) and update its image
                    if let viewControllers = self.viewControllers {
                        let profileIndex = viewControllers.count - 1 // Profile is the last tab
                        viewControllers[profileIndex].tabBarItem.image = resizedImage.withRenderingMode(.alwaysOriginal)
                        viewControllers[profileIndex].tabBarItem.selectedImage = resizedImage.withRenderingMode(.alwaysOriginal)
                    }
                }
            }
        } catch {
            print("Error loading tab bar image: \(error)")
        }
    }
    
    // MARK: - Resize and Circle Image
    
    private func resizeAndCircleImage(image: UIImage, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Create circular path
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(ovalIn: rect)
            path.addClip()
            
            // Draw image
            image.draw(in: rect)
        }
    }
}
