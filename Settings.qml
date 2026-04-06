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
  property string editSessionsFile: pluginApi?.pluginSettings?.sessionsFile || pluginApi?.manifest?.metadata?.defaultSettings?.sessionsFile || "~/.ssh/sessions.json"
  property string editTerminalCommand: pluginApi?.pluginSettings?.terminalCommand || pluginApi?.manifest?.metadata?.defaultSettings?.terminalCommand || ""
  property bool editShowNotifications: pluginApi?.pluginSettings?.showNotifications ?? pluginApi?.manifest?.metadata?.defaultSettings?.showNotifications ?? true
  property string editAutoStartMode: pluginApi?.pluginSettings?.autoStartMode || pluginApi?.manifest?.metadata?.defaultSettings?.autoStartMode || "Connect Existing"

  function saveSettings() {
    if (!pluginApi) return

    pluginApi.pluginSettings.socketPath = root.editSocketPath
    pluginApi.pluginSettings.sessionsFile = root.editSessionsFile
    pluginApi.pluginSettings.terminalCommand = root.editTerminalCommand
    pluginApi.pluginSettings.showNotifications = root.editShowNotifications
    pluginApi.pluginSettings.autoStartMode = root.editAutoStartMode
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

  NComboBox {
    Layout.fillWidth: true
    label: "Startup Behavior"
    description: "What to do when Noctalia starts"
    model: [
      { key: "Create New", name: "Create New" },
      { key: "Connect Existing", name: "Connect Existing" },
      { key: "Ask Each Time", name: "Ask Each Time" }
    ]
    currentKey: root.editAutoStartMode
    onSelected: key => root.editAutoStartMode = key || "Connect Existing"
  }

  NButton {
    text: "Save Settings"
    icon: "device-floppy"
    onClicked: root.saveSettings()
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: syscInfo.implicitHeight + Style.marginM * 2
    color: Color.mSurfaceVariant
    radius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    ColumnLayout {
      id: syscInfo
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      NText {
        text: "System Information"
        font.pointSize: Style.fontSizeM
        font.weight: Font.Bold
        color: Color.mOnSurface
      }

      RowLayout {
        spacing: Style.marginM
        NText {
          text: "ssh:"
          font.weight: Font.Medium
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 80
        }
        NText {
          text: pluginApi?.mainInstance?.sshVersion || "Loading..."
          color: Color.mOnSurface
          Layout.fillWidth: true
        }
      }
    }
  }

  Item { Layout.fillHeight: true }
}
