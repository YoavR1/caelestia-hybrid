import QtQuick

AnimatedImage {
    id: root

    property string path

    asynchronous: true
    fillMode: AnimatedImage.PreserveAspectCrop
    source: path || ""
    playing: true

    onSourceChanged: playing = true
}
