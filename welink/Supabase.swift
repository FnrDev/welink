//
//  Supabase.swift
//  auth-example
//
//  Created by Ahmed on 17/11/2025.
//

import Foundation
import Supabase

class SupabaseClientManager {
    static let shared = SupabaseClientManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://mjzyqwziqqhcdrdadfpc.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qenlxd3ppcXFoY2RyZGFkZnBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzMDczMTYsImV4cCI6MjA3ODg4MzMxNn0.2iBw3VrohCK6zPBcJPj4LqWhPJ60ycZNoUCaf06s1DI"
        )
    }
}

final class AdminLogService {
    static let shared = AdminLogService()

    private init() {}

    private struct CreateAdminLogPayload: Encodable {
        let action: String
        let target_user_id: String?
        let metadata: [String: String]?
    }

    private struct OkResponse: Decodable {
        let ok: Bool
    }

    func log(action: String, targetUserId: String? = nil, metadata: [String: String]? = nil) async {
        let trimmedAction = action.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAction.isEmpty else { return }

        do {
            let _: OkResponse = try await SupabaseClientManager.shared.client.functions
                .invoke(
                    "admin-add-log",
                    options: FunctionInvokeOptions(body: CreateAdminLogPayload(action: trimmedAction, target_user_id: targetUserId, metadata: metadata))
                )
        } catch {
            print("❌ Failed to write admin log: \(error)")
        }
    }
}
