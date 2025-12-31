//
//  AdminProviderDetailsViewController.swift
//  welink
//
//  Created by rawan on 27/12/2025.
//

import UIKit
import Supabase
import PhotosUI

final class AdminProviderDetailsViewController: UIViewController {

    @IBOutlet private weak var profileImageView: UIImageView?
    @IBOutlet private weak var fullNameTextField: UITextField?
    @IBOutlet private weak var emailTextField: UITextField?
    @IBOutlet private weak var phoneTextField: UITextField?
    @IBOutlet private weak var passwordTextField: UITextField?

    @IBOutlet private weak var skillsButton: UIButton?
    @IBOutlet private weak var servicesButton: UIButton?

    @IBOutlet private weak var saveButton: UIButton?
    @IBOutlet private weak var suspendButton: UIButton?

    var providerId: String?

    private struct ProviderRow: Decodable {
        let id: String
        let name: String
        let phone: String
        let image: String?
        let role: String?
        let status: String?
        let skills: [String]?
    }

    private struct ServiceRow: Decodable {
        let id: String
        let name: String
    }

    private struct UpdateServiceUserRequest: Encodable {
        let user_id: String?
    }

    private struct CreateServiceRequest: Encodable {
        let name: String
        let description: String?
        let price_per_hour: Double?
        let user_id: String
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

    private struct UpdateProviderRequest: Encodable {
        let name: String?
        let phone: String?
        let status: String?
        let skills: [String]?
        let image: String?
    }

    private var provider: ProviderRow?
    private var authEmail: String?
    private var skills: [String] = []
    private var services: [ServiceRow] = []
    private var status: String = "active"

    private var pendingProfileImage: UIImage?
    private var bottomBorderLayers: [ObjectIdentifier: CALayer] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Provider"

        configureUI()

        guard let providerId else {
            showError(message: "No provider selected")
            return
        }

        Task { [weak self] in
            await self?.loadAll(providerId: providerId)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let imageView = profileImageView {
            let size = min(imageView.bounds.width, imageView.bounds.height)
            imageView.layer.cornerRadius = size / 2
        }

        updateBottomBorders()
    }

    private func promptEditList(title: String, values: [String], onSave: @escaping ([String]) -> Void) {
        let message = values.isEmpty ? "No items yet" : values.joined(separator: "\n")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
            self?.promptAddItem(title: title, onSave: onSave)
        }))

        if !values.isEmpty {
            alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { [weak self] _ in
                self?.promptEditAllItems(title: title, existing: values, onSave: onSave)
            }))
            alert.addAction(UIAlertAction(title: "Clear", style: .destructive, handler: { _ in
                onSave([])
            }))
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            if title.lowercased().contains("skill") {
                popover.sourceView = skillsButton
                popover.sourceRect = skillsButton?.bounds ?? .zero
            } else {
                popover.sourceView = servicesButton
                popover.sourceRect = servicesButton?.bounds ?? .zero
            }
        }

        present(alert, animated: true)
    }

    private func promptAddItem(title: String, onSave: @escaping ([String]) -> Void) {
        let alert = UIAlertController(title: "Add \(title.dropLast())", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !value.isEmpty else { return }
            onSave(self.skills + [value])
        }))
        present(alert, animated: true)
    }

    private func promptEditAllItems(title: String, existing: [String], onSave: @escaping ([String]) -> Void) {
        let contentVC = UIViewController()
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = existing.joined(separator: "\n")
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.autocapitalizationType = .sentences
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.cornerRadius = 8

        contentVC.view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: contentVC.view.topAnchor),
            textView.leadingAnchor.constraint(equalTo: contentVC.view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentVC.view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: contentVC.view.bottomAnchor)
        ])
        contentVC.preferredContentSize = CGSize(width: 270, height: 140)

        let alert = UIAlertController(
            title: "Edit \(title)",
            message: "Enter one item per line",
            preferredStyle: .alert
        )
        alert.setValue(contentVC, forKey: "contentViewController")

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
            let raw = textView.text ?? ""
            let items = raw
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            onSave(items)
        }))

        present(alert, animated: true) {
            textView.becomeFirstResponder()
        }
    }

    private func loadAll(providerId: String) async {
        await logCurrentSession()
        await loadProvider(providerId: providerId)
        await loadAuthEmail(providerId: providerId)
        await loadServices(providerId: providerId)
        await MainActor.run {
            self.bindUI(preserveEdits: false)
        }
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

    private func logCurrentSession() async {
        do {
            let session = try await SupabaseClientManager.shared.client.auth.session
            print("✅ Admin session user id: \(session.user.id.uuidString)")
            print("✅ Admin session email: \(session.user.email ?? "-")")
        } catch {
            print("❌ Could not read session (are you logged in?): \(error)")
        }
    }

    private func loadProvider(providerId: String) async {
        do {
            let row: ProviderRow = try await SupabaseClientManager.shared.client.database
                .from("users")
                .select("id, name, phone, image, role, status, skills")
                .eq("id", value: providerId)
                .single()
                .execute()
                .value

            provider = row
            skills = row.skills ?? []
            status = (row.status?.isEmpty == false) ? (row.status ?? "active") : "active"
            print("✅ Loaded provider from users table: \(row.id) \(row.name)")
        } catch {
            print("❌ Failed to load provider row: \(error)")
        }
    }

    private func loadServices(providerId: String) async {
        do {
            let rows: [ServiceRow] = try await SupabaseClientManager.shared.client.database
                .from("services")
                .select("id, name")
                .eq("user_id", value: providerId)
                .order("created_at", ascending: false)
                .execute()
                .value
            services = rows
            print("✅ Loaded services for provider: \(rows.count)")
        } catch {
            services = []
            print("❌ Failed to load services: \(error)")
        }
    }

    private func assignServiceToProvider(serviceId: String, providerId: String) async {
        do {
            try await SupabaseClientManager.shared.client.database
                .from("services")
                .update(UpdateServiceUserRequest(user_id: providerId))
                .eq("id", value: serviceId)
                .execute()

            await loadServices(providerId: providerId)
            await syncUserServicesColumn(providerId: providerId)
        } catch {
            print("❌ Failed to assign service: \(error)")
        }
    }

    private func unassignService(serviceId: String) async {
        guard let providerId else { return }
        do {
            try await SupabaseClientManager.shared.client.database
                .from("services")
                .update(UpdateServiceUserRequest(user_id: nil))
                .eq("id", value: serviceId)
                .execute()

            await loadServices(providerId: providerId)
            await syncUserServicesColumn(providerId: providerId)
        } catch {
            print("❌ Failed to unassign service: \(error)")
        }
    }

    private func createService(providerId: String, name: String, description: String?, pricePerHour: Double?) async {
        do {
            let payload = CreateServiceRequest(
                name: name,
                description: (description?.isEmpty == false) ? description : nil,
                price_per_hour: pricePerHour,
                user_id: providerId
            )

            try await SupabaseClientManager.shared.client.database
                .from("services")
                .insert(payload)
                .execute()

            await loadServices(providerId: providerId)
            await syncUserServicesColumn(providerId: providerId)
            print("✅ Created service for provider")
        } catch {
            print("❌ Failed to create service: \(error)")
        }
    }

    private func syncUserServicesColumn(providerId: String) async {
        let serviceNames = services.map { $0.name }
        do {
            try await SupabaseClientManager.shared.client.database
                .from("users")
                .update(["services": serviceNames])
                .eq("id", value: providerId)
                .execute()
        } catch {
            print("❌ Failed to sync users.services: \(error)")
        }
    }

    private func loadAuthEmail(providerId: String) async {
        do {
            let payload = AdminGetUserEmailPayload(userId: providerId)
            let response: AdminGetUserEmailResponse = try await SupabaseClientManager.shared.client.functions
                .invoke(
                    "admin-get-user-email",
                    options: FunctionInvokeOptions(body: payload)
                )

            authEmail = response.email
            print("✅ Loaded auth email from edge function: \(response.email ?? "nil")")
        } catch {
            authEmail = nil
            print("❌ Failed to load auth email via edge function: \(error)")
        }
    }

    private func bindUI(preserveEdits: Bool) {
        if !preserveEdits {
            fullNameTextField?.text = provider?.name
            phoneTextField?.text = provider?.phone
        }
        emailTextField?.text = authEmail

        let skillsTitle = skills.isEmpty ? "Skills" : "Skills (\(skills.count))"
        let servicesTitle = services.isEmpty ? "Services" : "Services (\(services.count))"
        skillsButton?.setTitle(skillsTitle, for: .normal)
        servicesButton?.setTitle(servicesTitle, for: .normal)

        suspendButton?.setTitle(status.lowercased() == "suspended" ? "Unsuspend" : "Suspend", for: .normal)

        if let image = provider?.image, let url = URL(string: image) {
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

    @IBAction private func skillsTapped(_ sender: Any) {
        promptEditList(title: "Skills", values: skills) { [weak self] updated in
            self?.skills = updated
            self?.bindUI(preserveEdits: true)
        }
    }

    @IBAction private func servicesTapped(_ sender: Any) {
        showServicesActionSheet()
    }

    private func showServicesActionSheet() {
        let names = services.map { $0.name }
        let message = names.isEmpty ? "No services" : names.joined(separator: "\n")
        let alert = UIAlertController(title: "Services", message: message, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Create Service", style: .default, handler: { [weak self] _ in
            self?.showCreateServiceForm()
        }))

        if !services.isEmpty {
            alert.addAction(UIAlertAction(title: "Remove Service", style: .destructive, handler: { [weak self] _ in
                self?.showRemoveServiceSheet()
            }))
        }

        alert.addAction(UIAlertAction(title: "Close", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = servicesButton
            popover.sourceRect = servicesButton?.bounds ?? .zero
        }

        present(alert, animated: true)
    }

    private func showCreateServiceForm() {
        guard let providerId else { return }

        let alert = UIAlertController(title: "Create Service", message: nil, preferredStyle: .alert)

        alert.addTextField { tf in
            tf.placeholder = "Service name"
            tf.autocapitalizationType = .words
        }

        alert.addTextField { tf in
            tf.placeholder = "Description (optional)"
            tf.autocapitalizationType = .sentences
        }

        alert.addTextField { tf in
            tf.placeholder = "Price per hour (optional)"
            tf.keyboardType = .decimalPad
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let desc = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let priceText = alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let price = Double(priceText.replacingOccurrences(of: ",", with: "."))

            guard !name.isEmpty else { return }

            Task { [weak self] in
                guard let self else { return }
                await self.createService(providerId: providerId, name: name, description: desc, pricePerHour: price)
                await MainActor.run { self.bindUI(preserveEdits: true) }
            }
        }))

        present(alert, animated: true)
    }

    private func showRemoveServiceSheet() {
        guard let providerId else { return }
        let alert = UIAlertController(title: "Remove Service", message: "Select a service to remove from this provider", preferredStyle: .actionSheet)

        for row in services {
            alert.addAction(UIAlertAction(title: row.name, style: .destructive, handler: { [weak self] _ in
                guard let self else { return }
                Task { [weak self] in
                    guard let self else { return }
                    await self.unassignService(serviceId: row.id)
                    await self.loadServices(providerId: providerId)
                    await MainActor.run { self.bindUI(preserveEdits: true) }
                }
            }))
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = servicesButton
            popover.sourceRect = servicesButton?.bounds ?? .zero
        }

        present(alert, animated: true)
    }

    @IBAction private func saveTapped(_ sender: Any) {
        guard let providerId else {
            showError(message: "No provider selected")
            return
        }

        view.endEditing(true)

        let name = fullNameTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = phoneTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPassword = passwordTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { [weak self] in
            await self?.saveAll(providerId: providerId, name: name, phone: phone, newPassword: newPassword)
        }
    }

    @IBAction private func suspendTapped(_ sender: Any) {
        let isSuspended = status.lowercased() == "suspended"
        let nextStatus = isSuspended ? "active" : "suspended"
        let title = isSuspended ? "Unsuspend Provider" : "Suspend Provider"
        let message = isSuspended
            ? "Are you sure you want to unsuspend this provider?"
            : "Are you sure you want to suspend this provider?"

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: isSuspended ? "Unsuspend" : "Suspend", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            self.status = nextStatus
            self.bindUI(preserveEdits: true)

            Task { [weak self] in
                await self?.updateProviderStatus(nextStatus)
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

    private func saveAll(providerId: String, name: String?, phone: String?, newPassword: String?) async {
        do {
            let uploadedImageURL = try await uploadPendingProfileImageIfNeeded(providerId: providerId)
            let update = UpdateProviderRequest(
                name: (name?.isEmpty == false) ? name : nil,
                phone: (phone?.isEmpty == false) ? phone : nil,
                status: status,
                skills: skills,
                image: uploadedImageURL
            )

            try await SupabaseClientManager.shared.client.database
                .from("users")
                .update(update)
                .eq("id", value: providerId)
                .execute()

            if let newPassword, !newPassword.isEmpty {
                await setProviderPassword(newPassword: newPassword)
                await MainActor.run {
                    self.passwordTextField?.text = ""
                }
            }

            await loadProvider(providerId: providerId)
            await loadAuthEmail(providerId: providerId)
            await loadServices(providerId: providerId)

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

    private func uploadPendingProfileImageIfNeeded(providerId: String) async throws -> String? {
        guard let image = pendingProfileImage else { return nil }
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return nil }

        let path = "profiles/\(providerId).jpg"
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

    func setProviderPassword(newPassword: String) async {
        guard let providerId else { return }
        guard !newPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        do {
            let payload = AdminSetPasswordPayload(userId: providerId, newPassword: newPassword)
            let response: OkResponse = try await SupabaseClientManager.shared.client.functions
                .invoke(
                    "admin-set-password",
                    options: FunctionInvokeOptions(body: payload)
                )
            print("✅ Password updated: \(response.ok)")
        } catch {
            print("❌ Failed to update password via edge function: \(error)")
        }
    }

    func updateProviderStatus(_ newStatus: String) async {
        guard let providerId else { return }
        do {
            try await SupabaseClientManager.shared.client.database
                .from("users")
                .update(["status": newStatus])
                .eq("id", value: providerId)
                .execute()

            await loadProvider(providerId: providerId)
            await MainActor.run {
                self.bindUI(preserveEdits: false)
            }

            print("✅ Updated provider status to: \(newStatus)")
        } catch {
            print("❌ Failed to update provider status: \(error)")
        }
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension AdminProviderDetailsViewController: PHPickerViewControllerDelegate {
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
