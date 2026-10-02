import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // A plan file opened while the app is not running arrives here, not in
  // openURLContexts.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let url = connectionOptions.urlContexts.first?.url {
      AppDelegate.shared?.handleIncomingPlanFile(url: url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else {
      return
    }

    AppDelegate.shared?.handleIncomingPlanFile(url: url)
  }
}
