import AppKit

// Before AppKit. Otherwise macOS will not list Punt under Full Disk Access.
FullDiskAccess.registerForSettingsList()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
