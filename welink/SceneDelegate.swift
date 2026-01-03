import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    // MARK: - Change this to test different storyboards
    let testMode = false  // Set to true to test a specific storyboard
    let testStoryboard = "AdminDashboard"  // Change this to your storyboard name
    let testViewControllerID = "AdminSeekersListVC"  // Change this to your VC identifier
    
    // MARK: - Set this to true to clear session and go to login
    let clearSession = true
    // admin dashboard
    // - ProviderDashboard,ProviderDashboardVC

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)

        // Apply saved dark mode preference
        let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        window?.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
        
        // If clear session is on, sign out and go to login
        if clearSession {
            Task {
                try? await SupabaseClientManager.shared.client.auth.signOut()
                await MainActor.run {
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc = storyboard.instantiateViewController(withIdentifier: "ViewController")
                    window?.rootViewController = vc
                    window?.makeKeyAndVisible()
                }
            }
            return
        }

        // If test mode is on, load the test storyboard directly
        if testMode {
            let storyboard = UIStoryboard(name: testStoryboard, bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: testViewControllerID)
            window?.rootViewController = UINavigationController(rootViewController: vc)
            window?.makeKeyAndVisible()
            return
        }

        // Show launch screen first
        let launchStoryboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
        let launchVC = launchStoryboard.instantiateInitialViewController()
        window?.rootViewController = launchVC
        window?.makeKeyAndVisible()

        Task { @MainActor in
            // Keep launch screen for 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await checkSessionAndRedirect()
        }
    }

    @MainActor
    private func checkSessionAndRedirect() async {
        let client = SupabaseClientManager.shared.client
        let session = try? await client.auth.session

        if let session = session {
            // Fetch user role from database
            let userId = session.user.id.uuidString
            let userRole = await fetchUserRole(userId: userId)

            if userRole == "admin" {
                // Apply admin-specific dark mode setting
                let isAdminDarkMode = UserDefaults.standard.bool(forKey: "settings_dark_mode_enabled")
                window?.overrideUserInterfaceStyle = isAdminDarkMode ? .dark : .light

                let storyboard = UIStoryboard(name: "AdminDashboard", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "AdminTabBarController")
                window?.rootViewController = vc
            } else {
                let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "SeekerTabController")
                window?.rootViewController = vc
            }
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "ViewController") as! ViewController
            window?.rootViewController = vc
        }

        window?.makeKeyAndVisible()
    }

    private func fetchUserRole(userId: String) async -> String {
        do {
            let response: [[String: String]] = try await SupabaseClientManager.shared.client.database
                .from("users")
                .select("role")
                .eq("id", value: userId)
                .execute()
                .value

            return response.first?["role"] ?? "seeker"
        } catch {
            print("Error fetching user role: \(error)")
            return "seeker"
        }
    }
}
