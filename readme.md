I've worked on more “hybrid" iOS applications than I care to admit.  One of the major pain points of these apps is always communication across the web/native boundary - between JavaScript running in a `UIWebView` to ObjectiveC in the app shell. 

We all know that the only official way to call into a `UIWebView` from ObjectiveC is via `stringByEvaluatingJavaScriptFromString`.  And the typical way to call out from JavaScript is some manner of setting window.location to trigger a `shouldStartLoadWithRequest:` callback on the `UIWebView` delegate.   Another oft-considered technique is to implement a custom `NSURLProtocol` and intercept requests made via `XMLHttpRequest`.  

Apple gives us a public JavaScriptCore framework (part of WebKit) in iOS7, and JavaScriptCore provides simple mechanisms to proxy objects and methods between ObjectiveC and the JavaScript “context”.  Unfortunately, while it is common knowledge that `UIWebView` is built upon WebKit and in turn is using JavaScriptCore, Apple didn’t expose a mechanism for us to access this infrastructure.

It is possible to manhandle `UIWebView` and retrieve its internal JSContext object by using a KVO keypath to access undocumented properties deep within `UIWebView`.  [impathic describes this technique on his blog][1].  A major drawback of this approach, of course, is that it relies on the internal structure of the `UIWebView`.

I present an alternative approach to retrieving a `UIWebView`’s `JSContext`.  Of course mine is also non-Apple-sanctioned, and could break also.  I probably won’t try shipping this in an application to the App Store.  But it is less likely to break, and I think too that it does not have any specific dependency on the internals of `UIWebView` other than `UIWebView` itself using WebKit and JavaScriptCore.  (There is one small caveat to this, explained later.)


The basic mechanism in play is this:  WebKit communicates “frame loading events” to its clients (such as `UIWebView`) using “`WebFrameLoadDelegate`” callbacks performed in similar fashion to how `UIWebView` communicates page loading events via its own `UIWebViewDelegate`.   One of the `WebFrameLoadDelegate` methods is `webView:didCreateJavaScriptContext:forFrame:`   Like all good event sources, the WebKit code checks to see if the delegate implements the callback method, and if so makes the call.  Here’s what it looks like in the WebKit source (WebFrameLoaderClient.mm):

    if (implementations->didCreateJavaScriptContextForFrameFunc) {
        CallFrameLoadDelegate(implementations->didCreateJavaScriptContextForFrameFunc, webView, @selector(webView:didCreateJavaScriptContext:forFrame:),
            script.javaScriptContext(), m_webFrame.get());
    }

It turns out that in iOS, inside `UIWebView`, whatever object is implementing WebKit `WebFrameLoadDelegate` methods doesn’t actually implement `webView:didCreateJavaScriptContext:forFrame:`, and hence WebKit never performs this call.  If the method existed on the delegate object then it would be called automatically.

Well, there are a handful of ways in ObjectiveC to dynamically add a method to an existing class or object.  The easiest way is via a category.  My approach hinges on extending `NSObject` via a category, to implement `webView:didCreateJavaScriptContext:forFrame:`. 

Indeed, adding this method prompts WebKit to start calling it, since any object (including some sink object inside `UIWebView`) that inherits from `NSObject` now has an implementation of `webView:didCreateJavaScriptContext:forFrame:`.  If the sink inside `UIWebView` were to implement this method in the future then this approach would likely silently fail since my implementation on `NSObject` would never be called.

When our method is called by WebKit it passes us a WebKit `WebView` (not a `UIWebView`!), a JavaScriptCore `JSContext` object, and WebKit `WebFrame`.  Since we don’t have a public WebKit framework to provide headers for us, the WebView and WebFrame are effectively opaque to us.  But the `JSContext` is what we’re after, and it’s fully available to us via the JavaScriptCore framework.  (In practice, I do end up calling one method on the `WebFrame`, as an optimization.) 

The question becomes how to equate a given JSContext back to a particular `UIWebView`.  The first thing I tried was to use the `WebView` object we’re handed and walk up the view hierarchy to find the owning `UIWebView`.  But it turns out this object is some kind of proxy for a `UIView` and is not actually a `UIView`.  And because it is opaque to us I really didn’t want to use it.

My solution is to iterate all of the `UIWebViews` created in the app (see the code to see how I do this) and use `stringByEvaluatingJavaScriptFromString:` to place a token “cookie” inside its JavaScriptContext.  Then, I check for the existence of this token in the `JSContext` I’ve been handed - if it exists then this is the `UIWebView` I’ve Been Looking For!

Once we have the `JSContext` we can do all sorts of nifty things.  My test app shows how we can map ObjectiveC blocks and objects directly into the global namespace and access/invoke them from JavaScript.

**One Last Thing**  

(Sorry, couldn’t resist.)  With this bridge in place, it’s now possible to invoke ObjectiveC code in the app via the desktop Safari WebInspector console!  Try it out with the test app by attaching the WebInspector and typing `sayHello();` into the console input field.  Now that’s cool!

Nick Hodapp (a.k.a TomSwift), November 2013


  [1]: http://blog.impathic.com/post/64171814244/true-javascript-uiwebview-integration-in-ios7