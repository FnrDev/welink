import UIKit

class HomeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func logoutTapped(_ sender: Any) {
        Task {
            do {
                try await SupabaseClientManager.shared.client.auth.signOut()
                redirectToLogin()
            } catch {
                print("Logout error: \(error)")
            }
        }
    }
    
    private func redirectToLogin() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ViewController") as! ViewController
        
        // Set it as root view controller instead of presenting
        guard let window = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        window.windows.first?.rootViewController = vc
    }
}
