// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "markdown-webview",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "MarkdownWebView",
            targets: ["MarkdownWebView"]),
    ],
    targets: [
        .target(
            name: "MarkdownWebView",
            resources: [.process("Resources/page.html")]),
    ]
)
