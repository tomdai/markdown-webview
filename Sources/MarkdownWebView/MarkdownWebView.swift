import SwiftUI
import WebKit

#if os(macOS)
    typealias PlatformViewRepresentable = NSViewRepresentable
#elseif os(iOS)
    typealias PlatformViewRepresentable = UIViewRepresentable
#endif

#if !os(visionOS)
    @available(macOS 11.0, iOS 14.0, *)
    public struct MarkdownWebView: PlatformViewRepresentable {
        let markdownContent: String
        let customStylesheet: String?
        let linkActivationHandler: ((URL) -> Void)?
        let renderedContentHandler: ((String) -> Void)?

        public init(_ markdownContent: String, customStylesheet: String? = nil) {
            self.markdownContent = markdownContent
            self.customStylesheet = customStylesheet
            linkActivationHandler = nil
            renderedContentHandler = nil
        }

        init(_ markdownContent: String, customStylesheet: String?, linkActivationHandler: ((URL) -> Void)?, renderedContentHandler: ((String) -> Void)?) {
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

        func updatePlatformView(_ platformView: CustomWebView, context _: Context) {
            guard !platformView.isLoading else { return } /// This function might be called when the page is still loading, at which time `window.proxy` is not available yet.
            platformView.updateMarkdownContent(markdownContent)
        }

        #if os(macOS)
            public func updateNSView(_ nsView: CustomWebView, context: Context) { updatePlatformView(nsView, context: context) }
        #elseif os(iOS)
            public func updateUIView(_ uiView: CustomWebView, context: Context) { updatePlatformView(uiView, context: context) }
        #endif

        public func onLinkActivation(_ linkActivationHandler: @escaping (URL) -> Void) -> Self {
            .init(markdownContent, customStylesheet: customStylesheet, linkActivationHandler: linkActivationHandler, renderedContentHandler: renderedContentHandler)
        }

        public func onRendered(_ renderedContentHandler: @escaping (String) -> Void) -> Self {
            .init(markdownContent, customStylesheet: customStylesheet, linkActivationHandler: linkActivationHandler, renderedContentHandler: renderedContentHandler)
        }

        public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
            let parent: MarkdownWebView
            let platformView: CustomWebView

            init(parent: MarkdownWebView) {
                self.parent = parent
                platformView = .init()
                super.init()

                platformView.navigationDelegate = self

                #if DEBUG && os(iOS)
                    if #available(iOS 16.4, *) {
                        self.platformView.isInspectable = true
                    }
                #endif

                /// So that the `View` adjusts its height automatically.
                platformView.setContentHuggingPriority(.required, for: .vertical)

                /// Disables scrolling.
                #if os(iOS)
                    platformView.scrollView.isScrollEnabled = false
                #endif

                /// Set transparent background.
                #if os(macOS)
                    platformView.setValue(false, forKey: "drawsBackground")
                /// Equavalent to `.setValue(true, forKey: "drawsTransparentBackground")` on macOS 10.12 and before, which this library doesn't target.
                #elseif os(iOS)
                    platformView.isOpaque = false
                #endif

                /// Receive messages from the web view.
                platformView.configuration.userContentController = .init()
                platformView.configuration.userContentController.add(self, name: "sizeChangeHandler")
                platformView.configuration.userContentController.add(self, name: "renderedContentHandler")
                platformView.configuration.userContentController.add(self, name: "copyToPasteboard")

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
                platformView.loadHTMLString(htmlString, baseURL: nil)
            }

            /// Update the content on first finishing loading.
            public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
                (webView as! CustomWebView).updateMarkdownContent(parent.markdownContent)
            }

            public func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
                if navigationAction.navigationType == .linkActivated {
                    guard let url = navigationAction.request.url else { return .cancel }

                    if let linkActivationHandler = parent.linkActivationHandler {
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

            public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
                switch message.name {
                case "sizeChangeHandler":
                    guard let contentHeight = message.body as? CGFloat,
                          platformView.contentHeight != contentHeight
                    else { return }
                    platformView.contentHeight = contentHeight
                    platformView.invalidateIntrinsicContentSize()
                case "renderedContentHandler":
                    guard let renderedContentHandler = parent.renderedContentHandler,
                          let renderedContentBase64Encoded = message.body as? String,
                          let renderedContentBase64EncodedData: Data = .init(base64Encoded: renderedContentBase64Encoded),
                          let renderedContent = String(data: renderedContentBase64EncodedData, encoding: .utf8)
                    else { return }
                    renderedContentHandler(renderedContent)
                case "copyToPasteboard":
                    guard let base64EncodedString = message.body as? String else { return }
                    base64EncodedString.trimmingCharacters(in: .whitespacesAndNewlines).copyToPasteboard()
                default:
                    return
                }
            }
        }

        public class CustomWebView: WKWebView {
            var contentHeight: CGFloat = 0

            override public var intrinsicContentSize: CGSize {
                .init(width: super.intrinsicContentSize.width, height: contentHeight)
            }

            /// Disables scrolling.
            #if os(macOS)
                override public func scrollWheel(with event: NSEvent) {
                    if abs(event.deltaX) >= 1 {
                        super.scrollWheel(with: event)
                        nextResponder?.scrollWheel(with: event)
                    } else {
                        nextResponder?.scrollWheel(with: event)
                    }
                }
            #endif

            /// Removes "Reload" from the context menu.
            #if os(macOS)
                override public func willOpenMenu(_ menu: NSMenu, with _: NSEvent) {
                    menu.items.removeAll { $0.identifier == .init("WKMenuItemIdentifierReload") }
                }
            #endif

            func updateMarkdownContent(_ markdownContent: String) {
                guard let markdownContentBase64Encoded = markdownContent.data(using: .utf8)?.base64EncodedString() else { return }

                callAsyncJavaScript("window.updateWithMarkdownContentBase64Encoded(`\(markdownContentBase64Encoded)`)", in: nil, in: .page, completionHandler: nil)
            }
        }
    }
#endif

extension String {
    func copyToPasteboard() {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(self, forType: .string)
        #else
            UIPasteboard.general.string = self
        #endif
    }
}
