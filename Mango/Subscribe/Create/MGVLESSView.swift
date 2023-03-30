import SwiftUI

struct MGVLESSView: View {
    
    @ObservedObject private var vm: MGConfigurationEditViewModel
    
    init(vm: MGConfigurationEditViewModel) {
        self._vm = ObservedObject(initialValue: vm)
    }
    
    var body: some View {
        LabeledContent("Address") {
            TextField("", text: $vm.model.vless.address)
        }
        LabeledContent("Port") {
            TextField("", value: $vm.model.vless.port, format: .number)
        }
        LabeledContent("UUID") {
            TextField("", text: $vm.model.vless.user.id)
        }
        LabeledContent("Encryption") {
            TextField("", text: $vm.model.vless.user.encryption)
        }
        LabeledContent("Flow") {
            Picker("Flow", selection: $vm.model.vless.user.flow) {
                ForEach(MGConfiguration.Outbound.VLESSSettings.Flow.allCases) { encryption in
                    Text(encryption.description)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}
