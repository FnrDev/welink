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
