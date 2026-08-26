import SwiftUI

struct SegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    init(_ options: [Option], selection: Binding<Option>, label: @escaping (Option) -> String) {
        self.options = options
        _selection = selection
        self.label = label
    }

    var body: some View {
        Picker(selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(label(option))
                    .tag(option)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

private struct SegmentedControlPreview: View {
    @State private var selection = "Foods"

    var body: some View {
        SegmentedControl(["Foods", "Restaurants"], selection: $selection) { $0 }
            .padding()
            .background(AppPalette.paper)
    }
}

#Preview { SegmentedControlPreview() }
