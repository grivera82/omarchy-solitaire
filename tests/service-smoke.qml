import QtQuick
import Quickshell
import ".." as Solitaire
import "../Game.js" as Game

// Run with an isolated XDG_STATE_HOME. A second process exercises restoration
// from the first process's actual atomic FileView writes, not a mock store.
ShellRoot {
    Solitaire.Service { id: service }
    function check(condition, detail) { if (!condition) throw new Error(detail) }
    Timer {
        interval: 50; running: service.ready
        onTriggered: {
            try {
                if (Quickshell.env("SOLITAIRE_SMOKE_PHASE") === "restore") {
                    check(service.game.seed === 732, "saved seed was not restored")
                    check(service.game.stock.length === 6 && service.game.waste.length === 18, "saved cards were not restored")
                    check(service.past.length === 6, "undo history was not restored")
                    check(service.elapsed === 45 && service.midnight, "time/theme were not restored")
                    check(service.stats.games === 1 && service.counted, "played count was not restored")
                    check(service.undo() && service.game.stock.length === 9, "restored undo failed")
                    check(service.redo() && service.game.stock.length === 6, "restored redo failed")
                    var g = Game.deal(1,1,"")
                    g.stock = []; g.waste = []; g.down = [0,0,0,0,0,0,0]
                    g.tableau = [[12],[25],[38],[51],[],[],[]]
                    g.foundations = [[],[],[],[]]
                    for (var s=0;s<4;s++) for (var r=0;r<12;r++) g.foundations[s].push(s*13+r)
                    service.game = g; service.past = []; service.future = []; service.counted = false; service.credited = false
                    check(service.finish() && service.game.won, "service auto-finish failed")
                    check(service.stats.wins === 1, "win was not counted")
                    check(service.undo() && !service.game.won, "finish was not a single undo transaction")
                    check(service.redo() && service.game.won && service.stats.wins === 1, "redo double-counted the win")
                    console.log("SOLITAIRE_RESTORE_PASS")
                } else {
                    service.setPanelOpen("screen-one", true)
                    service.setPanelOpen("screen-two", true)
                    service.setPanelOpen("screen-one", false)
                    check(service.playing, "closing one screen paused the other")
                    service.setPanelOpen("screen-two", false)
                    check(!service.playing, "clock did not pause when all panels closed")
                    service.newGame(3, false, false)
                    service.game = Game.deal(732,3,"")
                    for (var i=0;i<6;i++) check(service.draw(), "stock draw failed")
                    check(service.stats.games === 1, "each move counted as a new game")
                    var snapshot = JSON.stringify(service.game)
                    check(service.undo() && service.canRedo, "service undo failed")
                    check(service.redo() && JSON.stringify(service.game) === snapshot, "service redo failed")
                    service.elapsed = 45; service.midnight = true; service.save()
                    console.log("SOLITAIRE_SAVE_PASS")
                }
                done.start()
            } catch(e) { console.error("SOLITAIRE_SMOKE_FAIL: " + e); done.start() }
        }
    }
    Timer { id: done; interval: 500; onTriggered: Qt.quit() }
}
