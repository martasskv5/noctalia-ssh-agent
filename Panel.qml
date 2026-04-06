import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 520 * Style.uiScaleRatio
  property real contentPreferredHeight: Math.max(
    320 * Style.uiScaleRatio,
    Math.min(760 * Style.uiScaleRatio, panelContent.implicitHeight + Style.marginM * 2)
  )
  readonly property bool allowAttach: true

  readonly property var mainInstance: pluginApi?.mainInstance

  property string editName: ""
  property string editHost: ""
  property string editUser: Quickshell.env("USER") || ""
  property string editPort: "22"
  property string editKeyPath: ""
  property string editExtraArgs: ""
  property string selectedSessionName: ""
  property var selectedSession: null
  property var selectedSessionDelegate: null

  function clearSessionForm() {
    editName = ""
    editHost = ""
    editUser = Quickshell.env("USER") || ""
    editPort = "22"
    editKeyPath = ""
    editExtraArgs = ""
    selectedSessionName = ""
  }

  function loadSessionIntoForm(session) {
    if (!session) return
    selectedSessionName = session.name || ""
    editName = session.name || ""
    editHost = session.host || ""
    editUser = session.user || ""
    editPort = session.port || "22"
    editKeyPath = session.key_path || ""
    editExtraArgs = session.extra_args || ""
    sessionEditorPopup.open()
  }

  function saveSessionFromForm() {
    mainInstance?.upsertSession({
      name: editName,
      host: editHost,
      user: editUser,
      port: editPort,
      key_path: editKeyPath,
      extra_args: editExtraArgs
    })
    sessionEditorPopup.close()
  }

  function openNewSessionEditor() {
    clearSessionForm()
    sessionEditorPopup.open()
  }

  function closeSessionEditor() {
    sessionEditorPopup.close()
    clearSessionForm()
  }

  function openSessionContextMenu(session, delegate, mouseX, mouseY) {
    selectedSession = session
    selectedSessionDelegate = delegate
    sessionContextMenu.openAtItem(delegate, mouseX, mouseY)
  }

  NContextMenu {
    id: sessionContextMenu

    model: [
      {
        label: "Connect",
        action: "connect",
        icon: "terminal"
      },
      {
        label: "Edit",
        action: "edit",
        icon: "edit"
      },
      {
        label: "Delete",
        action: "delete",
        icon: "trash"
      }
    ]

    onTriggered: action => {
      if (!root.selectedSession) return

      if (action === "connect") {
        mainInstance?.launchSession(root.selectedSession)
      } else if (action === "edit") {
        root.loadSessionIntoForm(root.selectedSession)
      } else if (action === "delete") {
        mainInstance?.deleteSession(root.selectedSession.name)
        if (root.selectedSessionName === root.selectedSession.name) {
          root.clearSessionForm()
        }
      }
    }
  }

  NFilePicker {
    id: keyPicker
    title: "Select private key"
    selectionMode: "files"
    initialPath: Quickshell.env("HOME") || ""

    onAccepted: paths => {
      if (paths.length > 0) {
        mainInstance?.addKey(paths[0])
      }
    }
  }

  Popup {
    id: sessionEditorPopup
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    readonly property real popupAvailWidth: Math.max(320, root.width - Style.marginL * 2)
    readonly property real popupAvailHeight: Math.max(320, root.height - Style.marginL * 2)
    width: Math.min(popupAvailWidth, 680 * Style.uiScaleRatio)
    height: Math.min(popupAvailHeight, 820 * Style.uiScaleRatio)
    x: Math.max(Style.marginL, (root.width - width) / 2)
    y: Math.max(Style.marginL, (root.height - height) / 2)
    padding: 0

    background: Rectangle {
      color: Color.mSurfaceVariant
      radius: Style.radiusL
      border.color: Style.capsuleBorderColor
      border.width: Style.capsuleBorderWidth
    }

    contentItem: Flickable {
      id: editorFlick
      clip: true
      contentWidth: width
      contentHeight: editorContent.implicitHeight + Style.marginM * 2
      boundsBehavior: Flickable.StopAtBounds

      ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
      }

      ColumnLayout {
        id: editorContent
        x: Style.marginM
        y: Style.marginM
        width: editorFlick.width - Style.marginM * 2
        spacing: Style.marginS

        NText {
          text: root.selectedSessionName ? "Edit Session" : "New Session"
          font.pointSize: Style.fontSizeM
          font.weight: Font.Medium
        }

        NTextInput {
          Layout.fillWidth: true
          label: "Session Name"
          text: root.editName
          onTextChanged: root.editName = text
        }

        NTextInput {
          Layout.fillWidth: true
          label: "Host"
          text: root.editHost
          onTextChanged: root.editHost = text
        }

        NTextInput {
          Layout.fillWidth: true
          label: "User"
          text: root.editUser
          onTextChanged: root.editUser = text
        }

        NTextInput {
          Layout.fillWidth: true
          label: "Port"
          text: root.editPort
          onTextChanged: root.editPort = text
        }

        NTextInput {
          Layout.fillWidth: true
          label: "Key Path"
          text: root.editKeyPath
          onTextChanged: root.editKeyPath = text
        }

        NTextInput {
          Layout.fillWidth: true
          label: "Extra SSH Args"
          text: root.editExtraArgs
          onTextChanged: root.editExtraArgs = text
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NButton {
            Layout.fillWidth: true
            text: root.selectedSessionName ? "Update Session" : "Save Session"
            icon: "device-floppy"
            onClicked: root.saveSessionFromForm()
          }

          NButton {
            Layout.fillWidth: true
            text: "Connect"
            icon: "terminal"
            enabled: root.editHost.length > 0
            onClicked: {
              mainInstance?.launchSession({
                name: root.editName,
                host: root.editHost,
                user: root.editUser,
                port: root.editPort,
                key_path: root.editKeyPath,
                extra_args: root.editExtraArgs
              })
            }
          }
        }

        NButton {
          Layout.fillWidth: true
          text: "Clear"
          icon: "eraser"
          onClicked: root.clearSessionForm()
        }

        NButton {
          Layout.fillWidth: true
          text: "Close"
          icon: "x"
          onClicked: root.closeSessionEditor()
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.marginM
        }
      }
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: panelContent
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      Rectangle {
        Layout.fillWidth: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RowLayout {
            spacing: Style.marginS

            NIcon {
              icon: "key"
              pointSize: Style.fontSizeXL
              color: Color.mPrimary
            }

            NText {
              text: "SSH Agent"
              font.pointSize: Style.fontSizeL
              font.weight: Font.Medium
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            Rectangle {
              radius: Style.radiusS
              color: mainInstance?.agentRunning ? Qt.alpha(Color.mSuccess, 0.2) : Qt.alpha(Color.mError, 0.2)
              implicitHeight: statusText.implicitHeight + Style.marginS
              implicitWidth: statusText.implicitWidth + Style.marginM

              NText {
                id: statusText
                anchors.centerIn: parent
                text: mainInstance?.agentRunning ? "Running" : "Stopped"
                color: mainInstance?.agentRunning ? Color.mSuccess : Color.mError
                pointSize: Style.fontSizeXS
              }
            }

            NIconButton {
              icon: "refresh"
              tooltipText: "Refresh"
              onClicked: mainInstance?.refreshState()
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(
          Style.baseWidgetSize * 2,
          Math.min(520 * Style.uiScaleRatio, scrollContent.implicitHeight + Style.marginM * 2)
        )
        color: Color.mSurfaceVariant
        radius: Style.radiusL
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        Flickable {
          id: bodyFlick
          anchors.fill: parent
          anchors.margins: Style.marginM
          clip: true
          contentWidth: width
          contentHeight: scrollContent.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
          }

          ColumnLayout {
            id: scrollContent
            width: bodyFlick.width
            spacing: Style.marginL

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NText {
                text: "Loaded Keys"
                font.pointSize: Style.fontSizeM
                font.weight: Font.Medium
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(
                  Style.baseWidgetSize * 4.8,
                  Math.max(
                    Style.baseWidgetSize * 1.4,
                    ((mainInstance?.loadedKeys?.length || 0) * (Style.baseWidgetSize * 0.95)) + Style.marginM
                  )
                )
                radius: Style.radiusM
                color: Style.capsuleColor
                border.color: Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth

                ListView {
                  anchors.fill: parent
                  anchors.margins: Style.marginS
                  model: mainInstance?.loadedKeys || []
                  spacing: Style.marginXS
                  clip: true

                  delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    radius: Style.radiusS
                    color: Qt.alpha(Color.mSurfaceVariant, 0.35)
                    implicitHeight: keyRow.implicitHeight + Style.marginS

                    RowLayout {
                      id: keyRow
                      anchors.fill: parent
                      anchors.margins: Style.marginS
                      spacing: Style.marginS

                      NText {
                        text: modelData.name || "(unknown)"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                      }

                      NText {
                        text: modelData.type || ""
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeXS
                      }

                      NIconButton {
                        icon: "trash"
                        tooltipText: "Unload key"
                        onClicked: mainInstance?.removeKey(modelData.name)
                      }
                    }
                  }
                }

                NText {
                  anchors.centerIn: parent
                  visible: (mainInstance?.loadedKeys?.length || 0) === 0
                  text: "No keys loaded"
                  color: Color.mOnSurfaceVariant
                }
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                  text: "Saved Sessions"
                  font.pointSize: Style.fontSizeM
                  font.weight: Font.Medium
                  Layout.fillWidth: true
                }

                NButton {
                  text: "New Session"
                  icon: "plus"
                  onClicked: root.openNewSessionEditor()
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(
                  Style.baseWidgetSize * 1.4,
                  sessionsList.contentHeight + Style.marginS * 2
                )
                radius: Style.radiusM
                color: Style.capsuleColor
                border.color: Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth

                ListView {
                  id: sessionsList
                  anchors.fill: parent
                  anchors.margins: Style.marginS
                  model: mainInstance?.sessions || []
                  spacing: Style.marginXS
                  interactive: false
                  clip: true

                  delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    radius: Style.radiusS
                    color: root.selectedSessionName === (modelData.name || "") ? Qt.alpha(Color.mPrimary, 0.22) : Qt.alpha(Color.mSurfaceVariant, 0.35)
                    implicitHeight: sessionRow.implicitHeight + Style.marginS

                    MouseArea {
                      anchors.fill: parent
                      onClicked: root.selectedSessionName = modelData.name || ""
                    }

                    TapHandler {
                      acceptedButtons: Qt.RightButton
                      onTapped: root.openSessionContextMenu(modelData, parent, point.position.x, point.position.y)
                    }

                    RowLayout {
                      id: sessionRow
                      anchors.fill: parent
                      anchors.margins: Style.marginS
                      spacing: Style.marginS

                      NText {
                        text: modelData.name || ""
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                        Layout.preferredWidth: 2
                        Layout.minimumWidth: Style.baseWidgetSize * 2.2
                        elide: Text.ElideRight
                      }

                      NText {
                        text: modelData.host || ""
                        color: Color.mOnSurfaceVariant
                        horizontalAlignment: Text.AlignRight
                        Layout.fillWidth: true
                        Layout.preferredWidth: 3
                        Layout.minimumWidth: Style.baseWidgetSize * 2.6
                        elide: Text.ElideMiddle
                      }
                    }
                  }
                }

                NText {
                  anchors.centerIn: parent
                  visible: (mainInstance?.sessions?.length || 0) === 0
                  text: "No saved sessions"
                  color: Color.mOnSurfaceVariant
                }
              }

            }
          }
        }
      }

      NButton {
        Layout.fillWidth: true
        text: "Add Key"
        icon: "plus"
        onClicked: keyPicker.open()
      }

      NButton {
        Layout.fillWidth: true
        text: "Remove All Keys"
        icon: "trash"
        enabled: (mainInstance?.loadedKeys?.length || 0) > 0
        onClicked: mainInstance?.removeAllKeys()
      }

      NButton {
        Layout.fillWidth: true
        text: mainInstance?.agentRunning ? "Restart Agent" : "Start Agent"
        icon: "player-play"
        backgroundColor: mainInstance?.agentRunning ? Color.mPrimary : Color.mSuccess
        onClicked: mainInstance?.startAgent(mainInstance?.agentRunning ?? false)
      }

      NButton {
        Layout.fillWidth: true
        text: "Stop Agent"
        icon: "player-stop"
        backgroundColor: Color.mError
        textColor: Color.mOnError
        visible: mainInstance?.agentRunning ?? false
        onClicked: mainInstance?.stopAgent()
      }
    }
  }
}
