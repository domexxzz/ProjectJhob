import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyCover: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    let hideInSwitcher = UserDefaults.standard.object(
      forKey: "flutter.privacy_hide_recent_apps"
    ) as? Bool ?? true
    guard hideInSwitcher,
          let windowScene = scene as? UIWindowScene,
          let window = windowScene.windows.first else { return }

    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = UIColor(red: 13 / 255, green: 17 / 255, blue: 23 / 255, alpha: 1)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
    icon.tintColor = UIColor(red: 0, green: 200 / 255, blue: 80 / 255, alpha: 1)
    icon.contentMode = .scaleAspectFit
    icon.translatesAutoresizingMaskIntoConstraints = false

    let label = UILabel()
    label.text = "พี่เงินปกป้องข้อมูลของคุณ"
    label.textColor = .white
    label.font = .boldSystemFont(ofSize: 18)
    label.translatesAutoresizingMaskIntoConstraints = false

    cover.addSubview(icon)
    cover.addSubview(label)
    NSLayoutConstraint.activate([
      icon.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: cover.centerYAnchor, constant: -24),
      icon.widthAnchor.constraint(equalToConstant: 58),
      icon.heightAnchor.constraint(equalToConstant: 58),
      label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 16),
      label.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
    ])

    window.addSubview(cover)
    privacyCover = cover
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }

}
