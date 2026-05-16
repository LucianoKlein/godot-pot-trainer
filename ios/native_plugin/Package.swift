// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NativePlugin",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "NativePlugin", type: .dynamic, targets: ["NativePlugin"])
    ],
    dependencies: [
        .package(path: "LocalSwiftGodot"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads", from: "11.0.0"),
        .package(url: "https://github.com/RevenueCat/purchases-ios", from: "5.0.0"),
        .package(path: "LocalGoogleSignIn"),
    ],
    targets: [
        .target(
            name: "NativePlugin",
            dependencies: [
                .product(name: "SwiftGodot", package: "LocalSwiftGodot"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
                .product(name: "RevenueCat", package: "purchases-ios"),
                .product(name: "GoogleSignIn", package: "LocalGoogleSignIn"),
            ],
            path: "Sources/NativePlugin",
            swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"])]
        )
    ]
)
