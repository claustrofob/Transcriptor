import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TranslationView()
                .tabItem {
                    Label("Translate", systemImage: "text.bubble")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainTabView()
}
