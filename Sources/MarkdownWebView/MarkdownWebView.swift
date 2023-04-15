import SwiftUI
import WebKit

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#elseif os(iOS)
typealias PlatformViewRepresentable = UIViewRepresentable
#endif

@available(macOS 11.0, iOS 14.0, *)
public struct MarkdownWebView: PlatformViewRepresentable {
    let markdownContent: String
    let linkActivationHandler: ((URL) -> Void)?
    
    public init(_ markdownContent: String, onLinkActivation linkActivationHandler: ((URL) -> Void)? = nil) {
        self.markdownContent = markdownContent
        self.linkActivationHandler = linkActivationHandler
    }
    
    public func makeCoordinator() -> Coordinator { .init(parent: self) }
    
    #if os(macOS)
    public func makeNSView(context: Context) -> CustomWebView { context.coordinator.platformView }
    #elseif os(iOS)
    public func makeUIView(context: Context) -> CustomWebView { context.coordinator.platformView }
    #endif
    
    func updatePlatformView(_ platformView: CustomWebView, context: Context) {
        guard !platformView.isLoading else { return } /// This function might be called when the page is still loading, at which time `window.proxy` is not available yet.
        platformView.updateMarkdownContent(self.markdownContent)
    }
    
    #if os(macOS)
    public func updateNSView(_ nsView: CustomWebView, context: Context) { self.updatePlatformView(nsView, context: context) }
    #elseif os(iOS)
    public func updateUIView(_ uiView: CustomWebView, context: Context) { self.updatePlatformView(uiView, context: context) }
    #endif
    
    public class Coordinator: NSObject, WKNavigationDelegate {
        let parent: MarkdownWebView
        let platformView: CustomWebView
        
        init(parent: MarkdownWebView) {
            self.parent = parent
            
            let webViewConfiguration: WKWebViewConfiguration = .init()
            self.platformView = .init(frame: .zero, configuration: webViewConfiguration)
            
            super.init()
            
            self.platformView.navigationDelegate = self
            
            #if DEBUG && os(iOS)
            if #available(iOS 16.4, *) {
                self.platformView.isInspectable = true
            }
            #endif
            
            /// So that the `View` adjusts its height automatically.
            self.platformView.setContentHuggingPriority(.required, for: .vertical)
            
            /// Disables scrolling.
            #if os(iOS)
            self.platformView.scrollView.isScrollEnabled = false
            #endif
            
            /// Set transparent background.
            #if os(macOS)
            self.platformView.setValue(true, forKey: "drawsTransparentBackground")
            #elseif os(iOS)
            self.platformView.isOpaque = false
            #endif
            
            #if os(macOS)
            let stylesheetFileName = "default-macOS"
            #elseif os(iOS)
            let stylesheetFileName = "default-iOS"
            #endif
            guard let templateFileURL = Bundle.module.url(forResource: "template", withExtension: ""),
                  let templateString = try? String(contentsOf: templateFileURL),
                  let scriptFileURL = Bundle.module.url(forResource: "script", withExtension: ""),
                  let scriptString = try? String(contentsOf: scriptFileURL),
                  let stylesheetFileURL = Bundle.module.url(forResource: stylesheetFileName, withExtension: ""),
                  let stylesheetString = try? String(contentsOf: stylesheetFileURL)
            else { return }
            let htmlString = templateString
                .replacingOccurrences(of: "PLACEHOLDER_SCRIPT", with: scriptString)
                .replacingOccurrences(of: "PLACEHOLDER_STYLESHEET", with: stylesheetString)
            self.platformView.loadHTMLString(htmlString, baseURL: nil)
        }
        
        /// Update the content on first finishing loading.
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            (webView as! CustomWebView).updateMarkdownContent(self.parent.markdownContent)
        }
        
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated {
                guard let url = navigationAction.request.url else { return .cancel }
                
                if let linkActivationHandler = self.parent.linkActivationHandler {
                    linkActivationHandler(url)
                } else {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #elseif os(iOS)
                    DispatchQueue.main.async {
                        Task { await UIApplication.shared.open(url) }
                    }
                    #endif
                }
                
                return .cancel
            } else {
                return .allow
            }
        }
    }
    
    public class CustomWebView: WKWebView {
        var contentHeight: Double = 0
        
        public override var intrinsicContentSize: CGSize {
            .init(width: super.intrinsicContentSize.width, height: self.contentHeight)
        }
        
        /// Disables scrolling.
        #if os(macOS)
        public override func scrollWheel(with event: NSEvent) {
            if event.deltaY == 0 {
                super.scrollWheel(with: event)
            } else {
                self.nextResponder?.scrollWheel(with: event)
            }
        }
        #endif
        
        /// Removes "Reload" from the context menu.
        #if os(macOS)
        public override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
            menu.items.removeAll { $0.identifier == .init("WKMenuItemIdentifierReload") }
        }
        #endif
        
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
