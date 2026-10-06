import QtQuick

Rectangle {
    id: root
    property string label: ""
    property bool emphasized: false
    property bool chosen: false
    property color ink: "#eee8d9"
    property color accent: "#d5b775"
    signal clicked()
    implicitWidth: textItem.implicitWidth + 24
    implicitHeight: 34
    radius: 8
    color: emphasized ? accent : chosen ? "#304a43" : area.containsMouse && enabled ? "#20ffffff" : "#0bffffff"
    border.width: 1
    border.color: chosen ? accent : "#16ffffff"
    opacity: enabled ? 1 : 0.35
    Behavior on color { ColorAnimation { duration: 110 } }
    Text {
        id: textItem; anchors.centerIn: parent; text: root.label
        color: root.emphasized ? "#182f29" : root.ink
        font.family: "DejaVu Sans"; font.pixelSize: 12; font.weight: Font.Medium
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; enabled: root.enabled; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
