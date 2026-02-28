import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Card, Player, Street, Suit, Rank, LayoutConfig, PitchState } from '@/types/poker'
import defaultLayout from '@/assets/defaultLayout.json'
import { saveLayout, loadLayout } from '@/services/layoutService'

const SUITS: Suit[] = ['hearts', 'diamonds', 'clubs', 'spades']
const RANKS: Rank[] = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
const SUIT_SHORT: Record<Suit, string> = { hearts: 'h', diamonds: 'd', clubs: 'c', spades: 's' }

function buildDeck(): Card[] {
  const deck: Card[] = []
  for (const suit of SUITS) {
    for (const rank of RANKS) {
      deck.push({ suit, rank, id: `${rank}${SUIT_SHORT[suit]}`, faceUp: false })
    }
  }
  return deck
}

function shuffleDeck(deck: Card[]): Card[] {
  const d = [...deck]
  for (let i = d.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[d[i], d[j]] = [d[j], d[i]]
  }
  return d
}

export const useGameStore = defineStore('game', () => {
  // --- State ---
  const players = ref<Player[]>([])
  const communityCards = ref<Card[]>([])
  const deck = ref<Card[]>([])
  const muckPile = ref<Card[]>([])
  const pot = ref(0)
  const currentBet = ref(0)
  const lastRaiseIncrement = ref(0)  // tracks the increment of the last raise/bet
  const currentPlayerIndex = ref(-1)
  const dealerIndex = ref(0)
  const street = ref<Street>('preflop')
  const smallBlind = ref(10)
  const bigBlind = ref(20)
  const isHandInProgress = ref(false)
  const lastAction = ref('')

  // UI state
  const contextMenuPlayerId = ref<number | null>(null)
  const showRaiseDialog = ref(false)
  const raiseDialogPlayerId = ref<number | null>(null)
  const foldingCards = ref<{ playerId: number; cards: Card[] } | null>(null)

  // Out-of-turn state
  const outOfTurnMode = ref(false)
  const hasOutOfTurnAction = ref(false)

  // Show action indicator
  const showAction = ref(false)

  // Show aggressor indicator
  const showAggressor = ref(false)
  const aggressorPlayerId = ref<number | null>(null)

  // Pitch state
  const pitchState = ref<PitchState>({
    cardsPitched: 0,
    playerCardCounts: Array(9).fill(0),
    hasMispitch: false,
    mispitchPosition: null,
  })
  const showMisdealX = ref(false)
  const showMisdealMenu = ref(false)

  interface ActionSnapshot {
    players: Player[]
    communityCards: Card[]
    pot: number
    currentBet: number
    currentPlayerIndex: number
    street: Street
    isHandInProgress: boolean
    lastAction: string
    muckPile: Card[]
    deck: Card[]
  }
  const actionHistory = ref<ActionSnapshot[]>([])

  // Layout state
  const layoutMode = ref(false)
  const layoutConfig = ref<LayoutConfig>(JSON.parse(JSON.stringify(defaultLayout)))

  // --- Getters ---
  const activePlayers = computed(() => players.value.filter(p => !p.folded))
  const currentPlayer = computed(() =>
    currentPlayerIndex.value >= 0 ? players.value[currentPlayerIndex.value] : null
  )
  const hasBetToMatch = computed(() => {
    if (!currentPlayer.value) return false
    return currentBet.value > currentPlayer.value.currentBet
  })

  // --- Actions ---

  function initGame() {
    const newPlayers: Player[] = []
    for (let i = 0; i < 9; i++) {
      newPlayers.push({
        id: i + 1,
        name: `Player ${i + 1}`,
        chips: 1000,
        holeCards: [],
        currentBet: 0,
        folded: false,
        hasActed: false,
      })
    }
    players.value = newPlayers
    communityCards.value = []
    muckPile.value = []
    pot.value = 0
    currentBet.value = 0
    currentPlayerIndex.value = -1
    street.value = 'preflop'
    isHandInProgress.value = false
    lastAction.value = ''
    foldingCards.value = null
  }

  function startHand() {
    for (const p of players.value) {
      p.holeCards = []
      p.currentBet = 0
      p.folded = false
      p.hasActed = false
    }
    communityCards.value = []
    muckPile.value = []
    pot.value = 0
    currentBet.value = 0
    foldingCards.value = null
    contextMenuPlayerId.value = null
    showRaiseDialog.value = false
    hasOutOfTurnAction.value = false
    actionHistory.value = []

    deck.value = shuffleDeck(buildDeck())

    // Post blinds
    const sbIndex = nextActiveIndex(dealerIndex.value)
    const bbIndex = nextActiveIndex(sbIndex)

    const sbPlayer = players.value[sbIndex]
    const sbAmount = Math.min(smallBlind.value, sbPlayer.chips)
    sbPlayer.chips -= sbAmount
    sbPlayer.currentBet = sbAmount

    const bbPlayer = players.value[bbIndex]
    const bbAmount = Math.min(bigBlind.value, bbPlayer.chips)
    bbPlayer.chips -= bbAmount
    bbPlayer.currentBet = bbAmount

    currentBet.value = bbAmount
    lastRaiseIncrement.value = bbAmount
    aggressorPlayerId.value = bbPlayer.id

    // Enter pitch phase — cards are NOT dealt yet
    street.value = 'pitch'
    isHandInProgress.value = true
    currentPlayerIndex.value = -1
    const firstReceiver = nextActiveIndex(dealerIndex.value) // player left of dealer
    pitchState.value = {
      cardsPitched: 0,
      playerCardCounts: Array(9).fill(0),
      hasMispitch: false,
      mispitchPosition: null,
      expectedPlayerIndex: firstReceiver,
      currentRound: 0,
      faceUpCards: [],
      totalFaceUp: 0,
      replacementPhase: false,
      replacementPlayerIndex: null,
      returningCard: null,
    }
    showMisdealX.value = false
    showMisdealMenu.value = false
    lastAction.value = `Blinds posted. Pitch cards to players.`
  }

  function nextActiveIndex(fromIndex: number): number {
    let idx = (fromIndex + 1) % players.value.length
    let count = 0
    while (players.value[idx].folded && count < players.value.length) {
      idx = (idx + 1) % players.value.length
      count++
    }
    return idx
  }

  function saveSnapshot(): ActionSnapshot {
    return {
      players: players.value.map(p => ({ ...p, holeCards: [...p.holeCards] })),
      communityCards: [...communityCards.value],
      pot: pot.value,
      currentBet: currentBet.value,
      currentPlayerIndex: currentPlayerIndex.value,
      street: street.value,
      isHandInProgress: isHandInProgress.value,
      lastAction: lastAction.value,
      muckPile: [...muckPile.value],
      deck: [...deck.value],
    }
  }

  function undoLastAction() {
    const snapshot = actionHistory.value.pop()
    if (!snapshot) return
    players.value = snapshot.players
    communityCards.value = snapshot.communityCards
    pot.value = snapshot.pot
    currentBet.value = snapshot.currentBet
    currentPlayerIndex.value = snapshot.currentPlayerIndex
    street.value = snapshot.street
    isHandInProgress.value = snapshot.isHandInProgress
    lastAction.value = snapshot.lastAction
    muckPile.value = snapshot.muckPile
    deck.value = snapshot.deck
    foldingCards.value = null
    hasOutOfTurnAction.value = actionHistory.value.length > 0 && outOfTurnMode.value
  }

  function playerAction(playerId: number, action: string, amount?: number) {
    const playerIdx = players.value.findIndex(p => p.id === playerId)
    if (playerIdx === -1) return

    // Save snapshot before action
    actionHistory.value.push(saveSnapshot())

    // Detect out-of-turn
    if (outOfTurnMode.value && players.value[currentPlayerIndex.value]?.id !== playerId) {
      hasOutOfTurnAction.value = true
    }

    switch (action) {
      case 'fold':
        handleFold(playerIdx)
        break
      case 'call':
        handleCall(playerIdx)
        break
      case 'raise':
        handleRaise(playerIdx, amount ?? 0)
        break
      case 'check':
        handleCheck(playerIdx)
        break
      case 'bet':
        handleBet(playerIdx, amount ?? 0)
        break
    }

    contextMenuPlayerId.value = null
    showRaiseDialog.value = false
  }

  function handleFold(playerIdx: number) {
    const player = players.value[playerIdx]
    foldingCards.value = { playerId: player.id, cards: [...player.holeCards] }
    player.folded = true
    player.hasActed = true
    lastAction.value = `${player.name} folds`

    setTimeout(() => {
      muckPile.value.push(...(foldingCards.value?.cards ?? []))
      foldingCards.value = null
    }, 500)

    player.holeCards = []
    checkStreetEnd(playerIdx)
  }

  function handleCall(playerIdx: number) {
    const player = players.value[playerIdx]
    const callAmount = currentBet.value - player.currentBet
    const actual = Math.min(callAmount, player.chips)
    player.chips -= actual
    player.currentBet += actual
    player.hasActed = true
    lastAction.value = `${player.name} calls $${actual}`
    checkStreetEnd(playerIdx)
  }

  function handleRaise(playerIdx: number, raiseTotal: number) {
    const player = players.value[playerIdx]
    const toAdd = raiseTotal - player.currentBet
    const actual = Math.min(toAdd, player.chips)
    player.chips -= actual
    player.currentBet += actual
    lastRaiseIncrement.value = player.currentBet - currentBet.value
    currentBet.value = player.currentBet
    player.hasActed = true
    aggressorPlayerId.value = player.id
    lastAction.value = `${player.name} raises to $${player.currentBet}`

    for (const p of players.value) {
      if (p.id !== player.id && !p.folded) {
        p.hasActed = false
      }
    }

    checkStreetEnd(playerIdx)
  }

  function handleCheck(playerIdx: number) {
    const player = players.value[playerIdx]
    player.hasActed = true
    lastAction.value = `${player.name} checks`
    checkStreetEnd(playerIdx)
  }

  function handleBet(playerIdx: number, betAmount: number) {
    const player = players.value[playerIdx]
    const actual = Math.min(betAmount, player.chips)
    player.chips -= actual
    player.currentBet = actual
    lastRaiseIncrement.value = actual
    currentBet.value = actual
    player.hasActed = true
    aggressorPlayerId.value = player.id
    lastAction.value = `${player.name} bets $${actual}`

    for (const p of players.value) {
      if (p.id !== player.id && !p.folded) {
        p.hasActed = false
      }
    }

    checkStreetEnd(playerIdx)
  }

  function checkStreetEnd(lastActorIdx: number) {
    const active = players.value.filter(p => !p.folded)
    if (active.length <= 1) {
      collectBets()
      if (active.length === 1) {
        lastAction.value = `${active[0].name} wins $${pot.value}!`
        active[0].chips += pot.value
        pot.value = 0
      }
      isHandInProgress.value = false
      currentPlayerIndex.value = -1
      return
    }

    const allActed = active.every(p => p.hasActed)
    const allMatched = active.every(p => p.currentBet === currentBet.value || p.chips === 0)

    if (allActed && allMatched) {
      advanceStreet()
    } else {
      currentPlayerIndex.value = nextActiveIndex(lastActorIdx)
    }
  }

  function collectBets() {
    for (const p of players.value) {
      pot.value += p.currentBet
      p.currentBet = 0
    }
  }

  function advanceStreet() {
    collectBets()
    currentBet.value = 0
    lastRaiseIncrement.value = 0
    aggressorPlayerId.value = null

    for (const p of players.value) {
      if (!p.folded) {
        p.hasActed = false
      }
    }

    const nextStreets: Record<string, Street> = {
      pitch: 'preflop',
      preflop: 'flop',
      flop: 'turn',
      turn: 'river',
      river: 'showdown',
    }

    street.value = nextStreets[street.value] ?? 'showdown'

    if (street.value === 'showdown') {
      isHandInProgress.value = false
      currentPlayerIndex.value = -1
      lastAction.value = `Showdown! Pot: $${pot.value}`
      return
    }

    if (street.value === 'flop') {
      deck.value.pop()
      for (let i = 0; i < 3; i++) {
        const c = deck.value.pop()!
        c.faceUp = true
        communityCards.value.push(c)
      }
    } else if (street.value === 'turn' || street.value === 'river') {
      deck.value.pop()
      const c = deck.value.pop()!
      c.faceUp = true
      communityCards.value.push(c)
    }

    currentPlayerIndex.value = nextActiveIndex(dealerIndex.value)
    lastAction.value = `Street: ${street.value}`
  }

  function resetGame() {
    initGame()
  }

  function openContextMenu(playerId: number) {
    if (layoutMode.value) return
    if (!isHandInProgress.value) return
    const player = players.value.find(p => p.id === playerId)
    if (!player || player.folded) return
    if (!outOfTurnMode.value && players.value[currentPlayerIndex.value]?.id !== playerId) return
    contextMenuPlayerId.value = playerId
  }

  function closeContextMenu() {
    contextMenuPlayerId.value = null
  }

  function openRaiseDialog(playerId: number) {
    raiseDialogPlayerId.value = playerId
    showRaiseDialog.value = true
    contextMenuPlayerId.value = null
  }

  function closeRaiseDialog() {
    showRaiseDialog.value = false
    raiseDialogPlayerId.value = null
  }

  function setPlayerChips(playerId: number, chips: number) {
    const player = players.value.find(p => p.id === playerId)
    if (player) {
      player.chips = chips
    }
  }

  function moveDealerButton() {
    dealerIndex.value = (dealerIndex.value + 1) % players.value.length
  }

  // --- Pitch actions ---

  function pitchCardToPlayer(playerIndex: number, faceUp: boolean = false) {
    if (street.value !== 'pitch') return
    if (pitchState.value.hasMispitch) return

    // Replacement phase: only the exposed player can receive
    if (pitchState.value.replacementPhase) {
      if (playerIndex !== pitchState.value.replacementPlayerIndex) return

      const card = deck.value.pop()!
      card.faceUp = false
      // Remove the face-up card from player's hand
      const faceUpIdx = players.value[playerIndex].holeCards.findIndex(c => c.faceUp)
      if (faceUpIdx !== -1) {
        const removedCard = players.value[playerIndex].holeCards.splice(faceUpIdx, 1)[0]
        // Put removed card back into deck (it goes to bottom)
        removedCard.faceUp = false
        deck.value.unshift(removedCard)
      }
      // Give replacement card
      players.value[playerIndex].holeCards.push(card)

      pitchState.value.replacementPhase = false
      pitchState.value.replacementPlayerIndex = null
      pitchState.value.faceUpCards = []
      pitchState.value.totalFaceUp = 0

      lastAction.value = `Replacement card dealt to ${players.value[playerIndex].name}. Pre-flop betting begins.`
      completePitch()
      return
    }

    if (pitchState.value.playerCardCounts[playerIndex] >= 2) return

    // Enforce clockwise order — wrong player triggers misdeal
    if (playerIndex !== pitchState.value.expectedPlayerIndex) {
      pitchState.value.hasMispitch = true
      pitchState.value.mispitchPosition = null
      showMisdealX.value = true
      lastAction.value = `Wrong order! Expected ${players.value[pitchState.value.expectedPlayerIndex].name}, got ${players.value[playerIndex].name}. Misdeal!`
      return
    }

    const card = deck.value.pop()!
    card.faceUp = faceUp
    players.value[playerIndex].holeCards.push(card)

    pitchState.value.playerCardCounts[playerIndex]++
    pitchState.value.cardsPitched++

    if (faceUp) {
      pitchState.value.totalFaceUp++
      pitchState.value.faceUpCards.push({
        playerIndex,
        cardIndex: pitchState.value.playerCardCounts[playerIndex] - 1,
        card,
      })

      // Check misdeal conditions for face-up cards
      const sbIndex = nextActiveIndex(dealerIndex.value)
      const bbIndex = nextActiveIndex(sbIndex)

      // First card to SB face-up = misdeal
      const isFirstCardToSB = pitchState.value.currentRound === 0 && playerIndex === sbIndex
      // First card to BB face-up = misdeal
      const isFirstCardToBB = pitchState.value.currentRound === 0 && playerIndex === bbIndex

      if (isFirstCardToSB || isFirstCardToBB || pitchState.value.totalFaceUp >= 2) {
        pitchState.value.hasMispitch = true
        pitchState.value.mispitchPosition = null
        showMisdealX.value = true
        const reason = isFirstCardToSB
          ? 'First card to SB dealt face-up'
          : isFirstCardToBB
          ? 'First card to BB dealt face-up'
          : 'Two or more cards dealt face-up'
        lastAction.value = `${reason}. Misdeal!`
        return
      }
    }

    // Advance expected player to next in clockwise order
    const nextExpected = nextActiveIndex(playerIndex)
    const firstReceiver = nextActiveIndex(dealerIndex.value)
    if (nextExpected === firstReceiver) {
      pitchState.value.currentRound++
    }
    pitchState.value.expectedPlayerIndex = nextExpected

    lastAction.value = `Card ${pitchState.value.cardsPitched}/18 pitched to ${players.value[playerIndex].name}${faceUp ? ' (FACE UP!)' : ''}`

    if (pitchState.value.cardsPitched >= players.value.length * 2) {
      // Check if we need replacement phase (exactly 1 face-up, not triggering misdeal)
      if (pitchState.value.totalFaceUp === 1) {
        const exposed = pitchState.value.faceUpCards[0]
        pitchState.value.replacementPhase = true
        pitchState.value.replacementPlayerIndex = exposed.playerIndex
        lastAction.value = `All cards pitched. ${players.value[exposed.playerIndex].name} has an exposed card — deal replacement.`
      } else {
        completePitch()
      }
    }
  }

  function mispitch(x: number, y: number) {
    if (street.value !== 'pitch') return
    if (pitchState.value.hasMispitch) return

    pitchState.value.hasMispitch = true
    pitchState.value.mispitchPosition = { x, y }
    showMisdealX.value = true
    lastAction.value = 'Mispitch! Click the X to declare a misdeal.'
  }

  function declareMisdeal() {
    showMisdealX.value = false
    showMisdealMenu.value = false

    for (const p of players.value) {
      p.holeCards = []
    }

    deck.value = shuffleDeck(buildDeck())

    const firstReceiver = nextActiveIndex(dealerIndex.value)
    pitchState.value = {
      cardsPitched: 0,
      playerCardCounts: Array(9).fill(0),
      hasMispitch: false,
      mispitchPosition: null,
      expectedPlayerIndex: firstReceiver,
      currentRound: 0,
      faceUpCards: [],
      totalFaceUp: 0,
      replacementPhase: false,
      replacementPlayerIndex: null,
      returningCard: null,
    }

    lastAction.value = 'Misdeal declared. Pitch again from scratch.'
  }

  function completePitch() {
    street.value = 'preflop'
    const sbIndex = nextActiveIndex(dealerIndex.value)
    const bbIndex = nextActiveIndex(sbIndex)
    currentPlayerIndex.value = nextActiveIndex(bbIndex)
    lastAction.value = 'All cards pitched. Pre-flop betting begins.'
  }

  // --- Layout actions ---

  function toggleLayoutMode() {
    layoutMode.value = !layoutMode.value
  }

  function updateLayoutPosition(
    category: keyof LayoutConfig,
    index: number | null,
    x: number,
    y: number
  ) {
    const config = layoutConfig.value
    if (index !== null) {
      const arr = config[category] as { x: number; y: number }[]
      if (arr && arr[index]) {
        arr[index].x = x
        arr[index].y = y
      }
    } else {
      const pos = config[category] as { x: number; y: number }
      if (pos) {
        pos.x = x
        pos.y = y
      }
    }
  }

  function exportLayout(): string {
    return JSON.stringify(layoutConfig.value, null, 2)
  }

  function importLayout(json: string) {
    try {
      const parsed = JSON.parse(json) as LayoutConfig
      layoutConfig.value = parsed
    } catch {
      console.error('Invalid layout JSON')
    }
  }

  function resetLayout() {
    layoutConfig.value = JSON.parse(JSON.stringify(defaultLayout))
  }

  function setAvatarScale(scale: number) {
    layoutConfig.value.avatarScale = scale
  }

  async function loadLayoutFromDB() {
    const saved = await loadLayout()
    if (saved) {
      layoutConfig.value = saved
    }
  }

  async function saveLayoutToDB() {
    await saveLayout(layoutConfig.value)
  }

  return {
    // State
    players,
    communityCards,
    deck,
    muckPile,
    pot,
    currentBet,
    lastRaiseIncrement,
    currentPlayerIndex,
    dealerIndex,
    street,
    smallBlind,
    bigBlind,
    isHandInProgress,
    lastAction,
    contextMenuPlayerId,
    showRaiseDialog,
    raiseDialogPlayerId,
    foldingCards,
    layoutMode,
    layoutConfig,
    outOfTurnMode,
    hasOutOfTurnAction,
    showAction,
    showAggressor,
    aggressorPlayerId,
    pitchState,
    showMisdealX,
    showMisdealMenu,
    // Getters
    activePlayers,
    currentPlayer,
    hasBetToMatch,
    // Actions
    initGame,
    startHand,
    playerAction,
    resetGame,
    openContextMenu,
    closeContextMenu,
    openRaiseDialog,
    closeRaiseDialog,
    setPlayerChips,
    moveDealerButton,
    pitchCardToPlayer,
    mispitch,
    declareMisdeal,
    toggleLayoutMode,
    updateLayoutPosition,
    exportLayout,
    importLayout,
    resetLayout,
    undoLastAction,
    loadLayoutFromDB,
    saveLayoutToDB,
    setAvatarScale,
  }
})
