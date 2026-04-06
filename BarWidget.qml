import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets
import QtQuick.Controls

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property int keyCount: mainInstance?.loadedKeys?.length ?? 0
  readonly property bool agentRunning: mainInstance?.agentRunning ?? false

  implicitWidth: capsule.width
  implicitHeight: capsule.height

  Rectangle {
    id: capsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: row.implicitWidth + Style.marginM * 2
    height: Style.capsuleHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL

    RowLayout {
      id: row
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        icon: agentRunning ? "key" : "key-off"
        color: agentRunning ? Color.mPrimary : Color.mOnSurfaceVariant
      }

    //   NText {
    //     text: keyCount > 0 ? keyCount.toString() : ""
    //     color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
    //     pointSize: Style.fontSizeS
    //     visible: keyCount > 0
    //   }

      NText {
        text: mouseArea.containsMouse ? (agentRunning ? "Running" : "Stopped") + (keyCount > 0 ? " - Keys: " + keyCount : "") : ""
        color: Color.mOnHover
        pointSize: Style.fontSizeXS
        visible: mouseArea.containsMouse
        opacity: mouseArea.containsMouse ? 1 : 0
        Behavior on opacity {
          PropertyAnimation {
            duration: 250
            easing.type: Easing.InOutQuad
          }
        }
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": "Refresh",
        "action": "refresh",
        "icon": "refresh"
      },
      {
        "label": agentRunning ? "Restart Agent" : "Start Agent",
        "action": "start-agent",
        "icon": "player-play"
      },
      {
        "label": "Plugin Settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)

      if (action === "refresh") {
        mainInstance?.refreshState()
      } else if (action === "start-agent") {
        mainInstance?.startAgent(agentRunning)
      } else if (action === "settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest)
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) {
        pluginApi?.openPanel(screen, root)
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen)
      }
    }
  }
}