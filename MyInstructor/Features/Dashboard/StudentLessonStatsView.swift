// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Dashboard/StudentLessonStatsView.swift
// --- UPDATED: Added "Instructors" breakdown section ---

import SwiftUI

struct StudentLessonStatsView: View {
    let studentID: String
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss
    
    @State private var stats: StudentStats? = nil
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Calculating Stats...").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                } else if let stats = stats {
                    VStack(spacing: 20) {
                        
                        // MARK: - Overview Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            StatCard(title: "Lessons Taken", value: "\(stats.completedLessons)", color: .accentGreen, icon: "checkmark.circle.fill")
                            StatCard(title: "Hours Driven", value: String(format: "%.1f", stats.totalHours), color: .primaryBlue, icon: "clock.fill")
                            StatCard(title: "Cancelled", value: "\(stats.cancelledLessons)", color: .warningRed, icon: "xmark.circle.fill")
                            StatCard(title: "Topics Done", value: "\(stats.topicsCovered.count)", color: .purple, icon: "book.closed.fill")
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        Divider().padding(.horizontal)
                        
                        // MARK: - NEW: Instructors Breakdown
                        if !stats.instructorBreakdown.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Instructors")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(stats.instructorBreakdown, id: \.name) { item in
                                    HStack {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.primaryBlue)
                                            .frame(width: 24)
                                        Text(item.name)
                                            .font(.body)
                                        Spacer()
                                        Text("\(item.count) Lessons")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                }
                            }
                            Divider().padding(.horizontal)
                        }
                        
                        // MARK: - Progress by Topic
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Curriculum Progress")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Covered Topics
                            if !stats.topicsCovered.isEmpty {
                                DisclosureGroup("Completed Topics (\(stats.topicsCovered.count))") {
                                    FlowLayout(alignment: .leading, spacing: 8) {
                                        ForEach(Array(stats.topicsCovered).sorted(), id: \.self) { topic in
                                            Text(topic)
                                                .font(.caption).bold()
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.accentGreen.opacity(0.15))
                                                .foregroundColor(.accentGreen)
                                                .cornerRadius(20)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                                .padding(.horizontal)
                                .accentColor(.accentGreen)
                            }
                            
                            // Remaining Topics
                            if !stats.topicsRemaining.isEmpty {
                                DisclosureGroup(
                                    isExpanded: .constant(true),
                                    content: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(stats.topicsRemaining, id: \.self) { topic in
                                                HStack {
                                                    Image(systemName: "circle")
                                                        .foregroundColor(.secondary)
                                                        .font(.caption)
                                                    Text(topic)
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                }
                                                .padding(.vertical, 4)
                                                Divider().opacity(0.5)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    },
                                    label: {
                                        Text("What's Left (\(stats.topicsRemaining.count))")
                                            .font(.headline)
                                    }
                                )
                                .padding(.horizontal)
                                .accentColor(.primaryBlue)
                            } else {
                                HStack {
                                    Image(systemName: "star.fill").foregroundColor(.yellow)
                                    Text("You've covered all core topics!").bold()
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Lesson Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadStats()
            }
        }
    }
    
    private func loadStats() async {
        isLoading = true
        do {
            self.stats = try await dataService.fetchStudentLessonStats(for: studentID)
        } catch {
            print("Error loading stats: \(error)")
        }
        isLoading = false
    }
}

// Simple Stat Card for the Grid
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(15)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}
