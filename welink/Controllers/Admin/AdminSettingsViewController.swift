//
//  AdminSettingsViewController.swift
//  welink
//
//  Created by rawan on 01/01/2026.
//

import UIKit
import Supabase

final class AdminSettingsViewController: UIViewController {

    @IBOutlet private weak var darkModeSwitch: UISwitch?
    @IBOutlet private weak var adminLogButton: UIButton?
    @IBOutlet private weak var logoutButton: UIButton?

    private enum DefaultsKey {
        static let darkModeEnabled = "settings_dark_mode_enabled"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Settings"

        let enabled = UserDefaults.standard.bool(forKey: DefaultsKey.darkModeEnabled)
        darkModeSwitch?.isOn = enabled
        applyAppTheme(enabled: enabled)

        adminLogButton?.setTitleColor(.label, for: .normal)
    }

    @IBAction private func darkModeChanged(_ sender: UISwitch) {
        let enabled = sender.isOn
        UserDefaults.standard.set(enabled, forKey: DefaultsKey.darkModeEnabled)
        applyAppTheme(enabled: enabled)
    }

    @IBAction private func adminLogTapped(_ sender: Any) {
        let alert = UIAlertController(
            title: "Admin Log",
            message: "Not implemented yet. If you want, we can add a Supabase table (admin_logs) and record actions like suspend/unsuspend, edits, approvals.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @IBAction private func logoutTapped(_ sender: Any) {
        let alert = UIAlertController(
            title: "Logout",
            message: "Are you sure you want to logout?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            Task { [weak self] in
                await self?.performLogout()
            }
        }))
        present(alert, animated: true)
    }

    private func performLogout() async {
        do {
            try await SupabaseClientManager.shared.client.auth.signOut()
            await MainActor.run {
                NotificationCenter.default.post(name: .didLogout, object: nil)
                self.resetToLoginRoot()
            }
        } catch {
            await MainActor.run {
                let alert = UIAlertController(
                    title: "Error",
                    message: "Failed to logout. Please try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    private func resetToLoginRoot() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")

        let scenes = UIApplication.shared.connectedScenes
        for scene in scenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.rootViewController = loginVC
                window.makeKeyAndVisible()
            }
        }
    }

    private func applyAppTheme(enabled: Bool) {
        let style: UIUserInterfaceStyle = enabled ? .dark : .light

        let scenes = UIApplication.shared.connectedScenes
        for scene in scenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

extension Notification.Name {
    static let didLogout = Notification.Name("did_logout")
}
