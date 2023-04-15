# markdown-webview

`MarkdownWebView` is a surprisingly performant SwiftUI view that renders Markdown content. 

I call it surprising because the underlying view is a `WKWebView`, yet a SwiftUI scroll view containing a bunch of `MarkdownWebView` still scrolls smoothly. A similar looking view built with native SwiftUI views doesn't have such performance (yet, hopefully).

https://user-images.githubusercontent.com/5054148/231708816-6c992197-893d-4d94-ae7c-2c6ce8d8c427.mp4

## Features

<details>
<summary>Auto-adjusting View Height</summary>

The view's height is always the content's height.

<img alt="Auto-adjusting View Height" src="https://user-images.githubusercontent.com/5054148/231703096-42a34f79-ffda-49b6-b352-304baa98fe84.png" width="1000">

</details>

<details>
<summary>Text Selection</summary>

<img alt="Text Selection" src="https://user-images.githubusercontent.com/5054148/231701074-17333cc7-5774-46ed-800a-dd113ca8dd5d.png" width="1000">

</details>

<details>
<summary>Dynamic Content</summary>

https://user-images.githubusercontent.com/5054148/231708816-6c992197-893d-4d94-ae7c-2c6ce8d8c427.mp4

</details>

<details>
<summary>Syntax Highlighting</summary>
Code syntax is automatically highlighted.
</details>

## Supported Platforms

- macOS 11 and later
- iOS 14 and later

## Installation

Add this package as a dependency. 

See the article [“Adding package dependencies to your app”](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app) to learn more.

## Usage

### Display Markdown Content

```swift
import SwiftUI
import MarkdownWebView

struct ContentView: View {
    @State private var markdownContent = "# Hello World"

    var body: some View {
        NavigationStack {
            MarkdownWebView(markdownContent)
        }
    }
}
```

### Customize Style

The view comes with a default style ([CSS files](https://github.com/tomdai/markdown-webview/tree/main/Sources/MarkdownWebView/Resources/stylesheets)) that suits many use cases.

You can also supply your own stylesheet by setting the `customStylesheet` parameter in the initializer.

```swift
import SwiftUI
import MarkdownWebView

struct ContentView: View {
    @State private var markdownContent = "# Hello World"
    private let stylesheet: String? = try? .init(contentsOf: Bundle.main.url(forResource: "markdown", withExtension: "css")!)
    
    var body: some View {
        NavigationStack {
            MarkdownWebView(markdownContent, customStylesheet: stylesheet)
        }
    }
}
```


### Handle Links

The view opens links with the default browser by default.

You can handle link activations yourself by setting the `onLinkActivation` parameter in the initializer.

```swift
import SwiftUI
import MarkdownWebView

struct ContentView: View {
    @State private var markdownContent = "# Hello apple.com"
    
    var body: some View {
        NavigationStack {
            MarkdownWebView(markdownContent)
                .onLinkActivation { url in
                    print(url)        
                }
        }
    }
}
```

## Requirement for macOS Apps

The underlying web view loads an HTML string. For the package to work in a macOS app, enable the “Outgoing Connections (Client)” capability.

<details>
<summary>What it looks like in Xcode</summary>

![Outgoing Connections (Client)](https://user-images.githubusercontent.com/5054148/231693500-093f4185-658b-4fa2-a182-fb40f50147b7.png)
</details>

## Acknowledgements
Portions of this package may utilize the following copyrighted material, the use of which is hereby acknowledged.

- [markdown-it](https://github.com/markdown-it/markdown-it)\
    © 2014 Vitaly Puzrin, Alex Kocharin
- [Punycode.js](https://github.com/mathiasbynens/punycode.js)\
    © Mathias Bynens
- [highlight.js](https://github.com/highlightjs/highlight.js)\
    © 2006 Ivan Sagalaev
- [markdown-it-mark](https://github.com/markdown-it/markdown-it-mark)\
    © 2014-2015 Vitaly Puzrin, Alex Kocharin
- [markdown-it-task-lists](https://github.com/revin/markdown-it-task-lists)\
    © 2016, Revin Guillen
- [github-markdown-css](https://github.com/sindresorhus/github-markdown-css)\
    © Sindre Sorhus
