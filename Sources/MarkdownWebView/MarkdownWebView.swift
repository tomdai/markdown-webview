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
    let customStylesheet: String?
    let linkActivationHandler: ((URL) -> Void)?
    let renderedContentHandler: ((String) -> Void)?
    
    public init(_ markdownContent: String, customStylesheet: String? = nil) {
        self.markdownContent = markdownContent
        self.customStylesheet = customStylesheet
        self.linkActivationHandler = nil
        self.renderedContentHandler = nil
    }
    
    internal init(_ markdownContent: String, customStylesheet: String?, linkActivationHandler: ((URL) -> Void)?, renderedContentHandler: ((String) -> Void)?) {
        self.markdownContent = markdownContent
        self.customStylesheet = customStylesheet
        self.linkActivationHandler = linkActivationHandler
        self.renderedContentHandler = renderedContentHandler
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
//        platformView.addCopyButtons()
    }
    
    #if os(macOS)
    public func updateNSView(_ nsView: CustomWebView, context: Context) { self.updatePlatformView(nsView, context: context) }
    #elseif os(iOS)
    public func updateUIView(_ uiView: CustomWebView, context: Context) { self.updatePlatformView(uiView, context: context) }
    #endif
    
    public func onLinkActivation(_ linkActivationHandler: @escaping (URL) -> Void) -> Self {
        .init(self.markdownContent, customStylesheet: self.customStylesheet, linkActivationHandler: linkActivationHandler, renderedContentHandler: self.renderedContentHandler)
    }
    
    public func onRendered(_ renderedContentHandler: @escaping (String) -> Void) -> Self {
        .init(self.markdownContent, customStylesheet: self.customStylesheet, linkActivationHandler: self.linkActivationHandler, renderedContentHandler: renderedContentHandler)
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: MarkdownWebView
        let platformView: CustomWebView
        
        init(parent: MarkdownWebView) {
            self.parent = parent
            self.platformView = .init()
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
            self.platformView.setValue(false, forKey: "drawsBackground")
            /// Equavalent to `.setValue(true, forKey: "drawsTransparentBackground")` on macOS 10.12 and before, which this library doesn't target.
            #elseif os(iOS)
            self.platformView.isOpaque = false
            #endif
            
            /// Receive messages from the web view.
            self.platformView.configuration.userContentController = .init()
            self.platformView.configuration.userContentController.add(self, name: "sizeChangeHandler")
            self.platformView.configuration.userContentController.add(self, name: "renderedContentHandler")
            
            #if os(macOS)
            let defaultStylesheetFileName = "default-macOS"
            #elseif os(iOS)
            let defaultStylesheetFileName = "default-iOS"
            #endif
            guard let templateFileURL = Bundle.module.url(forResource: "template", withExtension: ""),
                  let templateString = try? String(contentsOf: templateFileURL),
                  let scriptFileURL = Bundle.module.url(forResource: "script", withExtension: ""),
                  let script = try? String(contentsOf: scriptFileURL),
                  let defaultStylesheetFileURL = Bundle.module.url(forResource: defaultStylesheetFileName, withExtension: ""),
                  let defaultStylesheet = try? String(contentsOf: defaultStylesheetFileURL)
            else { return }
            let htmlString = templateString
                .replacingOccurrences(of: "PLACEHOLDER_SCRIPT", with: script)
                .replacingOccurrences(of: "PLACEHOLDER_STYLESHEET", with: self.parent.customStylesheet ?? defaultStylesheet)
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
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "sizeChangeHandler":
                guard let contentHeight = message.body as? CGFloat,
                      self.platformView.contentHeight != contentHeight
                else { return }
                self.platformView.contentHeight = contentHeight
                self.platformView.invalidateIntrinsicContentSize()
            case "renderedContentHandler":
                guard let renderedContentHandler = self.parent.renderedContentHandler,
                      let renderedContentBase64Encoded = message.body as? String,
                      let renderedContentBase64EncodedData: Data = .init(base64Encoded: renderedContentBase64Encoded),
                      let renderedContent = String(data: renderedContentBase64EncodedData, encoding: .utf8)
                else { return }
                renderedContentHandler(renderedContent)
            default:
                return
            }
        }
    }
    
    public class CustomWebView: WKWebView {
        var contentHeight: CGFloat = 0
        
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
        }
        
//        func addCopyButtons() {
//            let jsFunction = """
//            function addCopyButtons() {
//                const codeBlocks = document.querySelectorAll('pre');
//                codeBlocks.forEach((codeBlock) => {
//                    const button = document.createElement('button');
//                    button.textContent = 'Copy Code';
//                    button.addEventListener('click', async () => {
//                       await navigator.clipboard.writeText(codeBlock.textContent);
//                       button.textContent = 'Copied!';
//                       setTimeout(() => { button.textContent = 'Copy Code'; }, 2000);
//                    });
//                    codeBlock.parentNode.insertBefore(button, codeBlock.nextSibling);
//                });
//            }
//            """
//            evaluateJavaScript(jsFunction, completionHandler: nil)
//        }
    }
}
