import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    // MARK: - Change this to test different storyboards
    let testMode = true  // Set to true to test a specific storyboard
    let testStoryboard = "Main"  // Change this to your storyboard name
    let testViewControllerID = "ViewController"  // Change this to your VC identifier
    
    // admin dashboard
    // - ProviderDashboard,ProviderDashboardVC

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)

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
                let storyboard = UIStoryboard(name: "AdminDashboard", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "AdminDashboard")
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
