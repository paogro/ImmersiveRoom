import SwiftUI
import WebKit

/// Dünner SwiftUI-Wrapper um WKWebView. Lädt eine feste URL und meldet
/// Ladezustand und Seitentitel über Bindings zurück.
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // URL ist pro Fenster fix — kein Reload bei View-Updates nötig.
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        init(_ parent: WebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.pageTitle = webView.title ?? ""
            }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }
    }
}

/// Fenster-Inhalt für die Quelle eines News-Artikels. Wird als eigenes
/// WindowGroup-Fenster neben der Immersive Space geöffnet, damit der Raum
/// erhalten bleibt.
struct QuelleWebView: View {
    let url: URL

    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var pageTitle = ""

    var body: some View {
        NavigationStack {
            WebView(url: url, isLoading: $isLoading, pageTitle: $pageTitle)
                .overlay(alignment: .top) {
                    if isLoading {
                        ProgressView()
                            .padding(12)
                            .background(.thinMaterial, in: Capsule())
                            .padding(.top, 8)
                    }
                }
                .navigationTitle(pageTitle.isEmpty ? (url.host() ?? "Quelle") : pageTitle)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Fallback: Artikel im echten Safari öffnen, falls eine
                        // Seite das Einbetten verweigert oder der Nutzer es möchte.
                        Button {
                            openURL(url)
                        } label: {
                            Label("In Safari öffnen", systemImage: "safari")
                        }
                    }
                }
        }
        // Schließt sich selbst, sobald die App das Flag zurücksetzt (z. B. bei Navigation).
        // Self-dismiss aus der eigenen Fenster-Scene ist zuverlässiger als dismissWindow
        // von außerhalb.
        .onChange(of: appModel.offeneQuelleURL) { _, neu in
            if neu == nil { dismiss() }
        }
        // Wird das Fenster manuell geschlossen, Flag konsistent halten.
        .onDisappear {
            if appModel.offeneQuelleURL != nil {
                appModel.offeneQuelleURL = nil
            }
        }
    }
}
