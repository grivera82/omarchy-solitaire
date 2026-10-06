pragma ComponentBehavior: Bound
import QtQuick
import "Game.js" as Game

Item {
    id: root
    property int card: 0
    property bool faceUp: true
    property bool selected: false
    property bool interactive: true
    property bool topCard: false
    property Item stage: null
    property color backColor: "#20594f"
    readonly property string rankText: ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][Game.rank(card)]
    readonly property string suitText: Game.suits[Game.suit(card)]
    readonly property color ink: Game.red(card) ? "#b23c4f" : "#243731"
    readonly property var pipPositions: [[], [[0.5,0.5]], [[0.5,0],[0.5,1]],
        [[0.5,0],[0.5,0.5],[0.5,1]],
        [[0,0],[1,0],[0,1],[1,1]],
        [[0,0],[1,0],[0.5,0.5],[0,1],[1,1]],
        [[0,0],[1,0],[0,0.5],[1,0.5],[0,1],[1,1]],
        [[0,0],[1,0],[0.5,0.25],[0,0.5],[1,0.5],[0,1],[1,1]],
        [[0,0],[1,0],[0.5,0.25],[0,0.5],[1,0.5],[0.5,0.75],[0,1],[1,1]],
        [[0,0],[1,0],[0,0.33],[1,0.33],[0.5,0.5],[0,0.67],[1,0.67],[0,1],[1,1]],
        [[0,0],[1,0],[0.5,0.16],[0,0.33],[1,0.33],[0,0.67],[1,0.67],[0.5,0.84],[0,1],[1,1]]
    ][Math.min(10, Game.rank(card))]
    signal pointerDown(real px, real py, real localX, real localY)
    signal pointerMoved(real px, real py)
    signal pointerUp(real px, real py)
    signal canceled()
    signal doubleClicked()
    width: 94; height: width * 1.43
    Rectangle { x: 0; y: 3; width: parent.width; height: parent.height; radius: 8; color: "#50000000" }
    Rectangle {
        id: face; anchors.fill: parent; radius: 7
        color: root.faceUp ? "#f8f3e7" : root.backColor
        border.color: root.selected ? "#efd48c" : root.faceUp ? "#d4cdbb" : "#e6dbc1"
        border.width: root.selected ? 3 : 1
        Rectangle {
            visible: !root.faceUp; anchors.fill: parent; anchors.margins: 5
            radius: 4; color: "transparent"; border.width: 1; border.color: "#c4d9ca"
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var c = getContext("2d"); c.reset(); c.strokeStyle = "#5d9180"; c.lineWidth = 0.6
                    for (var i = -height; i < width + height; i += 9) {
                        c.beginPath(); c.moveTo(i, 0); c.lineTo(i + height, height); c.stroke()
                        c.beginPath(); c.moveTo(i, height); c.lineTo(i + height, 0); c.stroke()
                    }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }
            Rectangle {
                anchors.centerIn: parent; width: parent.width * 0.42; height: width; rotation: 45
                color: root.backColor; border.color: "#d5b775"; border.width: 2; radius: 3
                Text { anchors.centerIn: parent; rotation: -45; text: "♠"; color: "#e1ce9e"; font.pixelSize: parent.width * 0.75; font.family: "DejaVu Serif" }
            }
        }
        Column {
            visible: root.faceUp; x: 7; y: 5; spacing: -2
            Text { text: root.rankText; color: root.ink; font.family: "DejaVu Serif"; font.pixelSize: root.width * 0.21; font.bold: true }
            Text { text: root.suitText; color: root.ink; font.family: "DejaVu Serif"; font.pixelSize: root.width * 0.19 }
        }
        Column {
            visible: root.faceUp; x: root.width - width - 7; y: root.height - height - 5; rotation: 180; spacing: -2
            Text { text: root.rankText; color: root.ink; font.family: "DejaVu Serif"; font.pixelSize: root.width * 0.21; font.bold: true }
            Text { text: root.suitText; color: root.ink; font.family: "DejaVu Serif"; font.pixelSize: root.width * 0.19 }
        }
        Item {
            id: pips; visible: root.faceUp; anchors.centerIn: parent; width: root.width * 0.54; height: root.height * 0.64
            Repeater {
                model: Game.rank(root.card) <= 10 ? root.pipPositions : []
                Text {
                    required property var modelData
                    readonly property int count: Game.rank(root.card)
                    readonly property bool single: count === 1
                    x: modelData[0] * (pips.width - width)
                    y: modelData[1] * (pips.height - height)
                    rotation: modelData[1] > 0.5 ? 180 : 0
                    text: root.suitText; color: root.ink; font.family: "DejaVu Serif"
                    font.pixelSize: root.width * (single ? 0.51 : count > 7 ? 0.21 : 0.26)
                }
            }
            Rectangle {
                visible: Game.rank(root.card) > 10; anchors.centerIn: parent
                width: parent.width * 1.08; height: parent.height * 0.84; radius: width / 2
                color: "transparent"; border.width: 1; border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.32)
                Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -5; text: root.rankText; color: root.ink; font.family: "DejaVu Serif"; font.italic: true; font.pixelSize: root.width * 0.40 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; text: root.suitText; color: root.ink; font.pixelSize: root.width * 0.20 }
            }
        }
    }
    MouseArea {
        id: mouse; anchors.fill: parent; enabled: root.interactive && root.faceUp
        hoverEnabled: true; cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onPressed: function(m) { var p = root.mapToItem(root.stage, m.x, m.y); root.pointerDown(p.x, p.y, m.x, m.y) }
        onPositionChanged: function(m) { if (pressed) { var p = root.mapToItem(root.stage, m.x, m.y); root.pointerMoved(p.x, p.y) } }
        onReleased: function(m) { var p = root.mapToItem(root.stage, m.x, m.y); root.pointerUp(p.x, p.y) }
        onCanceled: root.canceled()
        onDoubleClicked: root.doubleClicked()
    }
}
