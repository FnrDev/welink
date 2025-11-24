import UIKit
import Supabase

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)

        Task { @MainActor in
            await checkSessionAndRedirect()
        }
    }

    @MainActor
    private func checkSessionAndRedirect() async {
        let client = SupabaseClientManager.shared.client
        let session = try? await client.auth.session

        if session != nil {
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "HomeVC") as! HomeViewController
            window?.rootViewController = vc
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "ViewController") as! ViewController
            window?.rootViewController = vc
        }
        
        window?.makeKeyAndVisible()
    }
}
