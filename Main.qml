import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property var settingsWatcher: pluginApi?.pluginSettings

  readonly property string userName: Quickshell.env("USER") || "default"
  readonly property string defaultSocketPath: "/tmp/ssh-agent-" + userName + ".sock"
  readonly property string defaultSessionsFile: "~/.pageant-tray-v2-sessions.json"

  readonly property string agentSocketPath: pluginApi?.pluginSettings?.socketPath || defaultSocketPath
  readonly property string terminalCommand: pluginApi?.pluginSettings?.terminalCommand || ""
  readonly property string sessionsFilePath: pluginApi?.pluginSettings?.sessionsFile || defaultSessionsFile
  readonly property bool showNotifications: pluginApi?.pluginSettings?.showNotifications ?? true

  property bool agentRunning: false
  property bool loadingKeys: false
  property var loadedKeys: []
  property var sessions: []

  readonly property string resolvedSessionsFilePath: resolvePath(sessionsFilePath)

  function shellQuote(text) {
    return "'" + String(text || "").replace(/'/g, "'\\''") + "'"
  }

  function resolvePath(path) {
    var value = String(path || "").trim()
    if (!value) return ""
    var home = Quickshell.env("HOME") || ""
    if (value === "~") return home
    if (value.startsWith("~/")) return home + value.substring(1)
    return value
  }

  function maybeNotifyInfo(title, message) {
    if (showNotifications) {
      ToastService.showNotice(title, message || "")
    }
  }

  function maybeNotifyError(title, message) {
    ToastService.showError(title, message || "")
  }

  function runProcess(proc, commandArray) {
    proc.running = false
    proc.command = commandArray
    proc.running = true
  }

  function refreshState() {
    checkAgentRunning()
    refreshLoadedKeys()
  }

  function checkAgentRunning() {
    runProcess(checkAgentProc, ["sh", "-lc", "test -S " + shellQuote(agentSocketPath)])
  }

  function startAgent(killPrevious) {
    var script = ""
    if (killPrevious) {
      script += "pkill -f 'ssh-agent -a " + agentSocketPath.replace(/'/g, "'\\''") + "' 2>/dev/null || true\n"
    }
    script += "mkdir -p " + shellQuote((agentSocketPath.split("/").slice(0, -1).join("/") || "/tmp")) + "\n"
    script += "ssh-agent -a " + shellQuote(agentSocketPath) + " >/dev/null"
    runProcess(startAgentProc, ["sh", "-lc", script])
  }

  function stopAgent() {
    runProcess(stopAgentProc, ["sh", "-lc", "pkill -f 'ssh-agent -a " + agentSocketPath.replace(/'/g, "'\\''") + "'"])
  }

  function refreshLoadedKeys() {
    loadingKeys = true
    var command =
      "SSH_AUTH_SOCK=" + shellQuote(agentSocketPath) +
      " ssh-add -l 2>&1"
    runProcess(listKeysProc, ["sh", "-lc", command])
  }

  function parseLoadedKeys(outputText, exitCode) {
    var text = String(outputText || "")
    if (exitCode !== 0) {
      if (text.indexOf("The agent has no identities") !== -1 || text.indexOf("The agent has no keys") !== -1) {
        loadedKeys = []
      } else {
        loadedKeys = []
        maybeNotifyError("SSH Agent", text.trim())
      }
      return
    }

    var keys = []
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue

      var match = line.match(/^(\d+)\s+(\S+)\s+(.+?)(?:\s+\(([^)]+)\))?$/)
      if (!match) continue

      keys.push({
        bits: match[1],
        fingerprint: match[2],
        name: match[3],
        type: match[4] || ""
      })
    }
    loadedKeys = keys
  }

  function addKey(keyPath) {
    var path = resolvePath(keyPath)
    if (!path) return

    addKeyProc.keyPath = path
    var script = ""
    script += "ASKPASS=${SSH_ASKPASS:-}\n"
    script += "if [ -z \"$ASKPASS\" ] || [ ! -x \"$ASKPASS\" ]; then\n"
    script += "  for p in /usr/bin/ksshaskpass /usr/bin/ssh-askpass /usr/lib/ssh/ssh-askpass /usr/bin/lxqt-openssh-askpass; do\n"
    script += "    if [ -x \"$p\" ]; then ASKPASS=\"$p\"; break; fi\n"
    script += "  done\n"
    script += "fi\n"
    script += "if [ -n \"$ASKPASS\" ]; then\n"
    script += "  export SSH_ASKPASS=\"$ASKPASS\"\n"
    script += "  export SSH_ASKPASS_REQUIRE=prefer\n"
    script += "fi\n"
    script += "SSH_AUTH_SOCK=" + shellQuote(agentSocketPath) + " ssh-add " + shellQuote(path) + " 2>&1"

    runProcess(addKeyProc, ["sh", "-lc", script])
  }

  function removeKey(keyName) {
    if (!keyName) return
    removeKeyProc.keyName = keyName
    var command =
      "SSH_AUTH_SOCK=" + shellQuote(agentSocketPath) +
      " ssh-add -d " + shellQuote(keyName) + " 2>&1"
    runProcess(removeKeyProc, ["sh", "-lc", command])
  }

  function removeAllKeys() {
    var command =
      "SSH_AUTH_SOCK=" + shellQuote(agentSocketPath) +
      " ssh-add -D 2>&1"
    runProcess(removeAllKeysProc, ["sh", "-lc", command])
  }

  function launchSession(session) {
    if (!session || !session.host) return

    var user = String(session.user || "").trim()
    var host = String(session.host || "").trim()
    var destination = user ? (user + "@" + host) : host
    var port = String(session.port || "22").trim() || "22"
    var keyPath = resolvePath(session.key_path || "")
    var extraArgs = String(session.extra_args || "").trim()

    var sshCommand = "ssh -p " + shellQuote(port)
    if (keyPath) {
      sshCommand += " -i " + shellQuote(keyPath)
    }
    if (extraArgs) {
      sshCommand += " " + extraArgs
    }
    sshCommand += " " + shellQuote(destination)

    var wrapped = "SSH_AUTH_SOCK=" + shellQuote(agentSocketPath) + " " + sshCommand

    if (terminalCommand && terminalCommand.trim().length > 0) {
      Quickshell.execDetached([terminalCommand.trim(), "-e", "sh", "-lc", wrapped])
      return
    }

    var fallbackScript = ""
    fallbackScript += "if command -v kitty >/dev/null 2>&1; then exec kitty -e sh -lc " + shellQuote(wrapped) + "; fi\n"
    fallbackScript += "if command -v x-terminal-emulator >/dev/null 2>&1; then exec x-terminal-emulator -e sh -lc " + shellQuote(wrapped) + "; fi\n"
    fallbackScript += "if command -v footclient >/dev/null 2>&1; then exec footclient sh -lc " + shellQuote(wrapped) + "; fi\n"
    fallbackScript += "exit 127"

    runProcess(launchSessionProc, ["sh", "-lc", fallbackScript])
  }

  function normalizeSession(raw) {
    return {
      name: String(raw?.name || "").trim(),
      host: String(raw?.host || "").trim(),
      user: String(raw?.user || "").trim(),
      port: String(raw?.port || "22").trim() || "22",
      key_path: String(raw?.key_path || "").trim(),
      extra_args: String(raw?.extra_args || "").trim()
    }
  }

  function upsertSession(rawSession) {
    var session = normalizeSession(rawSession)
    if (!session.name || !session.host) {
      maybeNotifyError("Saved Sessions", "Session name and host are required")
      return false
    }

    var updated = sessions.slice()
    var existingIndex = -1
    for (var i = 0; i < updated.length; i++) {
      if (updated[i].name === session.name) {
        existingIndex = i
        break
      }
    }

    if (existingIndex >= 0) {
      updated[existingIndex] = session
    } else {
      updated.push(session)
    }

    sessions = updated
    writeSessions()
    maybeNotifyInfo("Saved Sessions", "Stored '" + session.name + "'")
    return true
  }

  function deleteSession(name) {
    var sessionName = String(name || "").trim()
    if (!sessionName) return

    var updated = []
    for (var i = 0; i < sessions.length; i++) {
      if (sessions[i].name !== sessionName) {
        updated.push(sessions[i])
      }
    }

    sessions = updated
    writeSessions()
    maybeNotifyInfo("Saved Sessions", "Deleted '" + sessionName + "'")
  }

  function writeSessions() {
    var serialized = JSON.stringify(sessions, null, 2) + "\n"
    var directory = resolvedSessionsFilePath.split("/").slice(0, -1).join("/")
    if (!directory) {
      directory = "."
    }

    var script = ""
    script += "mkdir -p " + shellQuote(directory) + "\n"
    script += "printf %s " + shellQuote(serialized) + " > " + shellQuote(resolvedSessionsFilePath)
    runProcess(writeSessionsProc, ["sh", "-lc", script])
  }

  function loadSessionsFromDisk() {
    if (!resolvedSessionsFilePath) {
      sessions = []
      return
    }

    runProcess(readSessionsProc, ["sh", "-lc", "cat " + shellQuote(resolvedSessionsFilePath)])
  }

  Component.onCompleted: {
    refreshState()
    loadSessionsFromDisk()
  }

  onSettingsWatcherChanged: {
    refreshState()
    loadSessionsFromDisk()
  }

  IpcHandler {
    target: "plugin:ssh-agent"

    function refresh() {
      root.refreshState()
    }

    function startAgent() {
      root.startAgent(false)
    }
  }

  Process {
    id: readSessionsProc
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      if (exitCode !== 0) {
        root.sessions = []
        return
      }

      var text = String(stdout.text || "").trim()
      if (!text) {
        root.sessions = []
        return
      }

      try {
        var parsed = JSON.parse(text)
        if (Array.isArray(parsed)) {
          root.sessions = parsed
        } else if (Array.isArray(parsed.entries)) {
          root.sessions = parsed.entries
        } else {
          root.sessions = []
        }
      } catch (e) {
        root.sessions = []
        root.maybeNotifyError("Saved Sessions", "Invalid JSON in sessions file")
      }
    }
  }

  Process {
    id: writeSessionsProc
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      if (exitCode !== 0) {
        root.maybeNotifyError("Saved Sessions", String(stderr.text || stdout.text).trim() || "Failed to save sessions")
      }
    }
  }

  Process {
    id: checkAgentProc
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      root.agentRunning = exitCode === 0
    }
  }

  Process {
    id: startAgentProc
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      if (exitCode === 0) {
        root.maybeNotifyInfo("SSH Agent", "Agent started")
      } else {
        root.maybeNotifyError("SSH Agent", String(stderr.text || stdout.text).trim() || "Failed to start ssh-agent")
      }
      root.refreshState()
    }
  }

  Process {
    id: stopAgentProc
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      if (exitCode === 0) {
        root.maybeNotifyInfo("SSH Agent", "Agent stopped")
      }
      root.refreshState()
    }
  }

  Process {
    id: listKeysProc
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      root.loadingKeys = false
      var combined = String(stdout.text || "")
      if (exitCode !== 0 && stderr.text) {
        combined = combined + "\n" + String(stderr.text)
      }
      root.parseLoadedKeys(combined, exitCode)
    }
  }

  Process {
    id: addKeyProc
    property string keyPath: ""
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      if (exitCode === 0) {
        root.maybeNotifyInfo("SSH Key Added", keyPath)
      } else {
        root.maybeNotifyError("Failed to Add Key", String(stderr.text || stdout.text).trim() || keyPath)
      }
      root.refreshLoadedKeys()
    }
  }

  Process {
    id: removeKeyProc
    property string keyName: ""
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      if (exitCode === 0) {
        root.maybeNotifyInfo("SSH Key Unloaded", keyName)
      } else {
        root.maybeNotifyError("Failed to Unload Key", String(stderr.text || stdout.text).trim() || keyName)
      }
      root.refreshLoadedKeys()
    }
  }

  Process {
    id: removeAllKeysProc
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      if (exitCode === 0) {
        root.maybeNotifyInfo("SSH Agent", "All keys removed")
      } else {
        root.maybeNotifyError("Failed to Remove Keys", String(stderr.text || stdout.text).trim())
      }
      root.refreshLoadedKeys()
    }
  }

  Process {
    id: launchSessionProc
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      if (exitCode !== 0) {
        root.maybeNotifyError("Launch Failed", "No supported terminal found")
      }
    }
  }
}
