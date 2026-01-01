//
//  MessagesViewController.swift
//  welink
//
//  Created by Ahmed on 27/12/2025.
//

import UIKit
import Supabase

class ConversationViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    // MARK: - IBOutlets
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var messageTextField: UITextField!
    @IBOutlet private weak var sendButton: UIButton!

    // These will be found programmatically from the text field's superview
    private weak var inputContainerView: UIView?
    private var inputContainerBottomConstraint: NSLayoutConstraint?

    // MARK: - Properties
    var conversationId: String?
    var otherUserId: String?
    var otherUserName: String?

    private var messages: [ChatMessage] = []
    private var currentUserId: String?
    private var realtimeChannel: RealtimeChannelV2?

    // MARK: - Models
    struct ChatMessage: Codable, Identifiable {
        let id: String
        let conversation_id: String
        let sender_id: String
        let content: String
        let created_at: String

        var isFromCurrentUser: Bool = false

        enum CodingKeys: String, CodingKey {
            case id, conversation_id, sender_id, content, created_at
        }
    }

    struct CreateMessageRequest: Encodable {
        let conversation_id: String
        let sender_id: String
        let content: String
    }

    struct Conversation: Codable {
        let id: String
        let user1_id: String
        let user2_id: String
        let created_at: String?
    }

    struct CreateConversationRequest: Encodable {
        let user1_id: String
        let user2_id: String
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = otherUserName ?? "Messages"

        setupUI()
        setupKeyboardObservers()

        Task { [weak self] in
            await self?.initializeChat()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        Task { [weak self] in
            await self?.unsubscribeFromRealtime()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup
    private func setupUI() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.keyboardDismissMode = .interactive

        // Register cells programmatically
        tableView.register(MessageCell.self, forCellReuseIdentifier: "SentMessageCell")
        tableView.register(MessageCell.self, forCellReuseIdentifier: "ReceivedMessageCell")

        // Transform table to show messages from bottom
        tableView.transform = CGAffineTransform(scaleX: 1, y: -1)

        messageTextField.delegate = self
        messageTextField.placeholder = "Type a message..."
        messageTextField.returnKeyType = .send

        // Find input container from text field's superview
        inputContainerView = messageTextField.superview
        inputContainerView?.layer.borderWidth = 0.5
        inputContainerView?.layer.borderColor = UIColor.systemGray4.cgColor

        // Setup all constraints programmatically
        setupConstraints()

        sendButton.isEnabled = false
        messageTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }

    private func setupConstraints() {
        guard let container = inputContainerView else { return }

        // Disable autoresizing masks
        tableView.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        messageTextField.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        // Container constraints (pinned to bottom)
        container.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        container.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        container.heightAnchor.constraint(equalToConstant: 60).isActive = true

        // Bottom constraint (we'll animate this for keyboard)
        inputContainerBottomConstraint = container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        inputContainerBottomConstraint?.isActive = true

        // TableView constraints
        tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: container.topAnchor).isActive = true

        // TextField constraints (inside container)
        messageTextField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16).isActive = true
        messageTextField.topAnchor.constraint(equalTo: container.topAnchor, constant: 10).isActive = true
        messageTextField.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10).isActive = true
        messageTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -10).isActive = true

        // Send button constraints (inside container)
        sendButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16).isActive = true
        sendButton.centerYAnchor.constraint(equalTo: container.centerYAnchor).isActive = true
        sendButton.widthAnchor.constraint(equalToConstant: 60).isActive = true
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    // MARK: - Keyboard Handling
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }

        let keyboardHeight = keyboardFrame.height - view.safeAreaInsets.bottom

        UIView.animate(withDuration: duration) {
            self.inputContainerBottomConstraint?.constant = -keyboardHeight
            self.view.layoutIfNeeded()
        }

        scrollToBottom(animated: true)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }

        UIView.animate(withDuration: duration) {
            self.inputContainerBottomConstraint?.constant = 0
            self.view.layoutIfNeeded()
        }
    }

    @objc private func textFieldDidChange() {
        let text = messageTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        sendButton.isEnabled = !text.isEmpty
    }

    // MARK: - Chat Initialization
    private func initializeChat() async {
        guard let session = try? await SupabaseClientManager.shared.client.auth.session else {
            print("No active session")
            return
        }

        currentUserId = session.user.id.uuidString.lowercased()

        if conversationId == nil, let otherUserId = otherUserId, let currentUserId = currentUserId {
            // Normalize otherUserId to lowercase for consistent comparison
            await findOrCreateConversation(currentUserId: currentUserId, otherUserId: otherUserId.lowercased())
        }

        if conversationId != nil {
            await loadMessages()
            await subscribeToRealtime()
        }
    }

    private func findOrCreateConversation(currentUserId: String, otherUserId: String) async {
        let client = SupabaseClientManager.shared.client

        do {
            // Try to find existing conversation
            let conversations: [Conversation] = try await client.database
                .from("conversations")
                .select("*")
                .or("and(user1_id.eq.\(currentUserId),user2_id.eq.\(otherUserId)),and(user1_id.eq.\(otherUserId),user2_id.eq.\(currentUserId))")
                .execute()
                .value

            if let existing = conversations.first {
                conversationId = existing.id
            } else {
                // Create new conversation
                let request = CreateConversationRequest(user1_id: currentUserId, user2_id: otherUserId)
                let newConversation: Conversation = try await client.database
                    .from("conversations")
                    .insert(request)
                    .select()
                    .single()
                    .execute()
                    .value

                conversationId = newConversation.id
            }
        } catch {
            print("Error finding/creating conversation:", error.localizedDescription)
        }
    }

    // MARK: - Load Messages
    private func loadMessages() async {
        guard let conversationId = conversationId else { return }

        let client = SupabaseClientManager.shared.client

        do {
            var fetchedMessages: [ChatMessage] = try await client.database
                .from("messages")
                .select("*")
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            // Mark messages from current user
            fetchedMessages = fetchedMessages.map { msg in
                var message = msg
                message.isFromCurrentUser = msg.sender_id == currentUserId
                return message
            }

            await MainActor.run {
                self.messages = fetchedMessages
                self.tableView.reloadData()
            }
        } catch {
            print("Error loading messages:", error.localizedDescription)
        }
    }

    // MARK: - Supabase Realtime
    private func subscribeToRealtime() async {
        guard let conversationId = conversationId else { return }

        let client = SupabaseClientManager.shared.client

        realtimeChannel = client.realtimeV2.channel("messages:\(conversationId)")

        let insertions = await realtimeChannel!.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversationId)"
        )

        await realtimeChannel!.subscribe()

        Task {
            for await insertion in insertions {
                await handleNewMessage(insertion)
            }
        }
    }

    private func handleNewMessage(_ action: InsertAction) async {
        do {
            var newMessage = try action.decodeRecord(as: ChatMessage.self, decoder: JSONDecoder())
            newMessage.isFromCurrentUser = newMessage.sender_id == currentUserId

            // Don't add if it's our own message (already added optimistically)
            if newMessage.sender_id == currentUserId {
                return
            }

            await MainActor.run {
                // Insert at beginning since table is reversed
                self.messages.insert(newMessage, at: 0)
                self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
            }
        } catch {
            print("Error decoding realtime message:", error.localizedDescription)
        }
    }

    private func unsubscribeFromRealtime() async {
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
    }

    // MARK: - Send Message
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        print("button tapped for messages")
        sendMessage()
    }

    private func sendMessage() {
        guard let text = messageTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              let conversationId = conversationId,
              let currentUserId = currentUserId else {
            return
        }

        messageTextField.text = ""
        sendButton.isEnabled = false

        // Optimistically add message to UI
        let tempId = UUID().uuidString
        let dateFormatter = ISO8601DateFormatter()
        let now = dateFormatter.string(from: Date())

        var optimisticMessage = ChatMessage(
            id: tempId,
            conversation_id: conversationId,
            sender_id: currentUserId,
            content: text,
            created_at: now
        )
        optimisticMessage.isFromCurrentUser = true

        messages.insert(optimisticMessage, at: 0)
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)

        Task {
            await sendMessageToServer(text: text, conversationId: conversationId, senderId: currentUserId)
        }
    }

    private func sendMessageToServer(text: String, conversationId: String, senderId: String) async {
        let client = SupabaseClientManager.shared.client

        let request = CreateMessageRequest(
            conversation_id: conversationId,
            sender_id: senderId,
            content: text
        )

        do {
            _ = try await client.database
                .from("messages")
                .insert(request)
                .execute()
        } catch {
            print("Error sending message:", error.localizedDescription)

            await MainActor.run {
                // Remove optimistic message on failure
                if let index = self.messages.firstIndex(where: { $0.content == text && $0.sender_id == senderId }) {
                    self.messages.remove(at: index)
                    self.tableView.reloadData()
                }

                let alert = UIAlertController(
                    title: "Error",
                    message: "Failed to send message. Please try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        let cellIdentifier = message.isFromCurrentUser ? "SentMessageCell" : "ReceivedMessageCell"

        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? MessageCell else {
            return UITableViewCell()
        }

        // Flip the cell back since table is flipped
        cell.transform = CGAffineTransform(scaleX: 1, y: -1)
        cell.selectionStyle = .none

        cell.configure(
            message: message.content,
            time: formatMessageTime(message.created_at),
            isFromCurrentUser: message.isFromCurrentUser
        )

        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        messageTextField.resignFirstResponder()
    }

    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if sendButton.isEnabled {
            sendMessage()
        }
        return true
    }

    // MARK: - Helpers
    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        // Since table is flipped, scroll to top to show latest
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: animated)
    }

    private func formatMessageTime(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = isoFormatter.date(from: dateString) else {
            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            guard let date = isoFormatter.date(from: dateString) else {
                return ""
            }
            return formatTime(date)
        }

        return formatTime(date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }

        return formatter.string(from: date)
    }
}

// MARK: - MessageCell
class MessageCell: UITableViewCell {

    private let bubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var bubbleLeadingConstraint: NSLayoutConstraint?
    private var bubbleTrailingConstraint: NSLayoutConstraint?
    private var timeLabelLeadingConstraint: NSLayoutConstraint?
    private var timeLabelTrailingConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        contentView.addSubview(timeLabel)

        // Bubble constraints
        bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4).isActive = true
        bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75).isActive = true

        // Message label constraints inside bubble
        messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10).isActive = true
        messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10).isActive = true
        messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14).isActive = true
        messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14).isActive = true

        // Time label vertical constraints
        timeLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 2).isActive = true
        timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4).isActive = true

        // Create bubble position constraints (will toggle based on sender)
        bubbleLeadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)

        // Create time label position constraints
        timeLabelLeadingConstraint = timeLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor)
        timeLabelTrailingConstraint = timeLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor)
    }

    func configure(message: String, time: String, isFromCurrentUser: Bool) {
        messageLabel.text = message
        timeLabel.text = time

        if isFromCurrentUser {
            bubbleView.backgroundColor = .systemBlue
            messageLabel.textColor = .white

            bubbleLeadingConstraint?.isActive = false
            bubbleTrailingConstraint?.isActive = true
            timeLabelLeadingConstraint?.isActive = false
            timeLabelTrailingConstraint?.isActive = true
        } else {
            bubbleView.backgroundColor = .systemGray5
            messageLabel.textColor = .label

            bubbleTrailingConstraint?.isActive = false
            bubbleLeadingConstraint?.isActive = true
            timeLabelTrailingConstraint?.isActive = false
            timeLabelLeadingConstraint?.isActive = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        timeLabel.text = nil

        bubbleLeadingConstraint?.isActive = false
        bubbleTrailingConstraint?.isActive = false
        timeLabelLeadingConstraint?.isActive = false
        timeLabelTrailingConstraint?.isActive = false
    }
}
