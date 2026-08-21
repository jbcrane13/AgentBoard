import Foundation

/// `KanbanCLIWriting` conformer that mutates a **remote** Hermes dashboard
/// over its bundled kanban plugin API instead of shelling out to the local
/// `hermes` CLI. `KanbanCLIWriter` (the process-spawning conformer) is
/// untouched — this is an alternate implementation of the same protocol,
/// selected alongside `HTTPKanbanBackend` whenever a remote-gateway profile
/// is active, so writes land on the same host the board was read from.
///
/// Endpoint mapping (verified against the live OpenAPI schema and
/// `plugins/kanban/dashboard/plugin_api.py`):
///  - `create`   -> `POST tasks` `{title, body?, assignee?, priority, tenant?, parents}`, decodes `{"task": {...}}`
///  - `comment`  -> `POST tasks/{id}/comments` `{body}`
///  - `complete` -> `PATCH tasks/{id}` `{status:"done", summary}`
///  - `block`    -> `PATCH tasks/{id}` `{status:"blocked", block_reason}`
///  - `unblock`  -> `PATCH tasks/{id}` `{status:"ready"}`
///  - `promote`  -> `PATCH tasks/{id}` `{status:"ready"}`
///  - `archive`  -> `PATCH tasks/{id}` `{status:"archived"}`
///  - `assign`   -> `PATCH tasks/{id}` `{assignee}`
///
/// Two divergences from `KanbanCLIWriter` worth recording:
///  1. `promote` has no dedicated endpoint. `PATCH {status:"ready"}` reaches
///     the plugin's `_set_status_direct` for a todo/triage task, which skips
///     `kanban_db.promote_task`'s parent-dependency guard and its audit-trail
///     event. That is exactly what the dashboard's own board drag does, and
///     it is the only route the plugin API offers — there is no way to ask a
///     remote dashboard to enforce the guard from here.
///  2. `unblock` and `promote` therefore issue an identical request. They
///     stay separate methods because `KanbanCLIWriting` (and the
///     `KanbanBoardMove` it backs) distinguishes them semantically even
///     though this backend cannot.
public actor HTTPKanbanWriter: KanbanCLIWriting {
    private let client: HermesDashboardClient

    public init(client: HermesDashboardClient) {
        self.client = client
    }

    // MARK: - Create

    public func create(_ draft: KanbanCreateDraft) async throws -> KanbanTask {
        let body = CreateTaskRequest(
            title: draft.title,
            body: draft.body,
            assignee: draft.assignee,
            priority: draft.priority,
            tenant: draft.tenant,
            parents: draft.parentIDs
        )
        let response = try await client.post(
            "api/plugins/kanban/tasks",
            body: body,
            as: CreateTaskResponse.self
        )
        guard let task = response.task?.toKanbanTask() else {
            throw HermesDashboardClient.DashboardError.decodingFailed(
                "api/plugins/kanban/tasks: response carried no usable \"task\""
            )
        }
        return task
    }

    // MARK: - Comment

    public func comment(taskID: String, body: String) async throws {
        _ = try await client.post(
            "api/plugins/kanban/tasks/\(taskID)/comments",
            body: CommentRequest(body: body),
            as: EmptyResponse.self
        )
    }

    // MARK: - Complete

    public func complete(taskID: String, summary: String) async throws {
        try await patch(taskID: taskID, status: "done", summary: summary)
    }

    // MARK: - Block / Unblock

    public func block(taskID: String, reason: String) async throws {
        try await patch(taskID: taskID, status: "blocked", blockReason: reason)
    }

    public func unblock(taskID: String) async throws {
        try await patch(taskID: taskID, status: "ready")
    }

    // MARK: - Promote

    /// See the type-level doc comment: this issues the exact same request as
    /// `unblock`, because the plugin API has no dedicated promote endpoint.
    public func promote(taskID: String) async throws {
        try await patch(taskID: taskID, status: "ready")
    }

    // MARK: - Archive

    public func archive(taskID: String) async throws {
        try await patch(taskID: taskID, status: "archived")
    }

    // MARK: - Assign

    public func assign(taskID: String, assignee: String) async throws {
        try await patch(taskID: taskID, assignee: assignee)
    }

    // MARK: - Requests

    private func patch(
        taskID: String,
        status: String? = nil,
        summary: String? = nil,
        blockReason: String? = nil,
        assignee: String? = nil
    ) async throws {
        let body = UpdateTaskRequest(status: status, summary: summary, blockReason: blockReason, assignee: assignee)
        _ = try await client.patch(
            "api/plugins/kanban/tasks/\(taskID)",
            body: body,
            as: EmptyResponse.self
        )
    }
}

// MARK: - Request DTOs

/// `title`/`priority`/`parents` are always sent; the rest are omitted
/// entirely (not sent as `null`) when absent, matching what the dashboard
/// SPA itself sends.
private struct CreateTaskRequest: Encodable {
    let title: String
    let body: String?
    let assignee: String?
    let priority: Int
    let tenant: String?
    let parents: [String]

    enum CodingKeys: String, CodingKey {
        case title, body, assignee, priority, tenant, parents
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(assignee, forKey: .assignee)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(tenant, forKey: .tenant)
        try container.encode(parents, forKey: .parents)
    }
}

private struct CommentRequest: Encodable {
    let body: String
}

/// Backs every status-mutating call (`complete`/`block`/`unblock`/`promote`/
/// `archive`/`assign`). `UpdateTaskBody` on the server treats a
/// present-but-null field as "no change", so unused fields must be omitted
/// entirely rather than encoded as `null` — `encodeIfPresent` throughout.
private struct UpdateTaskRequest: Encodable {
    let status: String?
    let summary: String?
    let blockReason: String?
    let assignee: String?

    enum CodingKeys: String, CodingKey {
        case status, summary
        case blockReason = "block_reason"
        case assignee
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(blockReason, forKey: .blockReason)
        try container.encodeIfPresent(assignee, forKey: .assignee)
    }
}

// MARK: - Response DTOs

private struct CreateTaskResponse: Decodable {
    let task: DashboardTask?
}

/// Every mutation endpoint returns a JSON body (the updated task, a comment
/// record, etc.), but no caller here needs it — `KanbanCLIWriting`'s
/// non-create methods return `Void`. Decoding into this rather than adding a
/// Data-returning API to `HermesDashboardClient` still confirms the response
/// was valid JSON. The synthesized `init(from:)` for a zero-property struct
/// touches nothing on the decoder, so it accepts any well-formed payload.
private struct EmptyResponse: Decodable {}
