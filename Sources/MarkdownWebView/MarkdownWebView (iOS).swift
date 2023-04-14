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
            
            #if DEBUG
            if #available(iOS 16.4, *) {
                self.uiView.isInspectable = true
            }
            #endif
            
            self.uiView.navigationDelegate = self
            self.uiView.uiDelegate = self
            
            self.uiView.scrollView.isScrollEnabled = false
            self.uiView.setContentHuggingPriority(.required, for: .vertical)
            self.uiView.isOpaque = false
            
            guard let templateFileURL = Bundle.module.url(forResource: "template", withExtension: ""),
                  let templateString = try? String(contentsOf: templateFileURL),
                  let scriptFileURL = Bundle.module.url(forResource: "script", withExtension: ""),
                  let scriptString = try? String(contentsOf: scriptFileURL),
                  let stylesheetFileURL = Bundle.module.url(forResource: "default-iOS", withExtension: ""),
                  let stylesheetString = try? String(contentsOf: stylesheetFileURL)
            else { return }
            let htmlString = templateString
                .replacingOccurrences(of: "PLACEHOLDER_SCRIPT", with: scriptString)
                .replacingOccurrences(of: "PLACEHOLDER_STYLESHEET", with: stylesheetString)
            self.uiView.loadHTMLString(htmlString, baseURL: nil)
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
            guard let markdownContentBase64Encoded = markdownContent.data(using: .utf8)?.base64EncodedString() else { return }
            
            self.callAsyncJavaScript("window.updateWithMarkdownContentBase64Encoded(`\(markdownContentBase64Encoded)`)", in: nil, in: .page, completionHandler: nil)
            
            self.evaluateJavaScript("document.body.scrollHeight", in: nil, in: .page) { result in
                guard let contentHeight = try? result.get() as? Double else { return }
                self.contentHeight = contentHeight
                self.invalidateIntrinsicContentSize()
            }
        }
    }
}

#endif
