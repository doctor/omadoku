import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const source = fs.readFileSync(new URL('../SudokuEngine.js', import.meta.url), 'utf8')
const context = { console, Math, Number, Object, Array, JSON, isFinite }
vm.createContext(context)
vm.runInContext(source, context)

const { DIFFICULTIES, generate, clueCount, countSolutions, validComplete,
  createState, normalizeState, recordStart, recordAbandon, recordWin } = context

for (const [difficulty, clues] of Object.entries(DIFFICULTIES)) {
  for (let seed = 1; seed <= 25; seed++) {
    const game = generate(difficulty, seed)
    assert.equal(clueCount(game.puzzle), clues, `${difficulty} seed ${seed}: clues`)
    assert.equal(countSolutions(game.puzzle, 2), 1, `${difficulty} seed ${seed}: unique`)
    assert.equal(validComplete(game.solution), true, `${difficulty} seed ${seed}: solution`)
    for (let i = 0; i < 81; i++) if (game.puzzle[i]) assert.equal(game.puzzle[i], game.solution[i])
    assert.deepEqual(Array.from(generate(difficulty, seed).puzzle), Array.from(game.puzzle), 'deterministic')
  }
}

const state = createState()
recordStart(state, 'Easy')
recordWin(state, 'Easy', 120, 2)
assert.equal(state.stats.global.won, 1)
assert.equal(state.stats.global.currentStreak, 1)
assert.equal(state.stats.global.bestSeconds, 120)
recordStart(state, 'Easy')
recordAbandon(state, 'Easy')
assert.equal(state.stats.global.currentStreak, 0)
assert.equal(normalizeState({ nope: true }).version, 1, 'corrupt state recovers')
console.log('Omadoku engine tests passed: 100 generated puzzles')
