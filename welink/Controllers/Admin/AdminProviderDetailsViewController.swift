import UIKit
import Supabase
import PhotosUI

final class AdminProviderDetailsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, PHPickerViewControllerDelegate {

    @IBOutlet private weak var avatarImageView: UIImageView?

    @IBOutlet private weak var fullNameValueLabel: UILabel?
    @IBOutlet private weak var emailValueLabel: UILabel?
    @IBOutlet private weak var phoneValueLabel: UILabel?
    @IBOutlet private weak var skillsTextView: UITextView?

    @IBOutlet private weak var fullNameTextField: UITextField?
    @IBOutlet private weak var emailTextField: UITextField?
    @IBOutlet private weak var phoneTextField: UITextField?
    @IBOutlet private weak var passwordTextField: UITextField?
    @IBOutlet private weak var statusValueLabel: UILabel?
    @IBOutlet private weak var skillsTableView: UITableView?
    @IBOutlet private weak var servicesTableView: UITableView?

    var providerId: String?

    private struct ProviderRow: Decodable {
        let id: String
        let name: String
        let phone: String
        let image: String?
        let created_at: String?
        let role: String?
        let services: [String]?
        let skills: [String]?
        let status: String?
    }

    private struct UpdateProviderRequest: Encodable {
        let name: String?
        let phone: String?
        let image: String?
        let services: [String]?
        let skills: [String]?
        let status: String?
    }

    private struct AdminSetPasswordPayload: Encodable {
        let userId: String
        let newPassword: String
    }

    private enum ListKind {
        case skills
        case services
    }

    private var provider: ProviderRow?
    private var skills: [String] = []
    private var services: [String] = []
    private var currentImageURL: String?
    private var selectedImage: UIImage?
    private var status: String = "active"

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Provider"
        configureUI()
        configureTables()
        configureNavigationItems()

        guard let providerId else {
            showError(message: "No provider selected")
            return
        }

        Task { [weak self] in
            await self?.loadProvider(providerId: providerId)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let avatarImageView {
            avatarImageView.layer.cornerRadius = min(avatarImageView.bounds.width, avatarImageView.bounds.height) / 2
        }
    }

    private func configureUI() {
        avatarImageView?.clipsToBounds = true
        avatarImageView?.contentMode = .scaleAspectFill
        avatarImageView?.isUserInteractionEnabled = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(changePhotoTapped))
        avatarImageView?.addGestureRecognizer(tapGesture)

        emailTextField?.isEnabled = false
        passwordTextField?.isSecureTextEntry = true
    }

    private func configureTables() {
        skillsTableView?.dataSource = self
        skillsTableView?.delegate = self
        servicesTableView?.dataSource = self
        servicesTableView?.delegate = self

        skillsTableView?.tableFooterView = UIView()
        servicesTableView?.tableFooterView = UIView()

        skillsTableView?.allowsSelection = true
        servicesTableView?.allowsSelection = true
    }

    private func configureNavigationItems() {
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addItemTapped))
        navigationItem.rightBarButtonItem = addButton
    }

    private func loadProvider(providerId: String) async {
        let client = SupabaseClientManager.shared.client

        do {
            let row: ProviderRow = try await client.database
                .from("users")
                .select("id, name, phone, image, created_at, role, services, skills, status")
                .eq("id", value: providerId)
                .single()
                .execute()
                .value

            await MainActor.run {
                self.provider = row
                self.skills = row.skills ?? []
                self.services = row.services ?? []
                self.currentImageURL = row.image
                self.status = (row.status?.isEmpty == false) ? (row.status ?? "active") : "active"
                self.applyProviderToUI(row)
            }
        } catch {
            print("Error loading provider:", error.localizedDescription)
            await MainActor.run {
                self.showError(message: "Failed to load provider")
            }
        }
    }

    private func applyProviderToUI(_ row: ProviderRow) {
        fullNameValueLabel?.text = row.name
        phoneValueLabel?.text = row.phone

        fullNameTextField?.text = row.name
        phoneTextField?.text = row.phone

        let generatedEmail = makeEmail(from: row.name)
        emailValueLabel?.text = generatedEmail
        emailTextField?.text = generatedEmail

        statusValueLabel?.text = status

        let skillsText = (skills.isEmpty ? "-" : skills.joined(separator: ", "))
        skillsTextView?.text = skillsText

        skillsTableView?.reloadData()
        servicesTableView?.reloadData()

        if let urlString = row.image, let url = URL(string: urlString) {
            loadImage(url: url)
        } else {
            avatarImageView?.image = nil
            avatarImageView?.backgroundColor = UIColor.systemGray5
        }
    }

    private func loadImage(url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let image = UIImage(data: data)
                await MainActor.run {
                    self.avatarImageView?.image = image
                }
            } catch {
                await MainActor.run {
                    self.avatarImageView?.image = nil
                    self.avatarImageView?.backgroundColor = UIColor.systemGray5
                }
            }
        }
    }

    private func makeEmail(from fullName: String) -> String {
        let parts = fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map { String($0) }

        let first = parts.first ?? "user"
        let last = parts.count >= 2 ? parts.last ?? "" : ""

        let firstSanitized = sanitizeEmailPart(first)
        let lastSanitized = sanitizeEmailPart(last)

        if !lastSanitized.isEmpty {
            return "\(firstSanitized).\(lastSanitized)@gmail.com"
        }
        return "\(firstSanitized)@gmail.com"
    }

    private func sanitizeEmailPart(_ value: String) -> String {
        let lower = value.lowercased()
        let allowed = CharacterSet.alphanumerics
        let filtered = lower.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(filtered))
        return result.isEmpty ? "user" : result
    }

    @IBAction private func saveChangesTapped(_ sender: Any) {
        guard let providerId else {
            showError(message: "No provider selected")
            return
        }

        let name = fullNameTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = phoneTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPassword = passwordTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { [weak self] in
            await self?.saveProviderChanges(providerId: providerId, name: name, phone: phone, newPassword: newPassword)
        }
    }

    private func saveProviderChanges(providerId: String, name: String?, phone: String?, newPassword: String?) async {
        do {
            var uploadedImageURL: String? = currentImageURL
            if let image = selectedImage {
                uploadedImageURL = try await uploadImageToSupabase(image: image, userId: providerId)
            }

            let request = UpdateProviderRequest(
                name: (name?.isEmpty == false) ? name : nil,
                phone: (phone?.isEmpty == false) ? phone : nil,
                image: uploadedImageURL,
                services: services,
                skills: skills,
                status: status
            )

            try await SupabaseClientManager.shared.client.database
                .from("users")
                .update(request)
                .eq("id", value: providerId)
                .execute()

            if let newPassword, !newPassword.isEmpty {
                try await setPasswordAsAdmin(userId: providerId, newPassword: newPassword)
            }

            await MainActor.run {
                self.passwordTextField?.text = ""
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

    @IBAction private func suspendTapped(_ sender: Any) {
        if status.lowercased() == "suspended" {
            status = "active"
        } else {
            status = "suspended"
        }
        statusValueLabel?.text = status

        guard let providerId else {
            showError(message: "No provider selected")
            return
        }

        Task { [weak self] in
            await self?.updateStatus(providerId: providerId)
        }
    }

    private func updateStatus(providerId: String) async {
        do {
            let request = UpdateProviderRequest(
                name: nil,
                phone: nil,
                image: nil,
                services: nil,
                skills: nil,
                status: status
            )

            try await SupabaseClientManager.shared.client.database
                .from("users")
                .update(request)
                .eq("id", value: providerId)
                .execute()

            await MainActor.run {
                let alert = UIAlertController(title: "Updated", message: "Provider status is now \(self.status)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        } catch {
            await MainActor.run {
                self.showError(message: "Failed to update status")
            }
        }
    }

    @objc private func changePhotoTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }

        if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self, let image = object as? UIImage else { return }
                Task { @MainActor in
                    self.selectedImage = image
                    self.avatarImageView?.image = image
                }
            }
        }
    }

    private func uploadImageToSupabase(image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "AdminProviderDetails", code: 1)
        }

        let fileName = "\(userId).jpg"
        let filePath = "profiles/\(fileName)"

        try await SupabaseClientManager.shared.client.storage
            .from("images")
            .upload(
                path: filePath,
                file: imageData,
                options: .init(contentType: "image/jpeg")
            )

        let publicURL = try SupabaseClientManager.shared.client.storage
            .from("images")
            .getPublicURL(path: filePath)

        return publicURL.absoluteString
    }

    private func setPasswordAsAdmin(userId: String, newPassword: String) async throws {
        let payload = AdminSetPasswordPayload(userId: userId, newPassword: newPassword)
        _ = try await SupabaseClientManager.shared.client.functions
            .invoke("admin-set-password", body: payload)
    }

    @objc private func addItemTapped() {
        let sheet = UIAlertController(title: "Add", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Add Skill", style: .default, handler: { [weak self] _ in
            self?.promptForNewItem(kind: .skills)
        }))
        sheet.addAction(UIAlertAction(title: "Add Service", style: .default, handler: { [weak self] _ in
            self?.promptForNewItem(kind: .services)
        }))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(sheet, animated: true)
    }

    private func promptForNewItem(kind: ListKind) {
        let title: String = (kind == .skills) ? "New Skill" : "New Service"
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !value.isEmpty else { return }
            if kind == .skills {
                self.skills.append(value)
                self.skillsTableView?.reloadData()
                self.skillsTextView?.text = self.skills.joined(separator: ", ")
            } else {
                self.services.append(value)
                self.servicesTableView?.reloadData()
            }
        }))
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView === skillsTableView {
            return skills.count
        }
        if tableView === servicesTableView {
            return services.count
        }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")
        cell.selectionStyle = .default
        if tableView === skillsTableView {
            cell.textLabel?.text = skills[indexPath.row]
        } else if tableView === servicesTableView {
            cell.textLabel?.text = services[indexPath.row]
        } else {
            cell.textLabel?.text = nil
        }
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return (tableView === skillsTableView) || (tableView === servicesTableView)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        if tableView === skillsTableView {
            guard skills.indices.contains(indexPath.row) else { return }
            skills.remove(at: indexPath.row)
            skillsTableView?.deleteRows(at: [indexPath], with: .automatic)
            skillsTextView?.text = skills.isEmpty ? "-" : skills.joined(separator: ", ")
        } else if tableView === servicesTableView {
            guard services.indices.contains(indexPath.row) else { return }
            services.remove(at: indexPath.row)
            servicesTableView?.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView === skillsTableView {
            editItem(kind: .skills, index: indexPath.row)
        } else if tableView === servicesTableView {
            editItem(kind: .services, index: indexPath.row)
        }
    }

    private func editItem(kind: ListKind, index: Int) {
        let currentValue: String
        if kind == .skills {
            guard skills.indices.contains(index) else { return }
            currentValue = skills[index]
        } else {
            guard services.indices.contains(index) else { return }
            currentValue = services[index]
        }

        let title: String = (kind == .skills) ? "Edit Skill" : "Edit Service"
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = currentValue
            textField.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !value.isEmpty else { return }
            if kind == .skills {
                self.skills[index] = value
                self.skillsTableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                self.skillsTextView?.text = self.skills.joined(separator: ", ")
            } else {
                self.services[index] = value
                self.servicesTableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            }
        }))
        present(alert, animated: true)
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
