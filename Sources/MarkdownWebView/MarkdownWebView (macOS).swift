#if os(macOS)

import SwiftUI
import WebKit

@available(macOS 11.0, *)
public struct MarkdownWebView: NSViewRepresentable {
    let markdownContent: String
    
    public init(_ markdownContent: String) {
        self.markdownContent = markdownContent
    }
    
    public func makeCoordinator() -> Coordinator { .init(parent: self) }
    
    public func makeNSView(context: Context) -> CustomWebView { context.coordinator.nsView }
    
    public func updateNSView(_ nsView: CustomWebView, context: Context) {
        guard !nsView.isLoading else { return } /// This function might be called when the page is still loading, at which time `window.proxy` is not available yet.
        nsView.updateMarkdownContent(self.markdownContent)
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: MarkdownWebView
        let nsView: CustomWebView
        
        init(parent: MarkdownWebView) {
            self.parent = parent
            
            let webViewConfiguration: WKWebViewConfiguration = .init()
            self.nsView = .init(frame: .zero, configuration: webViewConfiguration)
            
            super.init()
            
            self.nsView.navigationDelegate = self
            self.nsView.uiDelegate = self
            self.nsView.setContentHuggingPriority(.required, for: .vertical)
            
            self.nsView.setValue(true, forKey: "drawsTransparentBackground")
            
            let pageFileURL = Bundle.module.url(forResource: "page", withExtension: "html")!
            self.nsView.loadFileURL(pageFileURL, allowingReadAccessTo: pageFileURL)
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            (webView as! CustomWebView).updateMarkdownContent(self.parent.markdownContent)
        }
    }
    
    public class CustomWebView: WKWebView {
        var contentHeight: Double = 0
        
        public override var intrinsicContentSize: NSSize {
            let width = super.intrinsicContentSize.width
            return .init(width: width, height: self.contentHeight)
        }
        
        public override func scrollWheel(with event: NSEvent) {
            self.nextResponder?.scrollWheel(with: event)
            return
        }
        
        public override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
            menu.items.removeAll { $0.identifier == .init("WKMenuItemIdentifierReload") }
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
