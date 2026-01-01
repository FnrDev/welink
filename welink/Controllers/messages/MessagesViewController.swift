//
//  MessagesViewController.swift
//  welink
//
//  Created by Ahmed on 27/12/2025.
//

import UIKit
import Supabase

class MessagesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - IBOutlets
    @IBOutlet private weak var tableView: UITableView!

    // MARK: - Properties
    private var conversations: [ConversationItem] = []
    private var currentUserId: String?

    // MARK: - Models
    struct ConversationItem {
        let conversationId: String
        let otherUserId: String
        let otherUserName: String
        let otherUserImage: String?
        let lastMessage: String
        let lastMessageTime: String
    }

    struct ConversationRow: Decodable {
        let id: String
        let user1_id: String
        let user2_id: String
        let created_at: String?
    }

    struct MessageRow: Decodable {
        let id: String
        let conversation_id: String
        let sender_id: String
        let content: String
        let created_at: String
    }

    struct UserRow: Decodable {
        let id: String
        let name: String
        let image: String?
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Messages"

        setupTableView()

        Task { [weak self] in
            await self?.loadConversations()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Reload conversations when returning to this screen
        Task { [weak self] in
            await self?.loadConversations()
        }
    }

    // MARK: - Setup
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ConversationCell.self, forCellReuseIdentifier: "ConversationCell")
        tableView.rowHeight = 80
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 80, bottom: 0, right: 0)
    }

    // MARK: - Load Conversations
    private func loadConversations() async {
        guard let session = try? await SupabaseClientManager.shared.client.auth.session else {
            print("No active session")
            return
        }

        currentUserId = session.user.id.uuidString.lowercased()
        guard let currentUserId = currentUserId else { return }

        let client = SupabaseClientManager.shared.client

        do {
            // Fetch all conversations where current user is involved
            let conversationRows: [ConversationRow] = try await client.database
                .from("conversations")
                .select("*")
                .or("user1_id.eq.\(currentUserId),user2_id.eq.\(currentUserId)")
                .execute()
                .value

            var items: [ConversationItem] = []

            for conv in conversationRows {
                // Determine the other user's ID
                let otherUserId = conv.user1_id == currentUserId ? conv.user2_id : conv.user1_id

                // Fetch other user's info
                let users: [UserRow] = try await client.database
                    .from("users")
                    .select("id, name, image")
                    .eq("id", value: otherUserId)
                    .limit(1)
                    .execute()
                    .value

                let otherUser = users.first

                // Fetch last message for this conversation
                let messages: [MessageRow] = try await client.database
                    .from("messages")
                    .select("*")
                    .eq("conversation_id", value: conv.id)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value

                let lastMessage = messages.first

                let item = ConversationItem(
                    conversationId: conv.id,
                    otherUserId: otherUserId,
                    otherUserName: otherUser?.name ?? "Unknown",
                    otherUserImage: otherUser?.image,
                    lastMessage: lastMessage?.content ?? "No messages yet",
                    lastMessageTime: formatTime(lastMessage?.created_at)
                )

                items.append(item)
            }

            // Sort by most recent message
            items.sort { $0.lastMessageTime > $1.lastMessageTime }

            await MainActor.run {
                self.conversations = items
                self.tableView.reloadData()
            }

        } catch {
            print("Error loading conversations:", error.localizedDescription)
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ConversationCell", for: indexPath) as? ConversationCell else {
            return UITableViewCell()
        }

        let conversation = conversations[indexPath.row]
        cell.configure(
            name: conversation.otherUserName,
            lastMessage: conversation.lastMessage,
            time: conversation.lastMessageTime,
            imageUrl: conversation.otherUserImage
        )

        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let conversation = conversations[indexPath.row]

        let storyboard = UIStoryboard(name: "Messages", bundle: nil)
        guard let conversationVC = storyboard.instantiateViewController(withIdentifier: "conversationVC") as? ConversationViewController else {
            return
        }

        conversationVC.conversationId = conversation.conversationId
        conversationVC.otherUserId = conversation.otherUserId
        conversationVC.otherUserName = conversation.otherUserName

        navigationController?.pushViewController(conversationVC, animated: true)
    }

    // MARK: - Helpers
    private func formatTime(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = isoFormatter.date(from: dateString)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: dateString)
        }

        guard let date = date else { return "" }

        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
        } else {
            formatter.dateFormat = "MM/dd/yy"
        }

        return formatter.string(from: date)
    }
}

// MARK: - ConversationCell
class ConversationCell: UITableViewCell {

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let avatarLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        contentView.addSubview(avatarImageView)
        avatarImageView.addSubview(avatarLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(messageLabel)
        contentView.addSubview(timeLabel)

        let avatarSize: CGFloat = 56

        // Avatar constraints
        avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16).isActive = true
        avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        avatarImageView.widthAnchor.constraint(equalToConstant: avatarSize).isActive = true
        avatarImageView.heightAnchor.constraint(equalToConstant: avatarSize).isActive = true
        avatarImageView.layer.cornerRadius = avatarSize / 2

        // Avatar label (for initials)
        avatarLabel.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor).isActive = true
        avatarLabel.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor).isActive = true

        // Time label (top right)
        timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14).isActive = true
        timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16).isActive = true

        // Name label
        nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14).isActive = true
        nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12).isActive = true
        nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8).isActive = true

        // Message label
        messageLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4).isActive = true
        messageLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12).isActive = true
        messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16).isActive = true
    }

    func configure(name: String, lastMessage: String, time: String, imageUrl: String?) {
        nameLabel.text = name
        messageLabel.text = lastMessage
        timeLabel.text = time

        // Set initials
        let initials = name.prefix(1).uppercased()
        avatarLabel.text = initials

        // Load image if available
        if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
            avatarLabel.isHidden = true
            loadImage(from: url)
        } else {
            avatarLabel.isHidden = false
            avatarImageView.image = nil
        }
    }

    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.avatarImageView.image = image
                    self?.avatarLabel.isHidden = true
                }
            }
        }.resume()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        messageLabel.text = nil
        timeLabel.text = nil
        avatarImageView.image = nil
        avatarLabel.text = nil
        avatarLabel.isHidden = false
    }
}
