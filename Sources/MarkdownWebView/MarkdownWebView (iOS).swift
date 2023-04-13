#if os(iOS)

import SwiftUI
import WebKit

@available(iOS 14.0, *)
public struct MarkdownWebView: UIViewRepresentable {
    let markdownContent: String
    
    public init(_ markdownContent: String) {
        self.markdownContent = markdownContent
    }
    
    public func makeCoordinator() -> Coordinator { .init(parent: self) }
    
    public func makeUIView(context: Context) -> CustomWebView { context.coordinator.uiView }
    
    public func updateUIView(_ uiView: CustomWebView, context: Context) {
        guard !uiView.isLoading else { return } /// This function might be called when the page is still loading, at which time `window.proxy` is not available yet.
        uiView.updateMarkdownContent(self.markdownContent)
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: MarkdownWebView
        let uiView: CustomWebView
        
        init(parent: MarkdownWebView) {
            self.parent = parent
            
            let webViewConfiguration: WKWebViewConfiguration = .init()
            self.uiView = .init(frame: .zero, configuration: webViewConfiguration)
            
            super.init()
            
            self.uiView.navigationDelegate = self
            self.uiView.uiDelegate = self
            
            self.uiView.scrollView.isScrollEnabled = false
            self.uiView.setContentHuggingPriority(.required, for: .vertical)
            
            let pageFileURL = Bundle.module.url(forResource: "page", withExtension: "html")!
            self.uiView.loadFileURL(pageFileURL, allowingReadAccessTo: pageFileURL)
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            (webView as! CustomWebView).updateMarkdownContent(self.parent.markdownContent)
        }
    }
    
    public class CustomWebView: WKWebView {
        var contentHeight: Double = 0
        
        public override var intrinsicContentSize: CGSize {
            let width = super.intrinsicContentSize.width
            return .init(width: width, height: self.contentHeight)
        }
        
        func updateMarkdownContent(_ markdownContent: String) {
            self.callAsyncJavaScript("window.proxy.markdownContent = `\(markdownContent.replacingOccurrences(of: "`", with: "\\`"))`", in: nil, in: .page, completionHandler: nil)
            
            self.evaluateJavaScript("document.body.scrollHeight", in: nil, in: .page) { result in
                guard let contentHeight = try? result.get() as? Double else { return }
                self.contentHeight = contentHeight
                self.invalidateIntrinsicContentSize()
            }
        }
    }
}

#endif
