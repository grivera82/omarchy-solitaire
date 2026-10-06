// The rules have no UI, filesystem or network dependencies. QML and Node share
// this exact engine; cards are unique integers (suit * 13 + rank - 1).
var suits = ["♣", "♦", "♠", "♥"];
function rank(c) { return c % 13 + 1; }
function suit(c) { return Math.floor(c / 13); }
function red(c) { return suit(c) % 2 === 1; }
function label(c) { return ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][rank(c)] + suits[suit(c)]; }
function clone(x) { return JSON.parse(JSON.stringify(x)); }
function dailySeed(date) {
    var h = 2166136261;
    for (var i = 0; i < date.length; i++) { h ^= date.charCodeAt(i); h = Math.imul(h, 16777619); }
    return h >>> 0;
}
function deal(seed, draw, daily) {
    seed = (seed >>> 0) || 1;
    var n = seed, deck = [], t = [[], [], [], [], [], [], []];
    for (var c = 0; c < 52; c++) deck.push(c);
    function random() { n ^= n << 13; n ^= n >>> 17; n ^= n << 5; return (n >>> 0) / 4294967296; }
    for (var i = 51; i > 0; i--) {
        var j = Math.floor(random() * (i + 1)), tmp = deck[i]; deck[i] = deck[j]; deck[j] = tmp;
    }
    for (var row = 0; row < 7; row++) for (var col = row; col < 7; col++) t[col].push(deck.pop());
    return {seed: seed, draw: draw === 3 ? 3 : 1, daily: daily || "", tableau: t,
        down: [0, 1, 2, 3, 4, 5, 6], stock: deck, waste: [], foundations: [[], [], [], []],
        score: 0, moves: 0, passes: 0, won: false};
}
function sourcePile(g, src) {
    if (!src) return null;
    if (src.kind === "tableau" && src.pile >= 0 && src.pile < 7) return g.tableau[src.pile];
    if (src.kind === "foundation" && src.pile >= 0 && src.pile < 4) return g.foundations[src.pile];
    if (src.kind === "waste") return g.waste;
    return null;
}
function stack(g, src) {
    var p = sourcePile(g, src);
    if (!p || !Number.isInteger(src.index) || src.index < 0 || src.index >= p.length) return [];
    if (src.kind === "tableau") {
        if (src.index < g.down[src.pile]) return [];
        for (var i = src.index + 1; i < p.length; i++)
            if (rank(p[i - 1]) !== rank(p[i]) + 1 || red(p[i - 1]) === red(p[i])) return [];
    } else if (src.index !== p.length - 1) return [];
    return p.slice(src.index);
}
function canMove(g, src, dst) {
    if (g.won || !dst || !Number.isInteger(dst.pile)) return false;
    var cards = stack(g, src);
    if (!cards.length || (src.kind === dst.kind && src.pile === dst.pile)) return false;
    var c = cards[0];
    if (dst.kind === "foundation") {
        return cards.length === 1 && dst.pile === suit(c) && rank(c) === g.foundations[dst.pile].length + 1;
    }
    if (dst.kind !== "tableau" || dst.pile < 0 || dst.pile > 6) return false;
    var p = g.tableau[dst.pile];
    return p.length ? rank(p[p.length - 1]) === rank(c) + 1 && red(p[p.length - 1]) !== red(c) : rank(c) === 13;
}
function move(g, src, dst) {
    if (!canMove(g, src, dst)) return null;
    var next = clone(g), from = sourcePile(next, src), cards = from.splice(src.index);
    if (dst.kind === "foundation") { next.foundations[dst.pile].push(cards[0]); next.score += 10; }
    else { next.tableau[dst.pile] = next.tableau[dst.pile].concat(cards); if (src.kind === "waste") next.score += 5; }
    if (src.kind === "foundation") next.score = Math.max(0, next.score - 15);
    if (src.kind === "tableau" && from.length && next.down[src.pile] === from.length) {
        next.down[src.pile]--; next.score += 5;
    }
    if (src.kind === "tableau" && !from.length) next.down[src.pile] = 0;
    next.moves++;
    next.won = next.foundations.every(function(p) { return p.length === 13; });
    return next;
}
function drawCards(g) {
    if (g.won || (!g.stock.length && !g.waste.length)) return null;
    var next = clone(g);
    if (!next.stock.length) {
        next.stock = next.waste.reverse(); next.waste = []; next.passes++;
        next.score = Math.max(0, next.score - 20);
    } else for (var i = 0; i < next.draw && next.stock.length; i++) next.waste.push(next.stock.pop());
    next.moves++;
    return next;
}
function safeHome(g, c) {
    if (rank(c) <= 2) return true;
    for (var s = 0; s < 4; s++) if ((s % 2) !== (suit(c) % 2) && g.foundations[s].length < rank(c) - 1) return false;
    return true;
}
function sources(g) {
    var out = [];
    if (g.waste.length) out.push({kind: "waste", pile: 0, index: g.waste.length - 1});
    for (var p = 0; p < 7; p++) for (var i = g.down[p]; i < g.tableau[p].length; i++)
        out.push({kind: "tableau", pile: p, index: i});
    return out;
}
function hint(g) {
    if (g.won) return {text: "All four suits are home. Beautifully played."};
    var candidates = [], ss = sources(g);
    ss.forEach(function(src) {
        var cards = stack(g, src), c = cards[0];
        if (!cards.length) return;
        var home = {kind: "foundation", pile: suit(c)};
        var reveal = src.kind === "tableau" && src.index === g.down[src.pile] && src.index > 0;
        if (canMove(g, src, home)) candidates.push({src: src, dst: home,
            weight: safeHome(g, c) ? 100 + (reveal ? 20 : 0) : 20,
            text: "Send " + label(c) + " to its foundation."});
        for (var p = 0; p < 7; p++) {
            var dst = {kind: "tableau", pile: p};
            if (!canMove(g, src, dst)) continue;
            // Moving an entire face-up king column to an empty column changes nothing.
            if (!g.tableau[p].length && src.kind === "tableau" && src.index === 0) continue;
            var top = g.tableau[p][g.tableau[p].length - 1];
            candidates.push({src: src, dst: dst, weight: reveal ? 90 : src.kind === "waste" ? 75 : 35,
                text: "Move " + label(c) + (cards.length > 1 ? " and its stack" : "") +
                    (top === undefined ? " into the empty column" : " onto " + label(top)) +
                    (reveal ? " to uncover a card." : ".")});
        }
    });
    candidates.sort(function(a,b) { return b.weight - a.weight; });
    if (candidates.length) return candidates[0];
    if (g.stock.length) return {draw: true, text: "Draw " + (g.draw === 3 ? "three cards" : "a card") + " from the stock."};
    if (g.waste.length) return {draw: true, text: "Turn the waste over to go through the stock again."};
    return {text: "No forward moves remain. Try undoing a move or returning a foundation card to the table."};
}
function canFinish(g) { return !g.won && !g.stock.length && !g.waste.length && g.down.every(function(n) { return n === 0; }); }
function finish(g) {
    if (!canFinish(g)) return null;
    var next = clone(g), changed = false;
    for (var round = 0; round < 52; round++) {
        var progressed = false;
        for (var p = 0; p < 7; p++) {
            var pile = next.tableau[p];
            if (!pile.length) continue;
            var src = {kind: "tableau", pile: p, index: pile.length - 1};
            var dst = {kind: "foundation", pile: suit(pile[pile.length - 1])};
            var moved = move(next, src, dst);
            if (moved) { next = moved; changed = true; progressed = true; }
        }
        if (!progressed || next.won) break;
    }
    return changed ? next : null;
}
function valid(g) {
    if (!g || !Number.isInteger(g.seed) || g.seed < 1 || g.seed > 4294967295 ||
        (g.draw !== 1 && g.draw !== 3) || typeof g.daily !== "string" ||
        !Array.isArray(g.tableau) || g.tableau.length !== 7 || !Array.isArray(g.down) || g.down.length !== 7 ||
        !Array.isArray(g.foundations) || g.foundations.length !== 4 || !Array.isArray(g.stock) || !Array.isArray(g.waste) ||
        !Number.isInteger(g.moves) || g.moves < 0 || !Number.isInteger(g.score) || g.score < 0 ||
        !Number.isInteger(g.passes) || g.passes < 0 || typeof g.won !== "boolean") return false;
    var seen = {}, count = 0;
    var piles = g.tableau.concat(g.foundations).concat([g.stock, g.waste]);
    for (var p = 0; p < piles.length; p++) {
        if (!Array.isArray(piles[p])) return false;
        for (var i = 0; i < piles[p].length; i++) {
            var c = piles[p][i];
            if (!Number.isInteger(c) || c < 0 || c > 51 || seen[c]) return false;
            seen[c] = true; count++;
        }
    }
    if (count !== 52) return false;
    for (var t = 0; t < 7; t++) {
        var down = g.down[t], table = g.tableau[t];
        if (!Number.isInteger(down) || down < 0 || (table.length ? down >= table.length : down !== 0)) return false;
        for (var k = down + 1; k < table.length; k++)
            if (rank(table[k - 1]) !== rank(table[k]) + 1 || red(table[k - 1]) === red(table[k])) return false;
    }
    for (var s = 0; s < 4; s++) for (var f = 0; f < g.foundations[s].length; f++)
        if (suit(g.foundations[s][f]) !== s || rank(g.foundations[s][f]) !== f + 1) return false;
    return g.won === g.foundations.every(function(pile) { return pile.length === 13; });
}
if (typeof module !== "undefined") module.exports = {rank:rank, suit:suit, red:red, label:label,
    deal:deal, dailySeed:dailySeed, clone:clone, stack:stack, canMove:canMove, move:move,
    drawCards:drawCards, hint:hint, canFinish:canFinish, finish:finish, valid:valid};
