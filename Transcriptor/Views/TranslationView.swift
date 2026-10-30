import SwiftUI
import TranscriptorKit

struct TranslationView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            TranslationScreen()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gear") {
                            showSettings = true
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
        }
    }
}

#Preview {
    TranslationView()
}
