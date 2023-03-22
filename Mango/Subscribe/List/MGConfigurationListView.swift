import SwiftUI

fileprivate extension MGConfiguration {
    
    var isUserCreated: Bool {
        self.attributes.source.scheme.flatMap(MGConfiguration.ProtocolType.init(rawValue:)) != nil
    }
    
    var isLocal: Bool {
        self.attributes.source.isFileURL || self.isUserCreated
    }
}

struct IdentifiableWrapper<Object>: Identifiable {
    
    let id: String
    let obj: Object
    
    init(id: String, obj: Object) {
        self.id = id
        self.obj = obj
    }
}

struct MGConfigurationListView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject private var packetTunnelManager: MGPacketTunnelManager
    @EnvironmentObject private var configurationListManager: MGConfigurationListManager
        
    @State private var isRenameAlertPresented = false
    @State private var configurationName: String = ""
    
    @State private var editInfoWrapper: IdentifiableWrapper<(MGConfiguration.ProtocolType, MGProtocolModel)>?
    
    @State private var location: MGConfigurationLocation?
    
    @State private var isConfirmationDialogPresented = false
    @State private var protocolType: MGConfiguration.ProtocolType?
    
    let current: Binding<String>
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isConfirmationDialogPresented.toggle()
                    } label: {
                        Label("创建", systemImage: "square.and.pencil")
                    }
                    Button {
                        
                    } label: {
                        Label("扫描二维码", systemImage: "qrcode.viewfinder")
                    }
                    .confirmationDialog("", isPresented: $isConfirmationDialogPresented) {
                        ForEach(MGConfiguration.ProtocolType.allCases) { value in
                            Button(value.description) {
                                protocolType = value
                            }
                        }
                    }
                    .fullScreenCover(item: $protocolType, onDismiss: { configurationListManager.reload() }) { protocolType in
                        MGCreateConfigurationView(vm: MGCreateConfigurationViewModel(protocolType: protocolType))
                    }
                } header: {
                    Text("创建配置")
                }
                Section {
                    Button {
                        location = .remote
                    } label: {
                        Label("从 URL 下载", systemImage: "square.and.arrow.down.on.square")
                    }
                    Button {
                        location = .local
                    } label: {
                        Label("从文件夹导入", systemImage: "tray.and.arrow.down")
                    }
                } header: {
                    HStack {
                        Text("导入自定义配置")
                        Spacer()
                        Button {
                            
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                    }
                }
                Section {
                    if configurationListManager.configurations.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 20) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.largeTitle)
                                Text("暂无配置")
                            }
                            .foregroundColor(.secondary)
                            .padding()
                            Spacer()
                        }
                    } else {
                        ForEach(configurationListManager.configurations) { configuration in
                            HStack(alignment: .center, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(configuration.attributes.alias)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                        .fontWeight(.medium)
                                    TimelineView(.periodic(from: Date(), by: 1)) { _ in
                                        Text(configuration.attributes.leastUpdated.formatted(.relative(presentation: .numeric)))
                                            .lineLimit(1)
                                            .foregroundColor(.secondary)
                                            .font(.callout)
                                            .fontWeight(.light)
                                    }
                                }
                                Spacer()
                                if configurationListManager.downloadingConfigurationIDs.contains(configuration.id) {
                                    ProgressView()
                                }
                            }
                            .contextMenu {
                                RenameOrEditButton(configuration: configuration)
                                UpdateButton(configuration: configuration)
                                Divider()
                                DeleteButton(configuration: configuration)
                            }
                        }
                    }
                } header: {
                    Text("配置列表")
                }
            }
            .navigationTitle(Text("配置管理"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $location) { location in
                MGConfigurationLoadView(location: location)
            }
            .fullScreenCover(item: $editInfoWrapper) { wrapper in
                MGCreateConfigurationView(vm: MGCreateConfigurationViewModel(protocolType: wrapper.obj.0, protocolModel: wrapper.obj.1))
            }
        }
    }
    
    @ViewBuilder
    private func RenameOrEditButton(configuration: MGConfiguration) -> some View {
        Button {
            if configuration.isUserCreated {
                do {
                    guard let prototolType = configuration.attributes.source.scheme.flatMap(MGConfiguration.ProtocolType.init(rawValue:)) else {
                        return
                    }
                    let data = try Data(contentsOf: MGConstant.assetDirectory.appending(component: "\(configuration.id)/config.\(MGConfigurationFormat.json.rawValue)"))
                    let prototolModel = try JSONDecoder().decode(MGProtocolModel.self, from: data)
                    self.editInfoWrapper = IdentifiableWrapper(id: configuration.id, obj: (prototolType, prototolModel))
                } catch {
                    MGNotification.send(title: "", subtitle: "", body: "加载文件失败, 原因: \(error.localizedDescription)")
                }
            } else {
                self.configurationName = configuration.attributes.alias
                self.isRenameAlertPresented.toggle()
            }
        } label: {
            Label(configuration.isUserCreated ? "编辑" : "重命名", systemImage: "square.and.pencil")
        }
        .alert("重命名", isPresented: $isRenameAlertPresented) {
            TextField("请输入配置名称", text: $configurationName)
            Button("确定") {
                let name = configurationName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !(name == configuration.attributes.alias || name.isEmpty) else {
                    return
                }
                do {
                    try configurationListManager.rename(configuration: configuration, name: name)
                } catch {
                    MGNotification.send(title: "", subtitle: "", body: "重命名失败, 原因: \(error.localizedDescription)")
                }
            }
            Button("取消", role: .cancel) {}
        }
    }
    
    @ViewBuilder
    private func UpdateButton(configuration: MGConfiguration) -> some View {
        Button {
            Task(priority: .userInitiated) {
                do {
                    try await configurationListManager.update(configuration: configuration)
                    MGNotification.send(title: "", subtitle: "", body: "\"\(configuration.attributes.alias)\"更新成功")
                    if configuration.id == current.wrappedValue {
                        guard let status = packetTunnelManager.status, status == .connected else {
                            return
                        }
                        packetTunnelManager.stop()
                        do {
                            try await packetTunnelManager.start()
                        } catch {
                            debugPrint(error.localizedDescription)
                        }
                    }
                } catch {
                    MGNotification.send(title: "", subtitle: "", body: "\"\(configuration.attributes.alias)\"更新失败, 原因: \(error.localizedDescription)")
                }
            }
        } label: {
            Label("更新", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(configurationListManager.downloadingConfigurationIDs.contains(configuration.id) || configuration.isLocal)
    }
    
    @ViewBuilder
    private func DeleteButton(configuration: MGConfiguration) -> some View {
        Button(role: .destructive) {
            do {
                try configurationListManager.delete(configuration: configuration)
                MGNotification.send(title: "", subtitle: "", body: "\"\(configuration.attributes.alias)\"删除成功")
                if configuration.id == current.wrappedValue {
                    current.wrappedValue = ""
                    packetTunnelManager.stop()
                }
            } catch {
                MGNotification.send(title: "", subtitle: "", body: "\"\(configuration.attributes.alias)\"删除失败, 原因: \(error.localizedDescription)")
            }
        } label: {
            Label("删除", systemImage: "trash")
        }
        .disabled(configurationListManager.downloadingConfigurationIDs.contains(configuration.id))
    }
}
