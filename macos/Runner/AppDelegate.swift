import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Prevent App Nap from throttling network activity when app is not visible
  private var activity: NSObjectProtocol?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Prevent macOS App Nap: keeps network & timers active even when app is hidden
    activity = ProcessInfo.processInfo.beginActivity(
      options: [.userInitiated, .idleSystemSleepDisabled],
      reason: "Maintain MQTT connection for real-time robot monitoring"
    )
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    if let activity = activity {
      ProcessInfo.processInfo.endActivity(activity)
    }
  }
}
