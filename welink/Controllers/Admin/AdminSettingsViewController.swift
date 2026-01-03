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

    private let cardCornerRadius: CGFloat = 16

    private enum DefaultsKey {
        static let darkModeEnabled = "settings_dark_mode_enabled"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Settings"

        let enabled = UserDefaults.standard.bool(forKey: DefaultsKey.darkModeEnabled)
        darkModeSwitch?.isOn = enabled
        applyAppTheme(enabled: enabled)

        updateAdminLogAppearance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let containers: [UIView] = [
            darkModeSwitch?.superview,
            adminLogButton?.superview,
            logoutButton?.superview
        ].compactMap { $0 }

        for view in containers {
            view.layer.cornerRadius = cardCornerRadius
            if #available(iOS 13.0, *) {
                view.layer.cornerCurve = .continuous
            }
            view.layer.masksToBounds = true
        }

        updateAdminLogAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            updateAdminLogAppearance()
        }
    }

    @IBAction private func darkModeChanged(_ sender: UISwitch) {
        let enabled = sender.isOn
        UserDefaults.standard.set(enabled, forKey: DefaultsKey.darkModeEnabled)
        applyAppTheme(enabled: enabled)

        DispatchQueue.main.async { [weak self] in
            self?.updateAdminLogAppearance()
        }
    }

    private func updateAdminLogAppearance() {
        guard let adminLogButton else { return }

        let isDark = traitCollection.userInterfaceStyle == .dark
        let color: UIColor = isDark ? .white : .label

        if var configuration = adminLogButton.configuration {
            configuration.baseForegroundColor = color
            adminLogButton.configuration = configuration
        } else {
            adminLogButton.setTitleColor(color, for: .normal)
        }

        adminLogButton.tintColor = color
    }

    @IBAction private func adminLogTapped(_ sender: Any) {
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "AdminLogsVC") as? AdminLogsViewController else {
            let alert = UIAlertController(title: "Error", message: "AdminLogs screen not found in storyboard", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        navigationController?.pushViewController(vc, animated: true)
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
        let loginVC = storyboard.instantiateViewController(withIdentifier: "ViewController")

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = loginVC
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
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
