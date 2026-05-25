import Foundation
import Capacitor
import WebKit

@objc(YouTubePlayerPlugin)
public class YouTubePlayerPlugin: CAPPlugin, CAPBridgedPlugin, WKScriptMessageHandler {
    public let identifier = "YouTubePlayerPlugin"
    public let jsName = "YouTubePlayer"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "show", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hide", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "seekTo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "layout", returnType: CAPPluginReturnPromise),
    ]

    private var playerView: WKWebView?
    private var containerView: UIView?

    @objc func show(_ call: CAPPluginCall) {
        guard let videoId = call.getString("videoId"), !videoId.isEmpty else {
            call.reject("videoId required")
            return
        }
        let startSec = call.getDouble("startSec") ?? 0
        let ccLang = call.getString("ccLang") ?? "pt"

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let bridgeVC = self.bridge?.viewController else {
                call.reject("no view controller")
                return
            }

            self.hideInternal()

            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []
            config.userContentController.add(self, name: "ytBridge")

            let webView = WKWebView(frame: .zero, configuration: config)
            webView.scrollView.isScrollEnabled = false
            webView.isOpaque = false
            webView.backgroundColor = .black

            let container = UIView(frame: .zero)
            container.backgroundColor = .black
            container.clipsToBounds = true

            bridgeVC.view.addSubview(container)
            container.addSubview(webView)

            self.containerView = container
            self.playerView = webView

            self.applyLayout(from: call, bridgeVC: bridgeVC, webView: webView, container: container)

            let html = self.embedHtml(videoId: videoId, ccLang: ccLang, startSec: startSec)
            webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com/")!)

            call.resolve()
        }
    }

    @objc func layout(_ call: CAPPluginCall) {
        DispatchQueue.main.async { [weak self] in
            guard
                let self = self,
                let bridgeVC = self.bridge?.viewController,
                let webView = self.playerView,
                let container = self.containerView
            else {
                call.resolve()
                return
            }
            self.applyLayout(from: call, bridgeVC: bridgeVC, webView: webView, container: container)
            call.resolve()
        }
    }

    @objc func hide(_ call: CAPPluginCall) {
        DispatchQueue.main.async { [weak self] in
            self?.hideInternal()
            call.resolve()
        }
    }

    @objc func seekTo(_ call: CAPPluginCall) {
        let sec = call.getDouble("sec") ?? 0
        DispatchQueue.main.async { [weak self] in
            self?.playerView?.evaluateJavaScript("if(window.ytPlayer){window.ytPlayer.seekTo(\(sec), true);}", completionHandler: nil)
            call.resolve()
        }
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "ytBridge", let body = message.body as? [String: Any] else { return }
        notifyListeners("youtubePlayerEvent", data: body)
    }

    private func applyLayout(from call: CAPPluginCall, bridgeVC: UIViewController, webView: WKWebView, container: UIView) {
        let top = CGFloat(call.getDouble("top") ?? 0)
        let left = CGFloat(call.getDouble("left") ?? 0)
        let width = CGFloat(call.getDouble("width") ?? bridgeVC.view.bounds.width)
        let height = CGFloat(call.getDouble("height") ?? 200)

        container.frame = CGRect(x: left, y: top, width: width, height: height)
        webView.frame = container.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    private func embedHtml(videoId: String, ccLang: String, startSec: Double) -> String {
        let safeId = videoId.replacingOccurrences(of: "'", with: "")
        let safeLang = ccLang.replacingOccurrences(of: "'", with: "")
        let startJs = startSec > 1 ? "start: \(Int(startSec))," : ""
        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="referrer" content="strict-origin-when-cross-origin">
          <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
          <style>html,body{margin:0;height:100%;background:#000}#p{width:100%;height:100%}</style>
          <script src="https://www.youtube.com/iframe_api"></script>
        </head>
        <body>
          <div id="p"></div>
          <script>
            function post(msg) {
              try { window.webkit.messageHandlers.ytBridge.postMessage(msg); } catch (e) {}
            }
            function onYouTubeIframeAPIReady() {
              window.ytPlayer = new YT.Player('p', {
                host: 'https://www.youtube-nocookie.com',
                videoId: '\(safeId)',
                playerVars: {
                  playsinline: 1,
                  rel: 0,
                  enablejsapi: 1,
                  origin: 'https://www.youtube.com',
                  widget_referrer: 'https://www.youtube.com',
                  cc_load_policy: 1,
                  cc_lang_pref: '\(safeLang)',
                  modestbranding: 1,
                  \(startJs)
                },
                events: {
                  onReady: function() {
                    post({ event: 'ready' });
                    setInterval(function() {
                      if (!window.ytPlayer || !window.ytPlayer.getCurrentTime) return;
                      post({
                        event: 'time',
                        currentTime: window.ytPlayer.getCurrentTime(),
                        playerState: window.ytPlayer.getPlayerState()
                      });
                    }, 250);
                  },
                  onStateChange: function(e) { post({ event: 'state', playerState: e.data }); },
                  onError: function(e) { post({ event: 'error', code: e.data }); }
                }
              });
            }
          </script>
        </body>
        </html>
        """
    }

    private func hideInternal() {
        if let webView = playerView {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "ytBridge")
        }
        containerView?.removeFromSuperview()
        playerView = nil
        containerView = nil
    }
}
