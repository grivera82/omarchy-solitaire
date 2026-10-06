import QtQuick
import Quickshell
import Quickshell.Io
import "Game.js" as Game

Item {
    id: root
    property var shell: null
    property var manifest: null
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/grivera-solitaire"
    property var game: null
    property var past: []
    property var future: []
    property var stats: ({games: 0, wins: 0, best: {}})
    property int elapsed: 0
    property var openPanels: ({})
    readonly property bool playing: Object.keys(openPanels).length > 0
    property bool ready: false
    property bool counted: false
    property bool credited: false
    property bool midnight: false
    property string notice: ""
    readonly property bool canUndo: past.length > 0
    readonly property bool canRedo: future.length > 0
    readonly property bool canFinish: game ? Game.canFinish(game) : false

    function today() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }
    function setPanelOpen(token, opened) {
        var panels = Object.assign({}, openPanels)
        if (opened) panels[token] = true
        else delete panels[token]
        openPanels = panels
    }
    function newGame(draw, daily, restart) {
        var seed = restart && game ? game.seed : daily ? Game.dailySeed(today()) : Math.floor(Math.random() * 4294967294) + 1
        var day = restart && game ? game.daily : daily ? today() : ""
        game = Game.deal(seed, draw, day)
        past = []; future = []; elapsed = 0; counted = false; credited = false
        saveSoon.restart()
    }
    function commit(next) {
        if (!next) return false
        past = past.concat([Game.clone(game)]).slice(-500)
        future = []; game = next
        if (!counted) { stats = Object.assign({}, stats, {games: stats.games + 1}); counted = true }
        recordWin(); saveSoon.restart(); return true
    }
    function recordWin() {
        if (!game.won || credited) return
        credited = true
        var best = Game.clone(stats.best), key = game.daily ? "daily" : "draw" + game.draw
        var previous = best[key] || {time: 0, score: 0}
        best[key] = {time: previous.time ? Math.min(previous.time, elapsed) : elapsed, score: Math.max(previous.score, game.score)}
        stats = Object.assign({}, stats, {wins: stats.wins + 1, best: best})
    }
    function move(src, dst) { return game ? commit(Game.move(game, src, dst)) : false }
    function draw() { return game ? commit(Game.drawCards(game)) : false }
    function finish() { return game ? commit(Game.finish(game)) : false }
    function undo() {
        if (!past.length) return false
        future = future.concat([Game.clone(game)])
        game = past[past.length - 1]; past = past.slice(0, -1); saveSoon.restart(); return true
    }
    function redo() {
        if (!future.length) return false
        past = past.concat([Game.clone(game)])
        game = future[future.length - 1]; future = future.slice(0, -1)
        recordWin(); saveSoon.restart(); return true
    }
    function save() {
        if (!ready || !game || !store.path) return
        store.setText(JSON.stringify({schema:1, game:game, past:past, future:future, elapsed:elapsed,
            stats:stats, counted:counted, credited:credited, midnight:midnight}) + "\n")
    }
    function load(text) {
        if (ready) return
        var data = null
        try { data = JSON.parse(text) } catch (e) {}
        if (data && data.schema === 1 && Game.valid(data.game)) {
            game = data.game
            past = Array.isArray(data.past) && data.past.every(Game.valid) ? data.past.slice(-500) : []
            future = Array.isArray(data.future) && data.future.every(Game.valid) ? data.future.slice(-500) : []
            elapsed = Math.min(2147483646, Math.max(0, Math.floor(Number(data.elapsed) || 0)))
            counted = data.counted === true; credited = data.credited === true; midnight = data.midnight === true
            if (data.stats && Number.isInteger(data.stats.games) && data.stats.games >= 0 &&
                Number.isInteger(data.stats.wins) && data.stats.wins >= 0 && data.stats.wins <= data.stats.games &&
                data.stats.best && typeof data.stats.best === "object") stats = data.stats
        } else {
            if (text) notice = "Your saved deal could not be read. A fresh table is ready."
            newGame(1, false, false)
        }
        ready = true
    }
    onPlayingChanged: if (!playing) save()
    onMidnightChanged: if (ready) saveSoon.restart()
    Timer { id: saveSoon; interval: 180; onTriggered: root.save() }
    Timer {
        interval: 1000; repeat: true
        running: root.ready && root.playing && root.counted && root.game && !root.game.won
        onTriggered: { root.elapsed++; if (root.elapsed % 10 === 0) root.save() }
    }
    Process {
        command: ["mkdir", "-p", root.stateDir]; running: true
        onExited: function(exitCode) {
            if (exitCode === 0) store.path = root.stateDir + "/game.json"
            else { root.notice = "The game is playable, but the save folder could not be created."; root.load("") }
        }
    }
    FileView {
        id: store; atomicWrites: true; printErrors: false
        onLoaded: root.load(text())
        onLoadFailed: function(error) {
            if (error !== FileViewError.FileNotFound) root.notice = "The saved game could not be opened."
            root.load("")
        }
    }
    Component.onDestruction: save()
}
