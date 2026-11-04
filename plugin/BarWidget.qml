import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "killie.dictator"

  property bool daemonRunning: false
  property bool settingsOpen: false
  property int idleTimeout: 300
  property bool neverAutoEnd: false

  readonly property var timeoutValues: [
    30,60,90,120,150,180,210,240,270,300,
    600,900,1200,1500,1800,2100,2400,2700,3000,3300,3600
  ]

  function refreshDaemon() {
    daemonCheck.running = true
  }

  function refreshTimeout() {
    timeoutRead.running = true
  }

  function close() {
    root.settingsOpen = false
  }

  function formatTimeout(seconds) {
    if (seconds <= 0) return "never"
    if (seconds < 60) return seconds + "s"
    var m = Math.floor(seconds / 60)
    var s = seconds % 60
    if (s === 0) return m + "m"
    return m + "m " + s + "s"
  }

  function indexForTimeout(seconds) {
    for (var i = 0; i < timeoutValues.length; i++) {
      if (timeoutValues[i] === seconds) return i
    }
    var best = 0, bestDiff = Math.abs(timeoutValues[0]-seconds)
    for (var j = 1; j < timeoutValues.length; j++) {
      var d = Math.abs(timeoutValues[j]-seconds)
      if (d < bestDiff) { bestDiff = d; best = j }
    }
    return best
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: daemonCheck
    command: ["bash", "-c", "systemctl --user is-active --quiet dictator.service && echo 1 || echo 0"]
    running: false
    stdout: SplitParser {
      onRead: function(data) {
        root.daemonRunning = (data.trim() === "1")
      }
    }
  }

  Process {
    id: toggleProc
    running: false
    onExited: root.refreshDaemon()
  }

  Process {
    id: configProc
    command: ["omarchy-voxtype-config"]
    running: false
  }

  Process {
    id: timeoutRead
    command: ["/home/bashman/.local/bin/dictator-get-timeout.sh"]
    running: false
    stdout: SplitParser {
      onRead: function(data) {
        var v = parseInt(data.trim(), 10)
        if (isNaN(v)) v = 300
        root.idleTimeout = v
        root.neverAutoEnd = (v === 0)
        if (!root.neverAutoEnd) {
          timeoutSlider.value = root.indexForTimeout(v)
        }
      }
    }
  }

  Process {
    id: timeoutWrite
    running: false
    onExited: root.refreshTimeout()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refreshDaemon()
  }

  Component.onCompleted: {
    root.refreshDaemon()
    root.refreshTimeout()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.daemonRunning ? "󰍬" : "󰍭"
    active: root.daemonRunning
    tooltipText: root.daemonRunning
      ? "Voxtype warm — click for settings"
      : "Voxtype cold — click for settings"
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        if (root.bar && typeof root.bar.run === "function") root.bar.run("omarchy-voxtype-config")
        else { configProc.running = true }
      } else {
        root.refreshTimeout()
        root.settingsOpen = !root.settingsOpen
      }
    }
  }

  PopupCard {
    id: settingsPopup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.settingsOpen
    onOpenChanged: {
      if (!open) root.settingsOpen = false
    }
    contentWidth: settingsPopup.fittedContentWidth(Style.space(340))
    contentHeight: settingsPopup.fittedContentHeight(content.implicitHeight)
    triggerMode: "click"

    Column {
      id: content
      anchors.fill: parent
      spacing: Style.space(12)

      Column {
        width: parent.width
        spacing: Style.space(2)

        Text {
          text: "Dictator"
          color: root.bar ? root.bar.barForeground : Commons.Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          text: root.daemonRunning ? "Daemon: warm" : "Daemon: cold"
          color: Qt.darker(root.bar ? root.bar.barForeground : Commons.Color.foreground, 1.35)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)

        Button {
          width: (parent.width - Style.space(8)) / 2
          bordered: true
          text: root.daemonRunning ? "Stop daemon (cold)" : "Start daemon (warm)"
          foreground: root.bar ? root.bar.barForeground : Commons.Color.foreground
          onClicked: {
            toggleProc.command = ["/home/bashman/.local/bin/dictator-toggle.sh"]
            toggleProc.running = true
          }
        }

        Button {
          width: (parent.width - Style.space(8)) / 2
          bordered: true
          text: "Configure"
          foreground: root.bar ? root.bar.barForeground : Commons.Color.foreground
          onClicked: {
            if (root.bar && typeof root.bar.run === "function") root.bar.run("omarchy-voxtype-config")
            else { configProc.running = true }
          }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(8)

        Toggle {
          width: parent.width
          label: "Never auto-stop daemon"
          checked: root.neverAutoEnd
          color: "transparent"
          borderSpec: Border.none()
          foreground: root.bar ? root.bar.barForeground : Commons.Color.foreground
          onClicked: {
            root.neverAutoEnd = !root.neverAutoEnd
            if (root.neverAutoEnd) {
              timeoutWrite.command = ["/home/bashman/.local/bin/dictator-set-timeout.sh", "0"]
              timeoutWrite.running = true
            } else {
              var secs = root.timeoutValues[Math.round(timeoutSlider.liveValue)]
              timeoutWrite.command = ["/home/bashman/.local/bin/dictator-set-timeout.sh", String(secs)]
              timeoutWrite.running = true
            }
          }
        }

        Text {
          text: "Timeout: " + (root.neverAutoEnd ? "never" : root.formatTimeout(root.timeoutValues[Math.round(timeoutSlider.liveValue)]))
          color: Qt.darker(root.bar ? root.bar.barForeground : Commons.Color.foreground, 1.35)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        PanelSlider {
          id: timeoutSlider
          bar: root.bar
          width: parent.width
          minimum: 0
          maximum: root.timeoutValues.length - 1
          step: 1
          integer: true
          value: root.neverAutoEnd ? 0 : root.indexForTimeout(root.idleTimeout)
          enabled: !root.neverAutoEnd
          opacity: enabled ? 1.0 : 0.4
          onMoved: function(v) { }
          onReleased: function(v) {
            if (!root.neverAutoEnd) {
              var secs = root.timeoutValues[Math.round(v)]
              timeoutWrite.command = ["/home/bashman/.local/bin/dictator-set-timeout.sh", String(secs)]
              timeoutWrite.running = true
            }
          }
        }
      }

    }
  }
}
