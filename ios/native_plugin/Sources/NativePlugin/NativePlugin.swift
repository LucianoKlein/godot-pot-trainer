import SwiftGodot
import AuthenticationServices
import UIKit
import GoogleMobileAds
import RevenueCat
import GoogleSignIn
import AppTrackingTransparency

#initSwiftExtension(
    cdecl: "swift_entry_point",
    types: [NativePlugin.self]
)

@Godot
class NativePlugin: RefCounted {

    // MARK: - Apple Sign-In 信号
    #signal("apple_sign_in_success", arguments: ["id_token": String.self, "display_name": String.self])
    #signal("apple_sign_in_failed", arguments: ["error_msg": String.self])
    #signal("apple_sign_in_cancelled")

    // MARK: - AdMob 信号
    #signal("rewarded_ad_loaded")
    #signal("rewarded_ad_failed_to_load", arguments: ["error_code": Int.self, "error_msg": String.self])
    #signal("rewarded_ad_opened")
    #signal("rewarded_ad_closed")
    #signal("user_earned_reward", arguments: ["reward_type": String.self, "reward_amount": Int.self])
    #signal("rewarded_ad_failed_to_show", arguments: ["error_code": Int.self, "error_msg": String.self])

    // MARK: - RevenueCat 信号
    #signal("configured")
    #signal("offerings_loaded", arguments: ["data": String.self])
    #signal("purchase_completed", arguments: ["product_id": String.self])
    #signal("purchase_failed", arguments: ["error_code": Int.self, "error_msg": String.self])
    #signal("customer_info_updated", arguments: ["data": String.self])
    #signal("restore_completed", arguments: ["data": String.self])

    // MARK: - Google Sign-In 信号
    #signal("google_sign_in_success", arguments: ["id_token": String.self])
    #signal("google_sign_in_failed", arguments: ["error_msg": String.self])
    #signal("google_sign_in_cancelled")

    // MARK: - ATT 信号
    #signal("att_authorization_completed", arguments: ["status": Int.self])

    // MARK: - 内部状态
    private var appleSignInDelegate: AppleSignInDelegate?
    private var adDelegate: AdFullScreenDelegate?
    private var rcDelegate: RCDelegate?
    var rewardedAd: GADRewardedAd?
    private var isAdLoading = false

    // MARK: - Apple Sign-In

    @Callable
    func appleSignIn() {
        #if os(iOS)
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        appleSignInDelegate = AppleSignInDelegate(plugin: self)
        controller.delegate = appleSignInDelegate
        controller.presentationContextProvider = appleSignInDelegate
        controller.performRequests()
        #else
        emit(signal: NativePlugin.appleSignInFailed, "Not supported on this platform")
        #endif
    }

    @Callable
    func appleSignOut() {
    }

    // MARK: - Google Sign-In

    @Callable
    func googleSignIn(clientId: String, serverClientId: String) {
        #if os(iOS)
        guard let rootVC = getRootViewController() else {
            emit(signal: NativePlugin.googleSignInFailed, "No root view controller")
            return
        }

        let config = GIDConfiguration(clientID: clientId, serverClientID: serverClientId)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                let nsError = error as NSError
                if nsError.code == -5 {
                    self.emit(signal: NativePlugin.googleSignInCancelled)
                } else {
                    self.emit(signal: NativePlugin.googleSignInFailed, error.localizedDescription)
                }
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self.emit(signal: NativePlugin.googleSignInFailed, "Failed to get ID token")
                return
            }

            self.emit(signal: NativePlugin.googleSignInSuccess, idToken)
        }
        #else
        emit(signal: NativePlugin.googleSignInFailed, "Not supported on this platform")
        #endif
    }

    @Callable
    func googleSignOut() {
        #if os(iOS)
        GIDSignIn.sharedInstance.signOut()
        #endif
    }

    // MARK: - AdMob

    @Callable
    func requestTrackingAuthorization() {
        #if os(iOS)
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    GD.print("[NativePlugin] ATT status: \(status.rawValue)")
                    self?.emit(signal: NativePlugin.attAuthorizationCompleted, Int(status.rawValue))
                }
            }
        } else {
            emit(signal: NativePlugin.attAuthorizationCompleted, 3)
        }
        #endif
    }

    @Callable
    func initializeAds() {
        #if os(iOS)
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        GD.print("[NativePlugin] AdMob SDK initialized")
        #endif
    }

    @Callable
    func loadRewardedAd(adUnitId: String) {
        #if os(iOS)
        guard !isAdLoading else { return }
        isAdLoading = true

        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: adUnitId, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            self.isAdLoading = false

            if let error = error {
                let nsError = error as NSError
                self.emit(signal: NativePlugin.rewardedAdFailedToLoad, nsError.code, error.localizedDescription)
                return
            }
            self.rewardedAd = ad
            self.adDelegate = AdFullScreenDelegate(plugin: self)
            self.rewardedAd?.fullScreenContentDelegate = self.adDelegate
            self.emit(signal: NativePlugin.rewardedAdLoaded)
        }
        #endif
    }

    @Callable
    func showRewardedAd() {
        #if os(iOS)
        guard let ad = rewardedAd else {
            emit(signal: NativePlugin.rewardedAdFailedToShow, -1, "Ad not loaded")
            return
        }
        guard let rootVC = getRootViewController() else {
            emit(signal: NativePlugin.rewardedAdFailedToShow, -1, "No root view controller")
            return
        }
        ad.present(fromRootViewController: rootVC) { [weak self] in
            guard let self = self else { return }
            let reward = ad.adReward
            self.emit(signal: NativePlugin.userEarnedReward, reward.type, reward.amount.intValue)
        }
        #endif
    }

    // MARK: - RevenueCat

    @Callable
    func initializeRevenueCat(apiKey: String) {
        #if os(iOS)
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)
        rcDelegate = RCDelegate(plugin: self)
        Purchases.shared.delegate = rcDelegate
        GD.print("[NativePlugin] RevenueCat configured")
        emit(signal: NativePlugin.configured)
        #endif
    }

    @Callable
    func login(userId: String) {
        #if os(iOS)
        Purchases.shared.logIn(userId) { [weak self] info, _, error in
            if let error = error {
                GD.print("[NativePlugin] RC login error: \(error.localizedDescription)")
                return
            }
            if let info = info {
                let json = Self.customerInfoToJson(info)
                self?.emit(signal: NativePlugin.customerInfoUpdated, json)
            }
        }
        #endif
    }

    @Callable
    func logout() {
        #if os(iOS)
        Purchases.shared.logOut { _, _ in }
        #endif
    }

    @Callable
    func fetchOfferings() {
        #if os(iOS)
        Purchases.shared.getOfferings { [weak self] offerings, error in
            guard let self = self else { return }
            if error != nil || offerings?.current == nil {
                self.emit(signal: NativePlugin.offeringsLoaded, "{}")
                return
            }
            var packages: [[String: Any]] = []
            for pkg in offerings!.current!.availablePackages {
                let product = pkg.storeProduct
                packages.append([
                    "identifier": pkg.identifier,
                    "product_id": product.productIdentifier,
                    "price": product.localizedPriceString,
                    "price_amount": product.price as NSNumber,
                    "title": product.localizedTitle,
                    "description": product.localizedDescription,
                ])
            }
            let json = Self.dictToJson(["packages": packages])
            self.emit(signal: NativePlugin.offeringsLoaded, json)
        }
        #endif
    }

    @Callable
    func purchase(productId: String) {
        #if os(iOS)
        Purchases.shared.getOfferings { [weak self] offerings, error in
            guard let self = self else { return }
            guard let pkg = offerings?.current?.availablePackages.first(where: {
                $0.storeProduct.productIdentifier == productId
            }) else {
                self.emit(signal: NativePlugin.purchaseFailed, -1, "Product not found: \(productId)")
                return
            }
            Purchases.shared.purchase(package: pkg) { [weak self] _, info, error, userCancelled in
                guard let self = self else { return }
                if userCancelled {
                    self.emit(signal: NativePlugin.purchaseFailed, -2, "User cancelled")
                    return
                }
                if let error = error {
                    self.emit(signal: NativePlugin.purchaseFailed, (error as NSError).code, error.localizedDescription)
                    return
                }
                self.emit(signal: NativePlugin.purchaseCompleted, productId)
                if let info = info {
                    let json = Self.customerInfoToJson(info)
                    self.emit(signal: NativePlugin.customerInfoUpdated, json)
                }
            }
        }
        #endif
    }

    @Callable
    func restorePurchases() {
        #if os(iOS)
        Purchases.shared.restorePurchases { [weak self] info, error in
            guard let self = self else { return }
            if let info = info {
                let json = Self.customerInfoToJson(info)
                self.emit(signal: NativePlugin.restoreCompleted, json)
            } else {
                self.emit(signal: NativePlugin.restoreCompleted, "{}")
            }
        }
        #endif
    }

    @Callable
    func getCustomerInfo() {
        #if os(iOS)
        Purchases.shared.getCustomerInfo { [weak self] info, error in
            if let info = info {
                let json = Self.customerInfoToJson(info)
                self?.emit(signal: NativePlugin.customerInfoUpdated, json)
            }
        }
        #endif
    }

    // MARK: - Helpers

    #if os(iOS)
    private func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return nil }
        return window.rootViewController
    }
    #endif

    static func customerInfoToJson(_ info: CustomerInfo) -> String {
        var entitlements: [String: Any] = [:]
        for (entId, ent) in info.entitlements.all {
            var entDict: [String: Any] = [
                "isActive": ent.isActive,
                "productIdentifier": ent.productIdentifier,
                "willRenew": ent.willRenew,
            ]
            if let expDate = ent.expirationDate {
                entDict["expirationDateMillis"] = Int64(expDate.timeIntervalSince1970 * 1000)
                let formatter = ISO8601DateFormatter()
                entDict["expirationDate"] = formatter.string(from: expDate)
            }
            entitlements[entId] = entDict
        }
        return dictToJson(["entitlements": entitlements])
    }

    static func dictToJson(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}

// MARK: - Apple Sign-In Delegate

#if os(iOS)
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    weak var plugin: NativePlugin?

    init(plugin: NativePlugin) {
        self.plugin = plugin
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return UIWindow() }
        return window
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            plugin?.emit(signal: NativePlugin.appleSignInFailed, "Failed to get identity token")
            return
        }
        var displayName = ""
        if let fullName = credential.fullName {
            let given = fullName.givenName ?? ""
            let family = fullName.familyName ?? ""
            displayName = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        }
        plugin?.emit(signal: NativePlugin.appleSignInSuccess, idToken, displayName)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.code == ASAuthorizationError.canceled.rawValue {
            plugin?.emit(signal: NativePlugin.appleSignInCancelled)
        } else {
            plugin?.emit(signal: NativePlugin.appleSignInFailed, error.localizedDescription)
        }
    }
}
#endif

// MARK: - GADFullScreenContentDelegate (AdMob)

#if os(iOS)
class AdFullScreenDelegate: NSObject, GADFullScreenContentDelegate {
    weak var plugin: NativePlugin?

    init(plugin: NativePlugin) {
        self.plugin = plugin
    }

    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        plugin?.emit(signal: NativePlugin.rewardedAdOpened)
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        plugin?.rewardedAd = nil
        plugin?.emit(signal: NativePlugin.rewardedAdClosed)
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        plugin?.rewardedAd = nil
        plugin?.emit(signal: NativePlugin.rewardedAdFailedToShow, (error as NSError).code, error.localizedDescription)
    }
}
#endif

// MARK: - PurchasesDelegate (RevenueCat)

#if os(iOS)
class RCDelegate: NSObject, PurchasesDelegate {
    weak var plugin: NativePlugin?

    init(plugin: NativePlugin) {
        self.plugin = plugin
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        let json = NativePlugin.customerInfoToJson(customerInfo)
        plugin?.emit(signal: NativePlugin.customerInfoUpdated, json)
    }
}
#endif
