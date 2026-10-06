pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Ui as Ui
import qs.Commons
import "Game.js" as Game

Ui.Panel {
    id: root
    moduleName: "grivera.solitaire"
    ipcTarget: "grivera.solitaire"
    readonly property var svc: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
    readonly property var g: svc && svc.game ? svc.game : Game.deal(1, 1, "")
    readonly property color gold: "#d9bd7c"
    readonly property color ink: "#f0eadb"
    readonly property color muted: "#a8beb1"
    property var selection: null
    property var hintMove: null
    property var dragSource: null
    property var dragCards: []
    property bool dragging: false
    property point dragStart: Qt.point(0, 0)
    property point dragPoint: Qt.point(0, 0)
    property point dragOffset: Qt.point(0, 0)
    property string message: "Make yourself a little space. One card at a time."
    property string pendingDeal: ""
    property bool helpOpen: false
    property bool winDismissed: false
    property bool keyboardMode: false
    property int cursorRow: 1
    property int cursorColumn: 0
    property int cursorIndex: 0
    readonly property string sessionToken: Date.now().toString(36) + Math.random().toString(36)
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function clock(seconds) {
        var h = Math.floor(seconds / 3600), m = Math.floor(seconds % 3600 / 60), s = seconds % 60
        return (h ? h + ":" + ("0" + m).slice(-2) : String(m)) + ":" + ("0" + s).slice(-2)
    }
    function same(a, b) { return !!a && !!b && a.kind === b.kind && a.pile === b.pile && a.index === b.index }
    function selected(kind, pile, index) {
        return selection && selection.kind === kind && selection.pile === pile &&
            (kind !== "tableau" || index >= selection.index)
    }
    function hidden(kind, pile, index) {
        return dragging && dragSource && dragSource.kind === kind && dragSource.pile === pile &&
            (kind !== "tableau" || index >= dragSource.index)
    }
    function suggested(kind, pile) { return hintMove && hintMove.dst && hintMove.dst.kind === kind && hintMove.dst.pile === pile }
    function legal(kind, pile) { return selection && Game.canMove(g, selection, {kind:kind, pile:pile}) }
    function clearDrag() { dragging = false; dragSource = null; dragCards = [] }
    function clearSelection() { selection = null; hintMove = null; clearDrag() }
    function startDrag(src, px, py, lx, ly) {
        if (!svc || !svc.ready || g.won) return
        dragCards = Game.stack(g, src)
        if (!dragCards.length) return
        dragSource = src; dragStart = Qt.point(px, py); dragPoint = dragStart; dragOffset = Qt.point(lx, ly)
        keyboardMode = false
    }
    function moveDrag(px, py) {
        if (!dragSource) return
        dragPoint = Qt.point(px, py)
        if (Math.abs(px - dragStart.x) + Math.abs(py - dragStart.y) > 7) {
            dragging = true; selection = dragSource; hintMove = null
        }
    }
    function releaseDrag(px, py) {
        var src = dragSource, wasDragging = dragging
        clearDrag()
        if (!src) return
        if (!wasDragging) { clickCard(src); return }
        var p = keyStage.mapToItem(board, px, py)
        var col = Math.round((p.x - board.cardW / 2) / board.stepX)
        var dst = null
        if (p.x >= -8 && p.x <= board.width + 8 && col >= 0 && col <= 6) {
            if (p.y >= -8 && p.y < board.cardH + 24 && col >= 3) dst = {kind:"foundation", pile:col - 3}
            else if (p.y >= board.tableauY - 10 && p.y <= board.height + 8) dst = {kind:"tableau", pile:col}
        }
        if (dst && svc.move(src, dst)) message = g.won ? "A perfect little ending." : "Nicely placed."
        else { selection = src; message = "Build downward in alternating colors. Only a king fills an empty column." }
    }
    function clickCard(src) {
        if (g.won || !svc || !svc.ready) return
        if (selection && !same(selection, src) && svc.move(selection, {kind:src.kind, pile:src.pile})) {
            message = "Nicely placed."; clearSelection(); return
        }
        if (same(selection, src)) { clearSelection(); return }
        if (Game.stack(g, src).length) { selection = src; hintMove = null; message = "Choose a column or foundation, or drag this card." }
    }
    function clickEmpty(kind, pile) {
        if (selection && svc && svc.move(selection, {kind:kind, pile:pile})) { clearSelection(); message = "Nicely placed." }
        else if (selection) message = kind === "tableau" ? "Only a king can begin an empty column." : "Foundations start with aces and build upward in the same suit."
    }
    function home(src) {
        var cards = Game.stack(g, src)
        if (cards.length === 1 && svc && svc.move(src, {kind:"foundation", pile:Game.suit(cards[0])})) { clearSelection(); message = "One more card home." }
        else message = "That card is not ready for a foundation yet."
    }
    function draw() {
        var recycle = !g.stock.length
        clearSelection()
        if (svc && svc.draw()) message = recycle ? "A fresh pass through the stock. −20 points." : "Look for a new opening."
        else message = g.won ? "All four suits are home." : "The stock is empty. Try a hint or undo."
    }
    function hint() {
        clearSelection(); hintMove = Game.hint(g); selection = hintMove.src || null; message = hintMove.text
    }
    function undo() { clearSelection(); if (svc && svc.undo()) message = "Move undone. You have room to rethink." }
    function redo() { clearSelection(); if (svc && svc.redo()) message = "Move restored." }
    function autoFinish() { clearSelection(); if (svc && svc.finish()) message = "All four suits are home." }
    function requestDeal(kind) {
        if (!svc || !svc.ready) return
        if (g.moves && !g.won) pendingDeal = kind
        else beginDeal(kind)
    }
    function beginDeal(kind) {
        clearSelection(); helpOpen = false; pendingDeal = ""; winDismissed = false
        var drawCount = kind === "draw3" ? 3 : kind === "draw1" || kind === "daily" ? 1 : g.draw
        svc.newGame(drawCount, kind === "daily", kind === "restart")
        message = kind === "daily" ? "Today's deal is the same for everyone. Take your time." : kind === "restart" ? "Same cards. A fresh perspective." : "A fresh deal. Let's see where it takes you."
        cursorColumn = 0; cursorRow = 1; cursorIndex = g.tableau[0].length - 1
    }
    function moveCursor(dx, dy) {
        keyboardMode = true
        if (dx) { cursorColumn = (cursorColumn + dx + 7) % 7; cursorIndex = g.tableau[cursorColumn].length - 1 }
        if (dy && cursorRow === 0) { if (dy > 0) { cursorRow = 1; cursorIndex = g.tableau[cursorColumn].length - 1 } }
        else if (dy < 0) {
            if (cursorIndex > g.down[cursorColumn]) cursorIndex--
            else cursorRow = 0
        } else if (dy > 0) cursorIndex = Math.min(g.tableau[cursorColumn].length - 1, cursorIndex + 1)
    }
    function activateCursor() {
        if (cursorRow === 0) {
            if (cursorColumn === 0) draw()
            else if (cursorColumn === 1 && g.waste.length) clickCard({kind:"waste", pile:0, index:g.waste.length - 1})
            else if (cursorColumn >= 3) {
                var p = cursorColumn - 3, f = g.foundations[p]
                if (f.length) clickCard({kind:"foundation", pile:p, index:f.length - 1})
                else clickEmpty("foundation", p)
            }
        } else if (g.tableau[cursorColumn].length) clickCard({kind:"tableau", pile:cursorColumn,
            index:Math.max(g.down[cursorColumn], Math.min(cursorIndex, g.tableau[cursorColumn].length - 1))})
        else clickEmpty("tableau", cursorColumn)
    }
    Connections {
        target: root.svc
        function onGameChanged() {
            root.clearSelection(); root.winDismissed = false
            root.cursorIndex = Math.max(0, Math.min(root.cursorIndex, root.g.tableau[root.cursorColumn].length - 1))
        }
        function onNoticeChanged() { if (root.svc.notice) root.message = root.svc.notice }
    }
    onOpenedChanged: {
        clearDrag()
        if (svc) svc.setPanelOpen(sessionToken, opened)
        if (opened) { keyboardMode = false; if (svc && svc.notice) message = svc.notice }
    }
    onSvcChanged: if (svc && opened) svc.setPanelOpen(sessionToken, true)
    Component.onDestruction: if (svc) svc.setPanelOpen(sessionToken, false)

    Ui.WidgetButton {
        id: button; bar: root.bar; text: "♠"; fontFamily: "DejaVu Serif"
        fontSize: Style.bar.iconFont; tooltipText: "Solitaire · " + (root.g.daily ? "Daily deal" : "Draw " + root.g.draw) + " · " + root.g.score + " points"
        onPressed: function(mouseButton) { if (mouseButton === Qt.RightButton) { root.open(); root.helpOpen = true } else root.toggle() }
    }

    Ui.KeyboardPanel {
        id: popup; anchorItem: button; owner: root; bar: root.bar; open: root.opened
        focusTarget: keyStage; padding: 0; centerOnBar: true
        contentWidth: fittedContentWidth(900)
        contentHeight: cappedContentHeight(740)

        Item {
            id: keyStage; anchors.fill: parent; focus: true; clip: true
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(e) {
                if (e.key === Qt.Key_Escape) {
                    if (root.pendingDeal) root.pendingDeal = ""
                    else if (root.helpOpen) root.helpOpen = false
                    else if (root.selection) root.clearSelection()
                    else root.close()
                } else if (root.pendingDeal) { if (e.key === Qt.Key_Return) root.beginDeal(root.pendingDeal) }
                else if (root.helpOpen) { if (e.key === Qt.Key_Question || e.key === Qt.Key_F1) root.helpOpen = false }
                else if (e.key === Qt.Key_Z && (e.modifiers & Qt.ControlModifier)) { if (e.modifiers & Qt.ShiftModifier) root.redo(); else root.undo() }
                else if (e.key === Qt.Key_Y && (e.modifiers & Qt.ControlModifier)) root.redo()
                else if (e.key === Qt.Key_Left) root.moveCursor(-1, 0)
                else if (e.key === Qt.Key_Right) root.moveCursor(1, 0)
                else if (e.key === Qt.Key_Up) root.moveCursor(0, -1)
                else if (e.key === Qt.Key_Down) root.moveCursor(0, 1)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.activateCursor()
                else if (e.key === Qt.Key_Space) root.draw()
                else if (e.key === Qt.Key_U) root.undo()
                else if (e.key === Qt.Key_R) root.redo()
                else if (e.key === Qt.Key_H) root.hint()
                else if (e.key === Qt.Key_F && root.selection) root.home(root.selection)
                else if (e.key === Qt.Key_A) root.autoFinish()
                else if (e.key === Qt.Key_N) root.requestDeal("new")
                else if (e.key === Qt.Key_D) root.requestDeal("daily")
                else if (e.key === Qt.Key_Question || e.key === Qt.Key_F1) root.helpOpen = true
                else return
                e.accepted = true
            }
            Rectangle {
                anchors.fill: parent; radius: 12
                gradient: Gradient {
                    GradientStop { position: 0; color: root.svc && root.svc.midnight ? "#202d41" : "#214b3e" }
                    GradientStop { position: 1; color: root.svc && root.svc.midnight ? "#101b2c" : "#12382e" }
                }
            }
            Rectangle { x: 18; y: 18; width: parent.width - 36; height: parent.height - 36; radius: 8; color: "transparent"; border.color: "#30d9bd7c" }
            Row {
                x: 32; y: 24; spacing: 13
                Text { text: "♠"; color: root.gold; font.family: "DejaVu Serif"; font.pixelSize: 35 }
                Column {
                    spacing: 4
                    Text { text: "SOLITAIRE"; color: root.ink; font.family: "DejaVu Serif"; font.pixelSize: 24; font.letterSpacing: 3 }
                    Text { text: root.g.daily ? "DAILY TABLE  /  " + root.g.daily : "KLONDIKE  /  DEAL " + root.g.seed.toString(36).toUpperCase(); color: root.muted; font.pixelSize: 10; font.letterSpacing: 1.2 }
                }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 30; y: 27; spacing: 8
                ActionButton { label: root.svc && root.svc.midnight ? "☀  Felt" : "☾  Midnight"; onClicked: if (root.svc) root.svc.midnight = !root.svc.midnight }
                ActionButton { label: "?"; width: 34; onClicked: root.helpOpen = true }
                ActionButton { label: "×"; width: 34; onClicked: root.close() }
            }
            Rectangle { x: 30; y: 82; width: parent.width - 60; height: 1; color: "#26d9bd7c" }
            Row {
                x: 32; y: 94; spacing: 30
                Repeater {
                    model: [
                        {name:"SCORE", value:String(root.g.score)},
                        {name:"TIME", value:root.clock(root.svc ? root.svc.elapsed : 0)},
                        {name:"MOVES", value:String(root.g.moves)}
                    ]
                    Row {
                        required property var modelData; spacing: 9
                        Text { text: modelData.name; color: root.muted; font.pixelSize: 10; font.letterSpacing: 1; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.value; color: root.ink; font.pixelSize: 18; font.family: "DejaVu Sans Mono" }
                    }
                }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 32; y: 99
                text: root.g.foundations.reduce(function(n,p) { return n + p.length }, 0) + " / 52 HOME"
                color: root.gold; font.pixelSize: 11; font.letterSpacing: 1
            }
            Row {
                id: toolbar; x: 30; y: 130; spacing: 6
                scale: Math.min(1, (keyStage.width - 60) / implicitWidth); transformOrigin: Item.TopLeft
                ActionButton { label: "New deal"; emphasized: true; onClicked: root.requestDeal("new") }
                ActionButton { label: "Daily"; chosen: !!root.g.daily; onClicked: root.requestDeal("daily") }
                ActionButton { label: "Draw 1"; chosen: root.g.draw === 1; onClicked: root.requestDeal("draw1") }
                ActionButton { label: "Draw 3"; chosen: root.g.draw === 3; onClicked: root.requestDeal("draw3") }
                ActionButton { label: "↶ Undo"; enabled: root.svc && root.svc.canUndo; onClicked: root.undo() }
                ActionButton { label: "↷ Redo"; enabled: root.svc && root.svc.canRedo; onClicked: root.redo() }
                ActionButton { label: "Hint"; enabled: !root.g.won; onClicked: root.hint() }
                ActionButton { label: root.svc && root.svc.canFinish ? "Finish ✦" : "Restart"; onClicked: root.svc && root.svc.canFinish ? root.autoFinish() : root.requestDeal("restart") }
            }
            Item {
                id: board; x: 30; y: 183; width: parent.width - 60; height: parent.height - y - 48
                readonly property real cardW: Math.min(98, (width - 6 * 12) / 7, Math.max(42, (height - 50) / 3.1))
                readonly property real cardH: cardW * 1.43
                readonly property real stepX: (width - cardW) / 6
                readonly property real tableauY: cardH + 48
                readonly property real tableHeight: height - tableauY
                function offset(pile, index) {
                    var down = root.g.down[pile], len = root.g.tableau[pile].length
                    var natural = Math.min(down, Math.max(0, len - 1)) * 13 + Math.max(0, len - 1 - down) * 27
                    var scale = natural > 0 ? Math.min(1, Math.max(0, tableHeight - cardH - 2) / natural) : 1
                    return (Math.min(index, down) * 13 + Math.max(0, index - down) * 27) * scale
                }
                MouseArea { anchors.fill: parent; onClicked: root.clearSelection() }
                // Stock. The top card is never exposed until the stock is drawn.
                Item {
                    x: 0; width: board.cardW; height: board.cardH
                    Rectangle { anchors.fill: parent; radius: 7; color: "#14000000"; border.width: 1; border.color: root.hintMove && root.hintMove.draw ? root.gold : "#42d8e0ce" }
                    Text { anchors.centerIn: parent; text: root.g.waste.length ? "↻" : "·"; color: root.muted; font.pixelSize: 36 }
                    Card { anchors.fill: parent; faceUp: false; interactive: false; visible: root.g.stock.length > 0; selected: root.hintMove && root.hintMove.draw; backColor: root.svc && root.svc.midnight ? "#344764" : "#20594f" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.draw() }
                    Text { anchors.top: parent.bottom; anchors.topMargin: 9; anchors.horizontalCenter: parent.horizontalCenter; text: root.g.stock.length ? "STOCK · " + root.g.stock.length : root.g.waste.length ? "RECYCLE" : "EMPTY"; color: root.muted; font.pixelSize: 9; font.letterSpacing: 1 }
                }
                Item {
                    x: board.stepX; width: board.cardW; height: board.cardH
                    Rectangle { anchors.fill: parent; radius: 7; color: "#10000000"; border.color: "#28d8e0ce" }
                    Repeater {
                        model: root.g.waste.slice(-Math.min(root.g.draw, 3))
                        Card {
                            required property int index; required property var modelData
                            readonly property int count: Math.min(root.g.waste.length, root.g.draw)
                            readonly property var source: ({kind:"waste", pile:0, index:root.g.waste.length - 1})
                            x: index * 15; width: board.cardW; height: board.cardH; card: modelData; stage: keyStage
                            interactive: index === count - 1
                            selected: index === count - 1 && root.selected("waste", 0, 0)
                            opacity: index === count - 1 && root.hidden("waste", 0, 0) ? 0 : 1
                            onPointerDown: function(px,py,lx,ly) { root.startDrag(source,px,py,lx,ly) }
                            onPointerMoved: function(px,py) { root.moveDrag(px,py) }
                            onPointerUp: function(px,py) { root.releaseDrag(px,py) }
                            onCanceled: root.clearDrag()
                            onDoubleClicked: root.home(source)
                        }
                    }
                    Text { anchors.top: parent.bottom; anchors.topMargin: 9; anchors.horizontalCenter: parent.horizontalCenter; text: "WASTE"; color: root.muted; font.pixelSize: 9; font.letterSpacing: 1 }
                }
                Repeater {
                    model: 4
                    Item {
                        id: homeSlot
                        required property int index
                        readonly property var pile: root.g.foundations[index]
                        readonly property var source: ({kind:"foundation", pile:index, index:pile.length - 1})
                        x: (index + 3) * board.stepX; width: board.cardW; height: board.cardH
                        Rectangle { anchors.fill: parent; radius: 7; color: "#13000000"; border.width: root.legal("foundation", homeSlot.index) || root.suggested("foundation", homeSlot.index) ? 2 : 1; border.color: root.legal("foundation", homeSlot.index) || root.suggested("foundation", homeSlot.index) ? root.gold : "#45d9bd7c" }
                        Text { anchors.centerIn: parent; text: Game.suits[homeSlot.index]; color: "#60d9bd7c"; font.family: "DejaVu Serif"; font.pixelSize: board.cardW * 0.48 }
                        MouseArea { anchors.fill: parent; cursorShape: root.selection ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.clickEmpty("foundation", homeSlot.index) }
                        Card {
                            anchors.fill: parent; visible: homeSlot.pile.length > 0; stage: keyStage
                            card: homeSlot.pile.length ? homeSlot.pile[homeSlot.pile.length - 1] : 0
                            selected: root.selected("foundation", homeSlot.index, 0)
                            opacity: root.hidden("foundation", homeSlot.index, 0) ? 0 : 1
                            onPointerDown: function(px,py,lx,ly) { root.startDrag(homeSlot.source,px,py,lx,ly) }
                            onPointerMoved: function(px,py) { root.moveDrag(px,py) }
                            onPointerUp: function(px,py) { root.releaseDrag(px,py) }
                            onCanceled: root.clearDrag()
                        }
                        Text { anchors.top: parent.bottom; anchors.topMargin: 9; anchors.horizontalCenter: parent.horizontalCenter; text: "FOUNDATION"; color: root.muted; font.pixelSize: 9; font.letterSpacing: 0.6 }
                    }
                }
                Repeater {
                    model: 7
                    Item {
                        id: columnSlot
                        required property int index
                        x: index * board.stepX; y: board.tableauY; width: board.cardW; height: board.tableHeight
                        Rectangle { width: parent.width; height: board.cardH; radius: 7; color: "#10000000"; border.width: root.legal("tableau", columnSlot.index) || root.suggested("tableau", columnSlot.index) ? 2 : 1; border.color: root.legal("tableau", columnSlot.index) || root.suggested("tableau", columnSlot.index) ? root.gold : "#34d8e0ce" }
                        Text { y: board.cardH / 2 - height / 2; anchors.horizontalCenter: parent.horizontalCenter; text: "K"; color: "#45d8e0ce"; font.family: "DejaVu Serif"; font.pixelSize: 27 }
                        MouseArea { anchors.fill: parent; cursorShape: root.selection ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.clickEmpty("tableau", columnSlot.index) }
                        Repeater {
                            model: root.g.tableau[columnSlot.index]
                            Card {
                                required property int index; required property var modelData
                                readonly property var source: ({kind:"tableau", pile:columnSlot.index, index:index})
                                y: board.offset(columnSlot.index, index); width: board.cardW; height: board.cardH; card: modelData; stage: keyStage
                                faceUp: index >= root.g.down[columnSlot.index]
                                selected: root.selected("tableau", columnSlot.index, index)
                                opacity: root.hidden("tableau", columnSlot.index, index) ? 0 : 1
                                onPointerDown: function(px,py,lx,ly) { root.startDrag(source,px,py,lx,ly) }
                                onPointerMoved: function(px,py) { root.moveDrag(px,py) }
                                onPointerUp: function(px,py) { root.releaseDrag(px,py) }
                                onCanceled: root.clearDrag()
                                onDoubleClicked: root.home(source)
                            }
                        }
                    }
                }
                Rectangle {
                    visible: root.keyboardMode; z: 200; color: "transparent"; radius: 9; border.width: 2; border.color: "#f2dfaa"
                    x: root.cursorColumn * board.stepX - 4
                    y: root.cursorRow === 0 ? -4 : board.tableauY + board.offset(root.cursorColumn, Math.max(0, root.cursorIndex)) - 4
                    width: board.cardW + 8; height: board.cardH + 8
                }
            }
            Item {
                visible: root.dragging; z: 1000; x: root.dragPoint.x - root.dragOffset.x; y: root.dragPoint.y - root.dragOffset.y
                width: board.cardW; height: board.cardH + root.dragCards.length * 20
                Repeater { model: root.dragCards; Card { required property int index; required property var modelData; y: index * 20; width: board.cardW; height: board.cardH; card: modelData; interactive: false; selected: true } }
            }
            Rectangle { x: 30; y: parent.height - 43; width: parent.width - 60; height: 1; color: "#26d9bd7c" }
            Text {
                x: 32; y: parent.height - 30; width: parent.width - 205; elide: Text.ElideRight
                text: root.message; color: root.hintMove ? root.gold : root.muted; font.pixelSize: 11
            }
            Text { anchors.right: parent.right; anchors.rightMargin: 32; y: parent.height - 30; text: "SPACE draw  ·  H hint"; color: "#7e9d90"; font.pixelSize: 10 }

            // Confirmation protects an in-progress deal when modes change.
            Rectangle {
                anchors.fill: parent; z: 2000; color: "#bb071510"; visible: root.pendingDeal !== ""
                MouseArea { anchors.fill: parent }
                Rectangle {
                    anchors.centerIn: parent; width: Math.min(parent.width - 50, 450); height: 224; radius: 15; color: "#18382e"; border.color: root.gold
                    Column {
                        anchors.fill: parent; anchors.margins: 26; spacing: 17
                        Text { text: root.pendingDeal === "restart" ? "A fresh look at this deal?" : "Ready for a new table?"; color: root.ink; font.family: "DejaVu Serif"; font.pixelSize: 22 }
                        Text { width: parent.width; wrapMode: Text.WordWrap; text: "Your current deal will be replaced. Your lifetime statistics stay with you."; color: root.muted; font.pixelSize: 13 }
                        Row { spacing: 10; ActionButton { label: "Keep playing"; onClicked: root.pendingDeal = "" } ActionButton { label: "Deal cards"; emphasized: true; onClicked: root.beginDeal(root.pendingDeal) } }
                    }
                }
            }
            Rectangle {
                anchors.fill: parent; z: 2001; color: "#cb071510"; visible: root.helpOpen
                MouseArea { anchors.fill: parent; onClicked: root.helpOpen = false }
                Rectangle {
                    anchors.centerIn: parent; width: Math.min(parent.width - 50, 570); height: Math.min(parent.height - 45, 565); radius: 15; color: "#18382e"; border.color: "#8bd9bd7c"
                    MouseArea { anchors.fill: parent }
                    Flickable {
                        anchors.fill: parent; anchors.margins: 26; clip: true; contentHeight: guide.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: guide; width: parent.width; spacing: 15
                            Text { text: "A quiet little card table"; color: root.ink; font.family: "DejaVu Serif"; font.pixelSize: 25 }
                            Text { width: parent.width; text: "Bring all 52 cards home. Foundations build from ace to king in the same suit. On the table, build downward in alternating colors; move a face-up sequence together. Only a king starts an empty column."; color: root.muted; wrapMode: Text.WordWrap; font.pixelSize: 13; lineHeight: 1.25 }
                            Text { width: parent.width; text: "Click a card, then its destination, or drag the card and its stack. Double-click an exposed card to send it home. Draw-three shows three waste cards, but only the top card can move. Recycle the stock as often as you like."; color: root.muted; wrapMode: Text.WordWrap; font.pixelSize: 13; lineHeight: 1.25 }
                            Text { text: "AT YOUR FINGERTIPS"; color: root.gold; font.pixelSize: 10; font.letterSpacing: 1.5 }
                            Text { width: parent.width; text: "Space   Draw / recycle     ·     H   Hint\nU / Ctrl+Z   Undo     ·     R / Ctrl+Shift+Z   Redo\nArrows   Navigate     ·     Enter   Select / place\nF   Send selected card home     ·     A   Auto-finish\nN   New deal     ·     D   Daily deal\nEsc   Clear selection / close     ·     ?   This guide"; color: root.ink; font.pixelSize: 12; lineHeight: 1.45 }
                            Text { width: parent.width; text: "+10 to a foundation · +5 from waste to table · +5 uncovering a card · −15 returning a foundation card · −20 recycling. Time pauses when the panel closes. Auto-finish appears once the stock is empty and every table card is face up. Daily deals use draw-one; they are repeatable, but are not guaranteed solvable."; color: root.muted; wrapMode: Text.WordWrap; font.pixelSize: 12; lineHeight: 1.25 }
                            Rectangle { width: parent.width; height: 1; color: "#35d9bd7c" }
                            Text { text: "YOUR TABLE RECORD"; color: root.gold; font.pixelSize: 10; font.letterSpacing: 1.5 }
                            Text {
                                text: root.svc ? root.svc.stats.wins + " wins  /  " + root.svc.stats.games + " deals played  /  " + (root.svc.stats.games ? Math.round(root.svc.stats.wins / root.svc.stats.games * 100) : 0) + "%" : ""
                                color: root.ink; font.pixelSize: 14
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap
                                text: {
                                    var best = root.svc ? root.svc.stats.best : {}, parts = []
                                    ;["draw1", "draw3", "daily"].forEach(function(k) { if (best[k]) parts.push((k === "daily" ? "Daily" : k === "draw1" ? "Draw 1" : "Draw 3") + ": " + root.clock(best[k].time) + " best time · " + best[k].score + " best score") })
                                    return parts.length ? parts.join("\n") : "Your first win starts the record."
                                }
                                color: root.muted; font.pixelSize: 12; lineHeight: 1.4
                            }
                            ActionButton { label: "Back to the table"; emphasized: true; onClicked: root.helpOpen = false }
                        }
                        ScrollBar.vertical: ScrollBar { width: 4; policy: ScrollBar.AsNeeded }
                    }
                }
            }
            Rectangle {
                anchors.fill: parent; z: 2000; color: "#ad071510"; visible: root.g.won && !root.winDismissed && !root.helpOpen && !root.pendingDeal
                MouseArea { anchors.fill: parent }
                Rectangle {
                    anchors.centerIn: parent; width: Math.min(parent.width - 50, 490); height: 300; radius: 16; color: "#18382e"; border.color: root.gold
                    Column {
                        anchors.centerIn: parent; spacing: 19; width: parent.width - 60
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "♣  ♦  ♠  ♥"; font.family: "DejaVu Serif"; font.pixelSize: 34; color: root.gold }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "All four suits are home."; color: root.ink; font.family: "DejaVu Serif"; font.pixelSize: 25 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.g.score + " points   ·   " + root.clock(root.svc ? root.svc.elapsed : 0) + "   ·   " + root.g.moves + " moves"; color: root.muted; font.pixelSize: 13 }
                        Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 10; ActionButton { label: "Admire the table"; onClicked: root.winDismissed = true } ActionButton { label: "Another deal"; emphasized: true; onClicked: root.beginDeal("new") } }
                    }
                }
            }
            Rectangle {
                anchors.fill: parent; z: 3000; color: "#18382e"; visible: !root.svc || !root.svc.ready
                Text { anchors.centerIn: parent; text: "Shuffling your table…"; color: root.gold; font.family: "DejaVu Serif"; font.pixelSize: 23 }
            }
        }
    }
}
