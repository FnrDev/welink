//
//  AdminModerationViewController.swift
//  welink
//
//  Created by rawan on 04/01/2026.
//

import UIKit
import Foundation
import Supabase

final class AdminModerationViewController: UIViewController {

    @IBOutlet private weak var flagSegmentedControl: UISegmentedControl?
    @IBOutlet private weak var noteTextView: UITextView?
    @IBOutlet private weak var saveButton: UIButton?

    var targetId: String?

    private struct ModerationRow: Decodable {
        let id: String
        let flag: String?
        let note: String?
        let target_id: String
    }

    private struct UpsertModerationRequest: Encodable {
        let target_id: String
        let flag: String?
        let note: String?
        let updated_at: String?
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Moderation"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didTapCancel)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(didTapSave)
        )

        Task { [weak self] in
            await self?.loadModeration()
        }
    }

    @IBAction private func saveButtonTapped(_ sender: Any) {
        didTapSave()
    }

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }

    @objc private func didTapSave() {
        guard let targetId else {
            showError(message: "No user selected")
            return
        }

        view.endEditing(true)

        let (flag, note) = currentInput()

        Task { [weak self] in
            await self?.upsertModeration(targetId: targetId, flag: flag, note: note)
        }
    }

    private func loadModeration() async {
        guard let targetId else {
            await MainActor.run {
                self.showError(message: "No user selected")
            }
            return
        }

        do {
            let rows: [ModerationRow] = try await SupabaseClientManager.shared.client.database
                .from("moderation_notes")
                .select("id, flag, note, target_id")
                .eq("target_id", value: targetId)
                .limit(1)
                .execute()
                .value

            let row = rows.first
            await MainActor.run {
                self.applyRowToUI(row)
            }
        } catch {
            await MainActor.run {
                self.showError(message: "Failed to load moderation")
            }
        }
    }

    private func upsertModeration(targetId: String, flag: String?, note: String?) async {
        let nowISO = ISO8601DateFormatter().string(from: Date())
        let payload = UpsertModerationRequest(target_id: targetId, flag: flag, note: note, updated_at: nowISO)

        do {
            try await SupabaseClientManager.shared.client.database
                .from("moderation_notes")
                .upsert(payload, onConflict: "target_id")
                .execute()

            await AdminLogService.shared.log(
                action: "Updated moderation",
                targetUserId: targetId,
                metadata: [
                    "flag": flag ?? "",
                    "note_len": "\((note ?? "").count)"
                ]
            )

            await MainActor.run {
                let alert = UIAlertController(title: "Saved", message: "Moderation saved successfully", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    self.dismiss(animated: true)
                }))
                self.present(alert, animated: true)
            }
        } catch {
            await MainActor.run {
                self.showError(message: "Failed to save moderation")
            }
        }
    }

    private func applyRowToUI(_ row: ModerationRow?) {
        let flag = row?.flag?.lowercased() ?? "none"
        flagSegmentedControl?.selectedSegmentIndex = segmentIndex(for: flag)
        noteTextView?.text = row?.note ?? ""
    }

    private func currentInput() -> (flag: String?, note: String?) {
        let idx = flagSegmentedControl?.selectedSegmentIndex ?? 0
        let flag: String?
        switch idx {
        case 1:
            flag = "under_review"
        case 2:
            flag = "warning_issued"
        case 3:
            flag = "reported"
        default:
            flag = "none"
        }

        let note = noteTextView?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (flag, (note?.isEmpty == false) ? note : nil)
    }

    private func segmentIndex(for flag: String) -> Int {
        switch flag {
        case "under_review":
            return 1
        case "warning_issued":
            return 2
        case "reported":
            return 3
        default:
            return 0
        }
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

}
