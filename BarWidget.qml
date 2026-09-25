import QtQuick
import qs.Commons
import qs.Ui

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 brightwalker25

// Derived from Omarchy's own `omarchy.weather` bar widget
// (https://github.com/basecamp/omarchy, MIT, Copyright (c) David Heinemeier
// Hansson), by way of this author's `brightwalker25.system`. The injectPanel /
// open / close / closeForPopoutSwitch contract below is what the bar requires
// of any widget hosting a panel.

// A fan in the bar, tinted green, amber or red; everything else is in the panel.
BarWidget {
  id: root
  moduleName: "brightwalker25.mac-fan"

  // nf-md-fan
  readonly property string glyph: "󰈐"

  readonly property var snap: panelLoader.item ? panelLoader.item.snap : null
  readonly property string status: snap && snap.rating ? String(snap.rating) : ""

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.poll) panelLoader.item.poll()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    slotSize: Style.bar.iconSlot
    tooltipText: ""

    // The same fixed green, amber and red as the other brightwalker25 widgets.
    useActiveColor: true
    active: root.status !== ""
    activeColor: root.status === "bad" ? "#f85149"
      : (root.status === "warn" ? "#d29922" : "#3fb950")

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
