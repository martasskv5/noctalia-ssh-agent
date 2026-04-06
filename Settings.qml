import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL

  property var pluginApi: null

  readonly property string defaultSocketPath: "/tmp/ssh-agent-" + (Quickshell.env("USER") || "default") + ".sock"

  property string editSocketPath: pluginApi?.pluginSettings?.socketPath || pluginApi?.manifest?.metadata?.defaultSettings?.socketPath || root.defaultSocketPath
  property string editSessionsFile: pluginApi?.pluginSettings?.sessionsFile || pluginApi?.manifest?.metadata?.defaultSettings?.sessionsFile || "~/.pageant-tray-v2-sessions.json"
  property string editTerminalCommand: pluginApi?.pluginSettings?.terminalCommand || pluginApi?.manifest?.metadata?.defaultSettings?.terminalCommand || ""
  property bool editShowNotifications: pluginApi?.pluginSettings?.showNotifications ?? pluginApi?.manifest?.metadata?.defaultSettings?.showNotifications ?? true

  function saveSettings() {
    if (!pluginApi) return

    pluginApi.pluginSettings.socketPath = root.editSocketPath
    pluginApi.pluginSettings.sessionsFile = root.editSessionsFile
    pluginApi.pluginSettings.terminalCommand = root.editTerminalCommand
    pluginApi.pluginSettings.showNotifications = root.editShowNotifications
    pluginApi.saveSettings()
  }

  NText {
    text: "SSH Agent Plugin Settings"
    pointSize: Style.fontSizeM
    font.weight: Font.Bold
    color: Color.mOnSurface
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Agent Socket Path"
    description: "Path to the ssh-agent UNIX socket"
    text: root.editSocketPath
    onTextChanged: root.editSocketPath = text
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Saved Sessions File"
    description: "JSON file used to store saved SSH sessions"
    text: root.editSessionsFile
    onTextChanged: root.editSessionsFile = text
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Preferred Terminal"
    description: "Optional terminal command used to launch SSH sessions (e.g. kitty)"
    text: root.editTerminalCommand
    onTextChanged: root.editTerminalCommand = text
  }

  NToggle {
    Layout.fillWidth: true
    label: "Show Notifications"
    description: "Display success and failure toasts for SSH operations"
    checked: root.editShowNotifications
    onToggled: checked => root.editShowNotifications = checked
  }

  NButton {
    text: "Save Settings"
    icon: "device-floppy"
    onClicked: root.saveSettings()
  }

  Item { Layout.fillHeight: true }
}
