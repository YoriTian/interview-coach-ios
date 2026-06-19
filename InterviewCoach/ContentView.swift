import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("首页", systemImage: "house")
                }
                .tag(0)

            QuestionBankView(selectedTab: $selectedTab)
                .tabItem {
                    Label("题库", systemImage: "books.vertical")
                }
                .tag(1)

            PracticeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("面试", systemImage: "mic")
                }
                .tag(2)

            ReviewView(selectedTab: $selectedTab)
                .tabItem {
                    Label("复盘", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
                .tag(4)
        }
        .environmentObject(viewModel)
        .onChange(of: selectedTab) { _, _ in
            KeyboardDismissal.dismiss()
        }
        .task {
            await viewModel.loadQuestionBankIfNeeded()
        }
    }
}
