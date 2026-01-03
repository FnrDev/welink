//
//  AdminSeekerDetailsViewController.swift
//  welink
//
//  Created by rawan on 01/01/2026.
//
import UIKit
import Supabase
import PhotosUI

final class AdminSeekerDetailsViewController: UIViewController {

    @IBOutlet private weak var profileImageView: UIImageView?
    @IBOutlet private weak var fullNameTextField: UITextField?
    @IBOutlet private weak var emailTextField: UITextField?
    @IBOutlet private weak var phoneTextField: UITextField?
    @IBOutlet private weak var passwordTextField: UITextField?

    @IBOutlet private weak var saveButton: UIButton?
    @IBOutlet private weak var suspendButton: UIButton?

    var seekerId: String?

    private struct SeekerRow: Decodable {
        let id: String
        let name: String
        let phone: String
        let image: String?
        let role: String?
        let status: String?
        let skills: [String]?
    }

    private struct AdminGetUserEmailPayload: Encodable {
        let userId: String
    }

    private struct AdminGetUserEmailResponse: Decodable {
        let email: String?
    }

    private struct AdminSetPasswordPayload: Encodable {
        let userId: String
        let newPassword: String
    }

    private struct OkResponse: Decodable {
        let ok: Bool
    }

    private struct UpdateUserRequest: Encodable {
        let name: String?
        let phone: String?
        let status: String?
        let image: String?
        let skills: [String]?
    }

    private var seeker: SeekerRow?
    private var authEmail: String?
    private var status: String = "active"
    private var skills: [String] = []

    private var pendingProfileImage: UIImage?
    private var bottomBorderLayers: [ObjectIdentifier: CALayer] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Seeker"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Moderation",
            style: .plain,
            target: self,
            action: #selector(didTapModeration)
        )
        configureUI()

        guard let seekerId else {
            showError(message: "No seeker selected")
            return
        }

        Task { [weak self] in
            await self?.loadAll(seekerId: seekerId)
        }
    }

    @objc private func didTapModeration() {
        guard let seekerId else {
            showError(message: "No seeker selected")
            return
        }

        let storyboard = UIStoryboard(name: "AdminDashboard", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "AdminModerationVC") as? AdminModerationViewController else {
            showError(message: "Moderation screen not found")
            return
        }

        vc.targetId = seekerId
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let imageView = profileImageView {
            let size = min(imageView.bounds.width, imageView.bounds.height)
            imageView.layer.cornerRadius = size / 2
        }

        updateBottomBorders()
    }

    private func configureUI() {
        profileImageView?.clipsToBounds = true
        profileImageView?.contentMode = .scaleAspectFill

        emailTextField?.isEnabled = false
        passwordTextField?.isSecureTextEntry = true

        applyTextFieldStyle(fullNameTextField)
        applyTextFieldStyle(emailTextField)
        applyTextFieldStyle(phoneTextField)
        applyTextFieldStyle(passwordTextField)
    }

    private func applyTextFieldStyle(_ textField: UITextField?) {
        guard let textField else { return }
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.clearButtonMode = .never

        let key = ObjectIdentifier(textField)
        if bottomBorderLayers[key] == nil {
            let layer = CALayer()
            layer.backgroundColor = UIColor.systemGray4.cgColor
            textField.layer.addSublayer(layer)
            bottomBorderLayers[key] = layer
        }
    }

    private func updateBottomBorders() {
        let height: CGFloat = 1
        let fields: [UITextField?] = [fullNameTextField, emailTextField, phoneTextField, passwordTextField]
        for tf in fields {
            guard let tf else { continue }
            let key = ObjectIdentifier(tf)
            guard let layer = bottomBorderLayers[key] else { continue }
            let y = tf.bounds.height - height
            layer.frame = CGRect(x: 0, y: y, width: tf.bounds.width, height: height)
        }
    }

    private func loadAll(seekerId: String) async {
        await loadSeeker(seekerId: seekerId)
        await loadAuthEmail(seekerId: seekerId)
        await MainActor.run {
            self.bindUI(preserveEdits: false)
        }
    }

    private func loadSeeker(seekerId: String) async {
        do {
            let row: SeekerRow = try await SupabaseClientManager.shared.client.database
                .from("users")
                .select("id, name, phone, image, role, status, skills")
                .eq("id", value: seekerId)
                .single()
                .execute()
                .value

            seeker = row
            skills = row.skills ?? []
            status = (row.status?.isEmpty == false) ? (row.status ?? "active") : "active"
        } catch {
            print("❌ Failed to load seeker row: \(error)")
        }
    }

    private func loadAuthEmail(seekerId: String) async {
        do {
            let payload = AdminGetUserEmailPayload(userId: seekerId)
            let response: AdminGetUserEmailResponse = try await SupabaseClientManager.shared.client.functions
                .invoke(
                    "admin-get-user-email",
                    options: FunctionInvokeOptions(body: payload)
                )

            authEmail = response.email
        } catch {
            authEmail = nil
            print("❌ Failed to load auth email via edge function: \(error)")
        }
    }

    private func bindUI(preserveEdits: Bool) {
        if !preserveEdits {
            fullNameTextField?.text = seeker?.name
            phoneTextField?.text = seeker?.phone
        }
        emailTextField?.text = authEmail

        suspendButton?.setTitle(status.lowercased() == "suspended" ? "Unsuspend" : "Suspend", for: .normal)

        if let image = seeker?.image, let url = URL(string: image) {
            loadImage(url: url)
        }
    }

    private func loadImage(url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let image = UIImage(data: data)
                await MainActor.run {
                    self.profileImageView?.image = image
                }
            } catch {
                await MainActor.run {
                    self.profileImageView?.image = nil
                }
            }
        }
    }

    @IBAction private func saveTapped(_ sender: Any) {
        guard let seekerId else {
            showError(message: "No seeker selected")
            return
        }

        view.endEditing(true)

        let name = fullNameTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = phoneTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPassword = passwordTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { [weak self] in
            await self?.saveAll(seekerId: seekerId, name: name, phone: phone, newPassword: newPassword)
        }
    }

    @IBAction private func suspendTapped(_ sender: Any) {
        let isSuspended = status.lowercased() == "suspended"
        let nextStatus = isSuspended ? "active" : "suspended"
        let title = isSuspended ? "Unsuspend Seeker" : "Suspend Seeker"
        let message = isSuspended
            ? "Are you sure you want to unsuspend this seeker?"
            : "Are you sure you want to suspend this seeker?"

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: isSuspended ? "Unsuspend" : "Suspend", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            self.status = nextStatus
            self.bindUI(preserveEdits: true)

            Task { [weak self] in
                await self?.updateUserStatus(nextStatus)
            }
        }))
        present(alert, animated: true)
    }

    @IBAction private func editPhotoTapped(_ sender: Any) {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func saveAll(seekerId: String, name: String?, phone: String?, newPassword: String?) async {
        do {
            let uploadedImageURL = try await uploadPendingProfileImageIfNeeded(userId: seekerId)
            let update = UpdateUserRequest(
                name: (name?.isEmpty == false) ? name : nil,
                phone: (phone?.isEmpty == false) ? phone : nil,
                status: status,
                image: uploadedImageURL,
                skills: skills
            )

            try await SupabaseClientManager.shared.client.database
                .from("users")
                .update(update)
                .eq("id", value: seekerId)
                .execute()

            if let newPassword, !newPassword.isEmpty {
                await setUserPassword(userId: seekerId, newPassword: newPassword)
                await MainActor.run {
                    self.passwordTextField?.text = ""
                }
            }

            await loadSeeker(seekerId: seekerId)
            await loadAuthEmail(seekerId: seekerId)

            await MainActor.run {
                self.bindUI(preserveEdits: false)
                let alert = UIAlertController(title: "Saved", message: "Changes saved successfully", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        } catch {
            await MainActor.run {
                self.showError(message: "Failed to save changes")
            }
        }
    }

    private func uploadPendingProfileImageIfNeeded(userId: String) async throws -> String? {
        guard let image = pendingProfileImage else { return nil }
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return nil }

        let path = "profiles/\(userId).jpg"
        let bucket = SupabaseClientManager.shared.client.storage.from("images")

        try await bucket.upload(
            path: path,
            file: jpegData,
            options: .init(contentType: "image/jpeg")
        )

        let publicURL = try bucket.getPublicURL(path: path)

        await MainActor.run {
            self.pendingProfileImage = nil
        }

        return publicURL.absoluteString
    }

    private func setUserPassword(userId: String, newPassword: String) async {
        guard !newPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        do {
            let payload = AdminSetPasswordPayload(userId: userId, newPassword: newPassword)
            let response: OkResponse = try await SupabaseClientManager.shared.client.functions
                .invoke(
                    "admin-set-password",
                    options: FunctionInvokeOptions(body: payload)
                )
            print("✅ Password updated: \(response.ok)")

            if response.ok {
                await AdminLogService.shared.log(
                    action: "Updated seeker password",
                    targetUserId: userId,
                    metadata: nil
                )
            }
        } catch {
            print("❌ Failed to update password via edge function: \(error)")
        }
    }

    private func updateUserStatus(_ newStatus: String) async {
        guard let seekerId else { return }
        do {
            try await SupabaseClientManager.shared.client.database
                .from("users")
                .update(["status": newStatus])
                .eq("id", value: seekerId)
                .execute()

            await AdminLogService.shared.log(
                action: (newStatus.lowercased() == "suspended") ? "Suspended seeker" : "Unsuspended seeker",
                targetUserId: seekerId,
                metadata: ["status": newStatus]
            )

            await loadSeeker(seekerId: seekerId)
            await MainActor.run {
                self.bindUI(preserveEdits: false)
            }
        } catch {
            print("❌ Failed to update status: \(error)")
        }
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension AdminSeekerDetailsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else { return }
        guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { return }

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            Task { @MainActor in
                self.pendingProfileImage = image
                self.profileImageView?.image = image
            }
        }
    }
}
