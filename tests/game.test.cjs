const {test} = require('node:test');
const assert = require('node:assert/strict');
const G = require('../Game.js');
const src = (kind, pile, index) => ({kind, pile, index});
const dst = (kind, pile) => ({kind, pile});
function fixture(overrides = {}) {
  const g = Object.assign(G.deal(1, 1, ''), {tableau:[[],[],[],[],[],[],[]], down:[0,0,0,0,0,0,0],
    foundations:[[],[],[],[]], waste:[], stock:[]}, overrides);
  const used = new Set(g.tableau.flat().concat(g.foundations.flat(),g.waste));
  g.stock = Array.from({length:52},(_,i)=>i).filter(c=>!used.has(c));
  assert(G.valid(g));
  return g;
}
test('deterministic shuffle deals all 52 unique cards, with one face up per column', () => {
  for (let seed = 1; seed < 100; seed++) {
    const g = G.deal(seed, seed % 2 ? 1 : 3, '');
    assert(G.valid(g)); assert.equal(g.stock.length,24);
    g.tableau.forEach((p,i)=>{ assert.equal(p.length,i+1); assert.equal(g.down[i],i); });
    assert.deepEqual(g,G.deal(seed,g.draw,''));
  }
  assert.notDeepEqual(G.deal(7,1,''),G.deal(8,1,''));
  assert.equal(G.dailySeed('2026-10-06'),G.dailySeed('2026-10-06'));
  assert.notEqual(G.dailySeed('2026-10-06'),G.dailySeed('2026-10-07'));
});
test('tableau moves a complete legal run and reveals the hidden card exactly once', () => {
  const g=fixture({tableau:[[20,24,10],[38],[],[],[],[],[]],down:[1,0,0,0,0,0,0]});
  const snapshot=JSON.stringify(g);
  const moved=G.move(g,src('tableau',0,1),dst('tableau',1));
  assert.deepEqual(moved.tableau[1],[38,24,10]); assert.deepEqual(moved.tableau[0],[20]);
  assert.equal(moved.down[0],0); assert.equal(moved.score,5); assert.equal(moved.moves,1);
  assert.equal(JSON.stringify(g),snapshot); assert(G.valid(moved));
  assert.equal(G.move(g,src('tableau',0,0),dst('tableau',1)),null);
  assert.equal(G.move(g,src('tableau',0,1),dst('tableau',0)),null);
  assert.equal(G.stack(g,{kind:'tableau',pile:0}).length,0);
  assert.equal(G.stack(g,src('tableau',0,1.5)).length,0);
  assert.equal(G.move(g,src('tableau',0,1),{kind:'tableau',pile:'0'}),null);
});
test('only kings fill empty columns, and colors must alternate', () => {
  const g=fixture({tableau:[[12],[11],[25],[],[],[],[]],waste:[23]});
  assert(G.canMove(g,src('tableau',0,0),dst('tableau',3)));
  assert(!G.canMove(g,src('tableau',1,0),dst('tableau',3)));
  assert(!G.canMove(g,src('tableau',1,0),dst('tableau',0)));
  assert(G.canMove(g,src('tableau',1,0),dst('tableau',2)));
  assert(!G.canMove(g,src('waste',0,0),dst('tableau',0)));
});
test('foundations require the correct suit, ace first, and one card at a time', () => {
  const g=fixture({tableau:[[0],[1],[14,26],[],[],[],[]]});
  assert(G.canMove(g,src('tableau',0,0),dst('foundation',0)));
  assert(!G.canMove(g,src('tableau',0,0),dst('foundation',1)));
  assert(!G.canMove(g,src('tableau',1,0),dst('foundation',0)));
  assert(!G.canMove(g,src('tableau',2,0),dst('foundation',1)));
  const one=G.move(g,src('tableau',0,0),dst('foundation',0));
  const two=G.move(one,src('tableau',1,0),dst('foundation',0));
  assert.deepEqual(two.foundations[0],[0,1]); assert.equal(two.score,20); assert(G.valid(two));
});
test('draw-three exposes only the last card and recycles in the original order', () => {
  let g=G.deal(73,3,'');
  const original=g.stock.slice();
  let first=G.drawCards(g);
  assert.deepEqual(first.waste,original.slice(-3).reverse());
  assert.equal(G.stack(first,src('waste',0,1)).length,0);
  for(let i=0;i<8;i++) g=G.drawCards(g);
  assert.equal(g.stock.length,0); assert.equal(g.waste.length,24);
  g.score=100;
  const recycled=G.drawCards(g);
  assert.deepEqual(recycled.stock,original); assert.deepEqual(recycled.waste,[]);
  assert.equal(recycled.score,80); assert.equal(recycled.passes,1);
  assert.deepEqual(G.drawCards(recycled).waste,first.waste);
});
test('foundation cards may return to the table with the correct score deduction', () => {
  const g=fixture({foundations:[[0,1],[],[],[]],tableau:[[15],[],[],[],[],[],[]],score:40});
  const moved=G.move(g,src('foundation',0,1),dst('tableau',0));
  assert.deepEqual(moved.tableau[0],[15,1]); assert.equal(moved.score,25); assert(G.valid(moved));
});
test('auto-finish detects completion, conserves cards and preserves its input', () => {
  const g=fixture({foundations:Array.from({length:4},(_,s)=>Array.from({length:12},(_,r)=>s*13+r)),
    tableau:[[12],[25],[38],[51],[],[],[]]});
  const snapshot=JSON.stringify(g);
  assert(G.canFinish(g));
  const won=G.finish(g);
  assert(won.won); assert.equal(won.score,40); assert.equal(won.moves,4); assert(G.valid(won));
  assert.equal(JSON.stringify(g),snapshot); assert.equal(G.drawCards(won),null);
  assert.equal(G.finish(G.deal(1,1,'')),null);
});
test('hints suggest legal moves and prioritize uncovering a hidden card', () => {
  const g=fixture({tableau:[[20,24,10],[38],[],[],[],[],[]],down:[1,0,0,0,0,0,0]});
  const h=G.hint(g); assert(G.canMove(g,h.src,h.dst)); assert.equal(h.src.pile,0);
  assert(h.text.includes('uncover'));
});
test('saved-state validation rejects duplicates, impossible foundations and hidden tops', () => {
  const g=G.deal(1,1,'');
  const duplicate=G.clone(g); duplicate.stock[0]=duplicate.stock[1]; assert(!G.valid(duplicate));
  const bad=G.clone(g); bad.down[0]=1; assert(!G.valid(bad));
  const corrupt=G.clone(g); corrupt.foundations[0]=[corrupt.stock.pop()]; assert(!G.valid(corrupt));
  const lie=G.clone(g); lie.won=true; assert(!G.valid(lie));
  assert(G.valid(JSON.parse(JSON.stringify(g))));
});
test('random legal play preserves invariants for both draw modes and supports snapshot undo', () => {
  let rng=78231;
  function random(n) { rng=(Math.imul(rng,1664525)+1013904223)>>>0; return rng%n; }
  for(let seed=1;seed<=30;seed++) {
    let g=G.deal(seed,seed%2?1:3,''), history=[];
    for(let turn=0;turn<160 && !g.won;turn++) {
      const moves=[], sources=[];
      g.tableau.forEach((p,t)=>p.forEach((_,i)=>sources.push(src('tableau',t,i))));
      if(g.waste.length) sources.push(src('waste',0,g.waste.length-1));
      g.foundations.forEach((p,f)=>{ if(p.length) sources.push(src('foundation',f,p.length-1)); });
      sources.forEach(s=>{ for(let t=0;t<7;t++) if(G.canMove(g,s,dst('tableau',t))) moves.push([s,dst('tableau',t)]);
        for(let f=0;f<4;f++) if(G.canMove(g,s,dst('foundation',f))) moves.push([s,dst('foundation',f)]); });
      history.push(G.clone(g));
      const choice=random(moves.length+1);
      const next=choice===moves.length ? G.drawCards(g) : G.move(g,...moves[choice]);
      if(next) g=next;
      assert(G.valid(g),`seed ${seed}, turn ${turn}`);
    }
    while(history.length) { g=history.pop(); assert(G.valid(g)); }
    assert.deepEqual(g,G.deal(seed,seed%2?1:3,''));
  }
});
