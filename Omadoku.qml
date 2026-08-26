import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "SudokuEngine.js" as Sudoku

Item {
  id: root
  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool paused: false
  property bool notesMode: false
  property bool won: false
  property bool confirmNew: false
  property bool showStats: false
  property int selected: 0
  property int elapsed: 0
  property int mistakes: 0
  property var appState: Sudoku.createState()
  property var puzzle: new Array(81).fill(0)
  property var solution: new Array(81).fill(0)
  property var entries: new Array(81).fill(0)
  property var notes: new Array(81).fill(0)
  property var undoStack: []
  property var redoStack: []
  property string difficulty: "Medium"
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateBase: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
  readonly property string statePath: stateBase + "/omadoku.json"
  property bool stateReady: false

  function copy(value) { return JSON.parse(JSON.stringify(value)) }
  function cellValue(index) { return entries[index] || puzzle[index] || 0 }
  function save() {
    if (!stateReady) return
    if (!won && puzzle.some(function(v) { return v !== 0 })) {
      appState.game = { difficulty: difficulty, puzzle: puzzle, solution: solution,
        entries: entries, notes: notes, elapsed: elapsed, mistakes: mistakes,
        undo: undoStack.slice(-100), redo: redoStack.slice(-100), paused: true }
    } else appState.game = null
    stateFile.setText(JSON.stringify(appState, null, 2) + "\n")
  }
  function load(raw) {
    try { appState = Sudoku.normalizeState(raw && raw.trim() ? JSON.parse(raw) : null) }
    catch (e) { appState = Sudoku.createState() }
    stateReady = true
    if (appState.game) restoreGame(appState.game)
    else newGame("Medium", false)
  }
  function restoreGame(game) {
    difficulty = game.difficulty; puzzle = game.puzzle.slice(); solution = game.solution.slice()
    entries = game.entries.slice(); notes = game.notes.slice(); elapsed = Number(game.elapsed) || 0
    mistakes = Number(game.mistakes) || 0; undoStack = (game.undo || []).slice(); redoStack = (game.redo || []).slice()
    paused = false; won = false
  }
  function newGame(level, abandon) {
    if (abandon && appState.game && !won) Sudoku.recordAbandon(appState, difficulty)
    difficulty = level
    var generated = Sudoku.generate(level, Date.now() ^ Math.floor(Math.random() * 0x7fffffff))
    puzzle = generated.puzzle.slice(); solution = generated.solution.slice()
    entries = new Array(81).fill(0); notes = new Array(81).fill(0)
    undoStack = []; redoStack = []; elapsed = 0; mistakes = 0; selected = 0
    paused = false; won = false; confirmNew = false; showStats = false
    Sudoku.recordStart(appState, level)
    appState.game = { difficulty: level }
    save()
  }
  function open(payloadJson) {
    opened = true; paused = false; confirmNew = false
    Qt.callLater(function() { keys.forceActiveFocus() })
  }
  function close() { opened = false; paused = true; save() }
  function dismiss() {
    close()
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "doctor.omadoku")
  }
  function toggle() { if (opened) dismiss(); else open("{}") }
  function selectCell(index) { selected = Math.max(0, Math.min(80, index)); keys.forceActiveFocus() }
  function applySnapshot(snapshot) {
    entries = snapshot.entries.slice(); notes = snapshot.notes.slice(); mistakes = snapshot.mistakes
    save()
  }
  function snapshot() { return { entries: entries.slice(), notes: notes.slice(), mistakes: mistakes } }
  function enter(number) {
    if (paused || won || puzzle[selected]) return
    undoStack.push(snapshot()); if (undoStack.length > 100) undoStack.shift(); redoStack = []
    var nextEntries = entries.slice(), nextNotes = notes.slice()
    if (notesMode && number) {
      nextNotes[selected] = nextNotes[selected] ^ (1 << number)
    } else {
      nextEntries[selected] = number; nextNotes[selected] = 0
      if (number && number !== solution[selected]) mistakes++
    }
    entries = nextEntries; notes = nextNotes
    if (entries.every(function(v, i) { return puzzle[i] || v === solution[i] })) finishGame()
    else save()
  }
  function undo() {
    if (!undoStack.length) return
    redoStack.push(snapshot()); var snap = undoStack.pop(); applySnapshot(snap)
  }
  function redo() {
    if (!redoStack.length) return
    undoStack.push(snapshot()); var snap = redoStack.pop(); applySnapshot(snap)
  }
  function finishGame() {
    won = true; paused = true
    Sudoku.recordWin(appState, difficulty, elapsed, mistakes); appState.game = null; save()
  }
  function timeText(seconds) {
    var m = Math.floor(seconds / 60), s = seconds % 60
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
  }
  function statText(bucket) {
    var rate = bucket.started ? Math.round(bucket.won * 100 / bucket.started) : 0
    var avg = bucket.won ? Math.round(bucket.totalWinSeconds / bucket.won) : 0
    return "Played  " + bucket.started + "     Won  " + bucket.won + "     Win rate  " + rate + "%\n" +
      "Streak  " + bucket.currentStreak + "     Best streak  " + bucket.bestStreak + "\n" +
      "Best  " + (bucket.bestSeconds ? timeText(bucket.bestSeconds) : "—") + "     Average  " + (avg ? timeText(avg) : "—") + "     Mistakes  " + bucket.mistakes
  }

  Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", stateBase])

  FileView {
    id: stateFile
    path: root.statePath
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: root.load("")
  }
  Timer { interval: 1000; repeat: true; running: root.opened && !root.paused && !root.won; onTriggered: { root.elapsed++; if (root.elapsed % 10 === 0) root.save() } }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "doctor-omadoku"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: Color.menu.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      width: Math.min(Style.space(880), panel.width - Style.gapsOut * 2)
      height: Math.min(Style.space(700), panel.height - Style.gapsOut * 2)
      anchors.centerIn: parent
      color: Color.menu.background
      radius: Style.cornerRadius
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding
      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true }
          else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_Z) { root.undo(); event.accepted = true }
          else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_Y) { root.redo(); event.accepted = true }
          else if (event.key === Qt.Key_N) { root.notesMode = !root.notesMode; event.accepted = true }
          else if (event.key === Qt.Key_P) { root.paused = !root.paused; event.accepted = true }
          else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) { root.selectCell(root.selected % 9 ? root.selected - 1 : root.selected); event.accepted = true }
          else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) { root.selectCell(root.selected % 9 < 8 ? root.selected + 1 : root.selected); event.accepted = true }
          else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) { root.selectCell(root.selected >= 9 ? root.selected - 9 : root.selected); event.accepted = true }
          else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) { root.selectCell(root.selected < 72 ? root.selected + 9 : root.selected); event.accepted = true }
          else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) { root.enter(event.key - Qt.Key_0); event.accepted = true }
          else if (event.key === Qt.Key_0 || event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) { root.enter(0); event.accepted = true }
        }

        Text { id: title; text: "OMADOKU"; color: Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.title; font.bold: true }
        Text { anchors.right: parent.right; text: root.timeText(root.elapsed) + "   •   " + root.difficulty + "   •   " + root.mistakes + " mistakes"; color: Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body }

        Item {
          id: content
          anchors { top: title.bottom; topMargin: Style.spacing.lg; left: parent.left; right: parent.right; bottom: parent.bottom }
          property real boardSize: Math.min(height, width * 0.67)
          Rectangle {
            id: board
            width: content.boardSize; height: width
            color: Color.menu.background
            border.color: Color.menu.border; border.width: 2

            Grid {
              anchors.fill: parent; columns: 9; rows: 9
              Repeater {
                id: boardRepeater
                model: 81
                Rectangle {
                  id: cell
                  required property int index
                  property int row: Math.floor(index / 9)
                  property int col: index % 9
                  property int value: root.cellValue(index)
                  property bool related: row === Math.floor(root.selected / 9) || col === root.selected % 9 ||
                    (Math.floor(row / 3) === Math.floor(Math.floor(root.selected / 9) / 3) && Math.floor(col / 3) === Math.floor((root.selected % 9) / 3))
                  width: board.width / 9; height: board.height / 9
                  color: index === root.selected ? Color.menu.selectedBackground : (related ? Qt.rgba(Color.menu.selectedBackground.r, Color.menu.selectedBackground.g, Color.menu.selectedBackground.b, 0.35) : Color.menu.background)
                  border.color: Color.menu.border
                  border.width: (col % 3 === 0 || row % 3 === 0) ? 1.5 : 0.5
                  Text {
                    anchors.centerIn: parent
                    visible: parent.value > 0 && !root.paused
                    text: parent.value
                    color: root.puzzle[index] ? Color.menu.text : (parent.value !== root.solution[index] ? "#ff5f5f" : Color.menu.selectedText)
                    font.family: Style.font.menuFamily; font.pixelSize: Math.max(16, parent.width * 0.42); font.bold: root.puzzle[index] > 0
                  }
                  Grid {
                    visible: !parent.value && !root.paused
                    anchors.fill: parent; columns: 3; rows: 3
                    Repeater { model: 9; Text { required property int index; width: parent.width / 3; height: parent.height / 3; text: (root.notes[cell.index] & (1 << (index + 1))) ? String(index + 1) : ""; color: Color.menu.text; opacity: 0.75; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: Math.max(7, width * 0.45) } }
                  }
                  MouseArea { anchors.fill: parent; onClicked: root.selectCell(index) }
                }
              }
            }
            Rectangle { visible: root.paused && !root.won; anchors.fill: parent; color: Color.menu.background; opacity: 0.96; Text { anchors.centerIn: parent; text: "PAUSED\nPress P to continue"; horizontalAlignment: Text.AlignHCenter; color: Color.menu.text; font.pixelSize: Style.font.title } }
            Rectangle { visible: root.won; anchors.fill: parent; color: Color.menu.background; opacity: 0.96; Text { anchors.centerIn: parent; text: "SOLVED!\n" + root.timeText(root.elapsed) + "  •  " + root.mistakes + " mistakes"; horizontalAlignment: Text.AlignHCenter; color: Color.menu.selectedText; font.pixelSize: Style.font.title } }
          }

          Column {
            anchors { left: board.right; leftMargin: Style.spacing.xl; right: parent.right; top: parent.top }
            spacing: Style.spacing.md
            Text { text: root.notesMode ? "NOTES ON" : "NUMBER MODE"; color: root.notesMode ? Color.menu.selectedText : Color.menu.text; font.bold: true; font.pixelSize: Style.font.body }
            Grid {
              columns: 3; spacing: Style.spacing.sm
              Repeater { model: 9; Rectangle { required property int index; width: Style.space(54); height: width; radius: Style.cornerRadius; color: numberMouse.containsMouse ? Color.menu.selectedBackground : Color.menu.background; border.color: Color.menu.border; Text { anchors.centerIn: parent; text: index + 1; color: Color.menu.text; font.pixelSize: Style.font.title } MouseArea { id: numberMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.enter(index + 1) } } }
            }
            ActionButton { label: root.notesMode ? "Notes: on" : "Notes: off"; onClicked: root.notesMode = !root.notesMode }
            ActionButton { label: root.paused ? "Resume" : "Pause"; onClicked: root.paused = !root.paused }
            ActionButton { label: "Undo / Redo"; onClicked: root.undo() }
            ActionButton { label: root.showStats ? "Hide stats" : "Statistics"; onClicked: root.showStats = !root.showStats }
            ActionButton { label: "New game"; urgent: true; onClicked: root.confirmNew = true }
            Text { visible: root.showStats; width: parent.width; wrapMode: Text.WordWrap; text: "ALL GAMES\n" + root.statText(root.appState.stats.global) + "\n\n" + root.difficulty.toUpperCase() + "\n" + root.statText(root.appState.stats.byDifficulty[root.difficulty]); color: Color.menu.text; font.pixelSize: Style.font.bodySmall; lineHeight: 1.25 }
            Column { visible: root.confirmNew; spacing: Style.spacing.sm; Text { text: "Replace this game?"; color: Color.menu.text; font.bold: true } Row { spacing: Style.spacing.sm; Repeater { model: ["Easy", "Medium", "Hard", "Expert"]; Rectangle { required property var modelData; width: Style.space(72); height: Style.space(34); radius: Style.cornerRadius; color: Color.menu.selectedBackground; Text { anchors.centerIn: parent; text: modelData; color: Color.menu.selectedText; font.pixelSize: Style.font.bodySmall } MouseArea { anchors.fill: parent; onClicked: root.newGame(modelData, true) } } } } }
          }
        }
      }
    }
  }

  component ActionButton: Rectangle {
    property string label: ""
    property bool urgent: false
    signal clicked()
    width: Style.space(180); height: Style.space(36); radius: Style.cornerRadius
    color: actionMouse.containsMouse ? Color.menu.selectedBackground : Color.menu.background
    border.color: urgent ? "#ff5f5f" : Color.menu.border
    Text { anchors.centerIn: parent; text: parent.label; color: Color.menu.text; font.pixelSize: Style.font.body }
    MouseArea { id: actionMouse; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
  }
}
