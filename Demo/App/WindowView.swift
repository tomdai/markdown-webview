import SwiftUI
import MarkdownWebView

struct WindowView: View {
    @State private var text: String = """
    # Heading 1
    
    ## Heading 2
    
    | Column 1 | Column 2 |
    | -------- | -------- |
    | Cell     | Cell     |
    | Cell     | Cell     |
    | Cell     | Cell     |
    | Cell     | Cell     |
    """
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    MarkdownWebView(self.text)
                    .border(.red)
                }
                .listStyle(.sidebar)
                Spacer(minLength: 0)
                TextEditor(text: self.$text)
                    .frame(height: 100)
                    .padding()
                    .background(.background)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        WindowView()
    }
}
