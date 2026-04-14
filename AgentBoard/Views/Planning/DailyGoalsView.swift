import SwiftUI
import SwiftData

struct DailyGoalsView: View {
    @Query var goals: [DailyGoal]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddGoal = false
    
    var todayGoals: [DailyGoal] {
        let calendar = Calendar.current
        return goals.filter { calendar.isDate($0.date, inSameDayAs: Date()) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var completedCount: Int {
        todayGoals.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Goals")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if !todayGoals.isEmpty {
                        Text("\(completedCount)/\(todayGoals.count) completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    showingAddGoal = true
                } label: {
                    Label("Add Goal", systemImage: "plus")
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Progress bar
            if !todayGoals.isEmpty {
                ProgressView(value: Double(completedCount), total: Double(todayGoals.count))
                    .padding(.horizontal)
            }
            
            // Goals list
            ScrollView {
                if todayGoals.isEmpty {
                    emptyState
                } else {
                    goalsList
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalSheet()
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No goals for today")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Add your first goal to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button("Add Goal") {
                showingAddGoal = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private var goalsList: some View {
        let grouped = Dictionary(grouping: todayGoals) { $0.project }
        
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(grouped.keys.sorted()), id: \.self) { project in
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.capitalized)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    ForEach(grouped[project] ?? []) { goal in
                        GoalRow(goal: goal)
                    }
                }
            }
        }
        .padding(.vertical)
    }
}

struct GoalRow: View {
    let goal: DailyGoal
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    if goal.isCompleted {
                        goal.markIncomplete()
                    } else {
                        goal.markComplete()
                    }
                }
            } label: {
                Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(goal.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .strikethrough(goal.isCompleted)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    if let agent = goal.assignedAgent {
                        Label(agent.capitalized, systemImage: "person")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if goal.linkedIssueNumber != nil {
                        Label("Linked Issue", systemImage: "link")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            Spacer()
            
            Button {
                modelContext.delete(goal)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var description = ""
    @State private var project = "netmonitor"
    @State private var assignedAgent: String? = nil
    
    let projects = ["netmonitor", "growwise", "agentboard"]
    let agents = [nil, "hermes", "claude", "codex"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Assignment") {
                    Picker("Project", selection: $project) {
                        ForEach(projects, id: \.self) { Text($0.capitalized) }
                    }
                    
                    Picker("Assign to", selection: $assignedAgent) {
                        Text("Blake (Human)").tag(nil as String?)
                        Text("Hermes").tag("hermes" as String?)
                        Text("Claude Code").tag("claude" as String?)
                        Text("Codex").tag("codex" as String?)
                    }
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let goal = DailyGoal(
                            title: title,
                            goalDescription: description,
                            project: project,
                            assignedAgent: assignedAgent
                        )
                        modelContext.insert(goal)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 400)
    }
}
