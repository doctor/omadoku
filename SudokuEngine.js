var DIFFICULTIES = {
  Easy: 40,
  Medium: 34,
  Hard: 29,
  Expert: 25
}

function rng(seed) {
  var state = (Number(seed) >>> 0) || 0x6d2b79f5
  return function() {
    state += 0x6d2b79f5
    var t = state
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function shuffle(values, random) {
  var out = values.slice()
  for (var i = out.length - 1; i > 0; i--) {
    var j = Math.floor(random() * (i + 1))
    var tmp = out[i]; out[i] = out[j]; out[j] = tmp
  }
  return out
}

function pattern(row, col) { return (row * 3 + Math.floor(row / 3) + col) % 9 }

function solvedGrid(seed) {
  var random = rng(seed)
  var bands = shuffle([0, 1, 2], random)
  var stacks = shuffle([0, 1, 2], random)
  var rows = [], cols = []
  for (var b = 0; b < 3; b++) {
    var localRows = shuffle([0, 1, 2], random)
    for (var r = 0; r < 3; r++) rows.push(bands[b] * 3 + localRows[r])
  }
  for (var s = 0; s < 3; s++) {
    var localCols = shuffle([0, 1, 2], random)
    for (var c = 0; c < 3; c++) cols.push(stacks[s] * 3 + localCols[c])
  }
  var digits = shuffle([1,2,3,4,5,6,7,8,9], random)
  var grid = []
  for (var y = 0; y < 9; y++)
    for (var x = 0; x < 9; x++) grid.push(digits[pattern(rows[y], cols[x])])
  return grid
}

function candidates(grid, index) {
  if (grid[index]) return []
  var row = Math.floor(index / 9), col = index % 9, used = {}
  for (var i = 0; i < 9; i++) {
    used[grid[row * 9 + i]] = true
    used[grid[i * 9 + col]] = true
  }
  var br = Math.floor(row / 3) * 3, bc = Math.floor(col / 3) * 3
  for (var r = br; r < br + 3; r++)
    for (var c = bc; c < bc + 3; c++) used[grid[r * 9 + c]] = true
  var out = []
  for (var n = 1; n <= 9; n++) if (!used[n]) out.push(n)
  return out
}

function countSolutions(grid, limit) {
  var work = grid.slice(), cap = limit || 2, count = 0
  function solve() {
    if (count >= cap) return
    var best = -1, options = null
    for (var i = 0; i < 81; i++) {
      if (work[i] !== 0) continue
      var found = candidates(work, i)
      if (found.length === 0) return
      if (options === null || found.length < options.length) {
        best = i; options = found
        if (found.length === 1) break
      }
    }
    if (best < 0) { count++; return }
    for (var j = 0; j < options.length && count < cap; j++) {
      work[best] = options[j]; solve(); work[best] = 0
    }
  }
  solve()
  return count
}

function clueCount(grid) {
  var count = 0
  for (var i = 0; i < 81; i++) if (grid[i]) count++
  return count
}

function expertTemplate(seed) {
  var basePuzzle = [7,0,0,0,0,0,0,0,0,0,0,0,8,0,0,7,0,2,0,5,0,4,0,0,9,6,0,0,0,0,1,0,0,2,0,6,5,0,0,0,6,0,0,0,8,2,0,7,0,0,3,0,0,0,0,9,2,0,0,8,0,5,0,8,0,3,0,0,4,0,0,0,0,0,0,0,0,0,0,0,1]
  var baseSolution = [7,2,4,6,3,9,1,8,5,9,3,6,8,5,1,7,4,2,1,5,8,4,2,7,9,6,3,3,8,9,1,4,5,2,7,6,5,4,1,7,6,2,3,9,8,2,6,7,9,8,3,5,1,4,6,9,2,3,1,8,4,5,7,8,1,3,5,7,4,6,2,9,4,7,5,2,9,6,8,3,1]
  var random = rng(seed), digits = shuffle([1,2,3,4,5,6,7,8,9], random)
  var turns = Math.floor(random() * 4), mirror = random() < 0.5
  function transform(grid) {
    var out = new Array(81)
    for (var row = 0; row < 9; row++) for (var col = 0; col < 9; col++) {
      var r = row, c = col
      if (mirror) c = 8 - c
      for (var t = 0; t < turns; t++) { var oldR = r; r = c; c = 8 - oldR }
      var value = grid[row * 9 + col]
      out[r * 9 + c] = value ? digits[value - 1] : 0
    }
    return out
  }
  return { puzzle: transform(basePuzzle), solution: transform(baseSolution), seed: Number(seed) >>> 0, difficulty: "Expert" }
}

function generate(difficulty, seed) {
  var target = DIFFICULTIES[difficulty] || DIFFICULTIES.Medium
  if (difficulty === "Expert") return expertTemplate(seed)
  for (var attempt = 0; attempt < 40; attempt++) {
    var actualSeed = ((Number(seed) >>> 0) + attempt * 2654435761) >>> 0
    var solution = solvedGrid(actualSeed), puzzle = solution.slice(), random = rng(actualSeed ^ 0xa5a5a5a5)
    var pairs = []
    for (var i = 0; i <= 40; i++) pairs.push(i)
    pairs = shuffle(pairs, random)
    for (var p = 0; p < pairs.length && clueCount(puzzle) > target; p++) {
      var a = pairs[p], b = 80 - a
      var removal = a === b ? 1 : 2
      if (clueCount(puzzle) - removal < target) continue
      var oldA = puzzle[a], oldB = puzzle[b]
      puzzle[a] = 0; puzzle[b] = 0
      if (countSolutions(puzzle, 2) !== 1) { puzzle[a] = oldA; puzzle[b] = oldB }
    }
    if (clueCount(puzzle) === target) return { puzzle: puzzle, solution: solution, seed: actualSeed, difficulty: difficulty }
  }
  throw new Error("Could not generate a unique " + difficulty + " puzzle")
}

function validComplete(grid) {
  if (!grid || grid.length !== 81) return false
  for (var i = 0; i < 81; i++) if (grid[i] < 1 || grid[i] > 9) return false
  return countSolutions(grid, 2) === 1
}

function freshStats() {
  return { started: 0, won: 0, currentStreak: 0, bestStreak: 0, totalWinSeconds: 0, bestSeconds: 0, mistakes: 0 }
}

function normalizeStats(value) {
  var source = value || {}, out = freshStats()
  var keys = Object.keys(out)
  for (var i = 0; i < keys.length; i++) {
    var n = Number(source[keys[i]])
    if (isFinite(n) && n >= 0) out[keys[i]] = Math.floor(n)
  }
  return out
}

function createState() {
  var byDifficulty = {}
  var names = Object.keys(DIFFICULTIES)
  for (var i = 0; i < names.length; i++) byDifficulty[names[i]] = freshStats()
  return { version: 1, game: null, stats: { global: freshStats(), byDifficulty: byDifficulty } }
}

function normalizeState(raw) {
  var out = createState()
  if (!raw || raw.version !== 1) return out
  out.stats.global = normalizeStats(raw.stats && raw.stats.global)
  var names = Object.keys(DIFFICULTIES)
  for (var i = 0; i < names.length; i++)
    out.stats.byDifficulty[names[i]] = normalizeStats(raw.stats && raw.stats.byDifficulty && raw.stats.byDifficulty[names[i]])
  var g = raw.game
  if (g && DIFFICULTIES[g.difficulty] && Array.isArray(g.puzzle) && g.puzzle.length === 81 &&
      Array.isArray(g.solution) && g.solution.length === 81 && Array.isArray(g.entries) && g.entries.length === 81) {
    out.game = g
    if (!Array.isArray(out.game.notes) || out.game.notes.length !== 81) out.game.notes = new Array(81).fill(0)
    if (!Array.isArray(out.game.undo)) out.game.undo = []
    if (!Array.isArray(out.game.redo)) out.game.redo = []
  }
  return out
}

function recordStart(state, difficulty) {
  state.stats.global.started++
  state.stats.byDifficulty[difficulty].started++
}

function recordAbandon(state, difficulty) {
  state.stats.global.currentStreak = 0
  state.stats.byDifficulty[difficulty].currentStreak = 0
}

function recordWin(state, difficulty, seconds, mistakes) {
  var buckets = [state.stats.global, state.stats.byDifficulty[difficulty]]
  for (var i = 0; i < buckets.length; i++) {
    var s = buckets[i]
    s.won++; s.currentStreak++; s.bestStreak = Math.max(s.bestStreak, s.currentStreak)
    s.totalWinSeconds += seconds; s.mistakes += mistakes
    if (!s.bestSeconds || seconds < s.bestSeconds) s.bestSeconds = seconds
  }
}
