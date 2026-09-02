pragma Singleton

import QtQuick

QtObject {
    readonly property bool playing: video.playing

    property var video: null

    function play(): void {
        video.play();
    }

    function stop(): void {
        video.stop();
    }
}
