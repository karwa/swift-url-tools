# WebURL Live Viewer

<img src="example.png" height="50%" width="50%"><img src="example2.png" height="50%" width="50%">

A developer utility for [swift-url](https://www.github.com/karwa/swift-url). It has a similar interface to the [JSDOM live URL viewer](https://jsdom.github.io/whatwg-url/), and allows easy comparisons of WebURL with the JSDom reference implementation among other things.

> If the logo didn't make it clear, this isn't supposed to be a pretty App. It's a tool for WebURL developers (basically me) to exercise the API interactively. But you might find it cool to play with 🙂

Requires macOS Big Sur or newer. Also supports iOS.

<img src="example3.png" height="33%" width="33%"> <img src="example4.png" height="33%" width="33%">

Also, it has a funky render mode, which demonstrates using WebURL's UTF8View to render a URL as an attributed string.

<img src="example5.png" height="50%" width="50%"> 

<img src="example6.png" height="50%" width="50%">

The app contains a local copy of the JSDom live URL viewer website (in `live-viewer/Resources/live-viewer/`).

## Getting Started

1. Clone this repository
2. Clone the swift-url repository in to this one, so your folder structure looks like:

   - swift-url-tools/
      - live-viewer.xcworkspace
      - live-viewer/
        - viewer-app.xcodeproj
        - Sources/
        - Resources/
      - swift-url/
        - Sources/
        - Tests/
        - ...etc

Here's the command:

    git clone https://www.github.com/karwa/swift-url

(Yes, this is a bit clunky, but you get a much better testing & editing experience in Xcode when these are just 2 source projects on disk).

3. Open live-viewer.xcworkspace in XCode.
4. Build and run the "live-url-viewer" target.

Note: You can also run WebURL's own test suite from this same workspace by selecting the "swift-url Package" target.