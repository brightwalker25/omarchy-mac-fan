import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 brightwalker25

// The panel scaffolding here, the open/close and IPC contract, is derived from
// Omarchy's `omarchy.weather` and `omarchy.agents` plugins
// (https://github.com/basecamp/omarchy, MIT, Copyright (c) David Heinemeier
// Hansson), by way of this author's `brightwalker25.battery-limit`.

// The panel behind the fan glyph. It shows what the fan and the CPU are doing,
// and carries two choices: how eagerly mbpfan spins the fan up, and which
// power profile the CPU runs under. Everything it shows comes from
// `bin/mac-fan`, which decides everything and can be run from a terminal.
Panel {
  id: root
  moduleName: "brightwalker25.mac-fan"
  ipcTarget: "brightwalker25.mac-fan"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property color okColor: "#3fb950"
  readonly property color warnColor: "#d29922"
  readonly property color badColor: "#f85149"

  readonly property int refreshMs: Math.max(1000, Number(setting("refreshIntervalMs", 2000)))
  readonly property string cli: String(Qt.resolvedUrl("bin/mac-fan")).replace(/^file:\/\//, "")

  property var snap: null
  property string error: ""
  property bool busy: false
  property string pendingProfile: ""
  property string pendingPower: ""

  // The kernel's throttle figures are totals since boot, so "throttling now"
  // is a rise between two readings. It is the time spent throttled that is
  // compared, not the count of events: this CPU logs bursts of events that
  // add up to no measurable time, and a note that fires on those is noise.
  // The time of the last real rise is kept so the note does not flicker off
  // between polls.
  property int lastThrottle: -1
  property real lastRiseAt: 0
  readonly property bool throttlingNow: lastRiseAt > 0 && (Date.now() - lastRiseAt) < 15000

  readonly property var fan: snap && snap.fans && snap.fans.length > 0 ? snap.fans[0] : null
  readonly property var cpu: snap ? snap.cpu : null
  readonly property string profile: pendingProfile !== "" ? pendingProfile
    : (snap && snap.mbpfan && snap.mbpfan.profile ? snap.mbpfan.profile : "")
  readonly property string power: pendingPower !== "" ? pendingPower
    : (snap && snap.power && snap.power.profile ? snap.power.profile : "")
  readonly property bool canWrite: snap && snap.helper && snap.helper.installed ? true : false

  readonly property var profileText: ({
    "quiet": "The fan stays at its minimum until the CPU passes 68°C, and is only flat out at 86°C. Quietest, and the CPU runs hotter.",
    "balanced": "The fan starts ramping at 55°C and is flat out at 80°C. The setting this Mac was already running.",
    "performance": "The fan never drops below 40% and ramps from 50°C, flat out at 72°C, so the CPU keeps more turbo headroom under a long load.",
    "max": "The fan runs flat out all the time. For a long render or build; it is audible.",
    "custom": "/etc/mbpfan.conf has been edited to values that are not one of these profiles."
  })

  function tempColor(t) {
    if (t === null || t === undefined) return root.dim
    if (t >= 90) return root.badColor
    if (t >= 80) return root.warnColor
    return root.foreground
  }

  // ------------------------------------------------------------- the script

  function poll() {
    if (reader.running || writer.running) return
    reader.running = true
  }

  function ingest(text) {
    var parsed = null
    try { parsed = JSON.parse(String(text)) } catch (e) { root.error = "Could not parse mac-fan output"; return }
    if (!parsed || typeof parsed !== "object") return
    var t = parsed.throttle ? Number(parsed.throttle.packageMs) : -1
    if (root.lastThrottle >= 0 && t - root.lastThrottle >= 50) root.lastRiseAt = Date.now()
    root.lastThrottle = t
    root.snap = parsed
    root.pendingProfile = ""
    root.pendingPower = ""
  }

  function run(argv) {
    if (writer.running) return
    root.error = ""
    root.busy = true
    writer.argv = argv
    writer.running = true
  }

  function setProfile(name) { root.pendingProfile = name; run(["profile", name]) }
  function setPower(name) { root.pendingPower = name; run(["power", name]) }

  Process {
    id: reader
    command: [root.cli, "status"]
    running: false
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.ingest(text) }
  }

  Process {
    id: writer
    property var argv: []
    // Each action prints a fresh status when it is done, so the panel never
    // draws the state from before its own change.
    command: [root.cli].concat(writer.argv)
    running: false
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.ingest(text) }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: { var t = String(text || "").trim(); if (t !== "") root.error = t }
    }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) {
        root.pendingProfile = ""
        root.pendingPower = ""
        if (root.error === "") root.error = "mac-fan exited " + exitCode
      }
      root.poll()
    }
  }

  Timer {
    running: true
    interval: root.opened ? root.refreshMs : 60000
    repeat: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }

  // ------------------------------------------------------- open/close contract

  property bool openedFromHotkey: false

  function open() { openedFromHotkey = false; root.controller.show(); root.poll() }
  function openFromHotkey() { openedFromHotkey = true; root.controller.show(); root.poll() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.openFromHotkey() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      root.bar.switchPanelFrom(root.barIdentity, direction)
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.poll() }
    // For keybindings: `omarchy-shell brightwalker25.mac-fan performance`
    function quiet(): void { root.setProfile("quiet") }
    function balanced(): void { root.setProfile("balanced") }
    function performance(): void { root.setProfile("performance") }
    function max(): void { root.setProfile("max") }
  }

  // ------------------------------------------------------------- components

  component Stat: Column {
    id: stat
    property string caption: ""
    property string reading: ""
    property color readingColor: root.foreground
    spacing: Style.space(2)

    Text {
      textFormat: Text.PlainText
      text: stat.reading
      color: stat.readingColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }

    Text {
      textFormat: Text.PlainText
      text: stat.caption.toUpperCase()
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1.2
    }
  }

  component Note: Item {
    id: note
    property string message: ""
    property color accent: root.warnColor
    visible: message !== ""
    implicitHeight: visible ? noteText.implicitHeight : 0

    Rectangle {
      id: rule
      anchors.left: parent.left
      width: Style.space(3)
      height: parent.height
      radius: 1
      color: note.accent
    }

    Text {
      id: noteText
      textFormat: Text.PlainText
      anchors.left: rule.right
      anchors.leftMargin: Style.spacing.sm
      anchors.right: parent.right
      text: note.message
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  component Caption: Text {
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  // ------------------------------------------------------------------ layout

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: flick.width
          spacing: Style.spacing.lg

          // ---- Hero: fan speed and CPU temperature, the two numbers the
          // profiles trade against each other.
          Column {
            width: parent.width
            spacing: Style.spacing.xxs

            Text {
              textFormat: Text.PlainText
              text: root.fan ? (root.fan.label.toUpperCase() + " FAN") : "FAN"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }

            Row {
              spacing: Style.space(28)

              Text {
                id: rpmText
                textFormat: Text.PlainText
                text: root.fan && root.fan.rpm !== null ? root.fan.rpm + " rpm" : "-"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 34
                font.bold: true
              }

              Text {
                textFormat: Text.PlainText
                anchors.baseline: rpmText.baseline
                text: root.cpu && root.cpu.packageC !== null ? Math.round(root.cpu.packageC) + "°C" : ""
                color: root.tempColor(root.cpu ? root.cpu.packageC : null)
                font.family: root.fontFamily
                font.pixelSize: 34
                font.bold: true
              }
            }

            Caption {
              width: parent.width
              text: {
                if (!root.fan) return "No Apple SMC fan found."
                var s = "Fan at " + root.fan.percent + "% of its " + root.fan.minRpm + " to " + root.fan.maxRpm + " rpm range"
                if (!root.fan.manual) s += ", under the firmware's own control"
                return s + ", and the CPU package temperature."
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.spacing.lg

            Stat {
              caption: "clock now"
              reading: root.cpu && root.cpu.maxNowMhz ? (root.cpu.maxNowMhz / 1000).toFixed(1) + " GHz" : "-"
            }

            Stat {
              caption: "turbo max"
              reading: root.cpu && root.cpu.turboMhz ? (root.cpu.turboMhz / 1000).toFixed(1) + " GHz" : "-"
              readingColor: root.cpu && root.cpu.turbo === false ? root.warnColor : root.foreground
            }

            Stat {
              caption: "throttling"
              reading: root.throttlingNow ? "now" : "no"
              readingColor: root.throttlingNow ? root.warnColor : root.okColor
            }
          }

          // ---- Fan profile
          Column {
            width: parent.width
            spacing: Style.spacing.md

            PanelSeparator { width: parent.width; foreground: root.foreground }

            PanelSectionHeader {
              text: "Fan profile"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            ButtonGroup {
              width: parent.width
              enabled: root.canWrite && !root.busy
              opacity: enabled ? 1.0 : 0.45
              options: [
                { value: "quiet", label: "Quiet" },
                { value: "balanced", label: "Balanced" },
                { value: "performance", label: "Perform" },
                { value: "max", label: "Max" }
              ]
              value: root.profile
              foreground: root.foreground
              background: root.bar ? root.bar.background : Color.background
              fontFamily: root.fontFamily
              focusable: false
              onChanged: function(v) { if (v !== root.profile) root.setProfile(v) }
            }

            Caption {
              width: parent.width
              text: root.profileText[root.profile] || ""
              visible: text !== ""
            }
          }

          // ---- Power profile. Separate from the fan: the fan decides how hot
          // the CPU is allowed to get, this decides how hard it tries to boost.
          Column {
            width: parent.width
            spacing: Style.spacing.md
            visible: root.power !== ""

            PanelSeparator { width: parent.width; foreground: root.foreground }

            PanelSectionHeader {
              text: "Power profile"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            ButtonGroup {
              width: parent.width
              enabled: !root.busy
              opacity: enabled ? 1.0 : 0.45
              options: [
                { value: "power-saver", label: "Saver" },
                { value: "balanced", label: "Balanced" },
                { value: "performance", label: "Perform" }
              ]
              value: root.power
              foreground: root.foreground
              background: root.bar ? root.bar.background : Color.background
              fontFamily: root.fontFamily
              focusable: false
              onChanged: function(v) { if (v !== root.power) root.setPower(v) }
            }

            Caption {
              width: parent.width
              text: "For the most speed, pair Performance here with the Performance or Max fan profile."
            }
          }

          // ---- Anything the script or the last action wants said.
          Column {
            width: parent.width
            spacing: Style.spacing.sm
            visible: root.error !== "" || root.throttlingNow
              || (root.snap && root.snap.warnings && root.snap.warnings.length > 0)

            PanelSeparator { width: parent.width; foreground: root.foreground }

            Note {
              width: parent.width
              message: root.error
              accent: root.badColor
            }

            Note {
              width: parent.width
              message: root.throttlingNow
                ? "The CPU is throttling to stay under its temperature limit. A faster fan profile gives it more room." : ""
            }

            Repeater {
              model: root.snap && root.snap.warnings ? root.snap.warnings : []
              delegate: Note {
                required property var modelData
                width: column.width
                message: String(modelData)
              }
            }
          }
        }
      }
    }
  }
}
