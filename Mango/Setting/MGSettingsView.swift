import SwiftUI

struct MGSettingsView: View {
            
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MGNetworkEntranceView()
                } header: {
                    Text("系统")
                }
                Section {
                    MGLogEntranceView()
                    MGInboundEntranceView()
                    MGDNSEntranceView()
                    MGRouteEntranceView()
                    MGAssetEntranceView()
                } header: {
                    Text("内核")
                }
                Section {
                    LabeledContent {
                        Text(Bundle.appVersion)
                            .monospacedDigit()
                    } label: {
                        Label("应用", systemImage: "app")
                    }
                    LabeledContent {
                        Text("1.8.0")
                            .monospacedDigit()
                    } label: {
                        Label("内核", systemImage: "app.fill")
                    }
                } header: {
                    Text("版本")
                }
                Section {
                    MGResetView()
                }
            }
            .navigationTitle(Text("设置"))
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
