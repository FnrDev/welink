import UIKit
import Supabase

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    // MARK: - Change this to test different storyboards
    let testMode = false  // Set to true to test a specific storyboard
    let testStoryboard = "SeekerHome"  // Change this to your storyboard name
    let testViewControllerID = "HomeVC"  // Change this to your VC identifier

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)

        // If test mode is on, load the test storyboard directly
        if testMode {
            let storyboard = UIStoryboard(name: testStoryboard, bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: testViewControllerID)
            window?.rootViewController = vc
            window?.makeKeyAndVisible()
            return
        }

        Task { @MainActor in
            await checkSessionAndRedirect()
        }
    }

    @MainActor
    private func checkSessionAndRedirect() async {
        let client = SupabaseClientManager.shared.client
        let session = try? await client.auth.session

        if session != nil {
            let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "HomeVC") as! SeekerHomeViewController
            window?.rootViewController = vc
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "ViewController") as! ViewController
            window?.rootViewController = vc
        }
        
        window?.makeKeyAndVisible()
    }
}
