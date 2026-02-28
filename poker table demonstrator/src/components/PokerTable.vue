<script setup lang="ts">
import { useGameStore } from '../stores/gameStore'
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useTableLayout } from '../composables/useTableLayout'
import PlayerSeat from './PlayerSeat.vue'
import PlayerContextMenu from './PlayerContextMenu.vue'
import DealerButton from './DealerButton.vue'
import CommunityCards from './CommunityCards.vue'
import PotDisplay from './PotDisplay.vue'
import MuckPile from './MuckPile.vue'
import RaiseDialog from './RaiseDialog.vue'
import LayoutEditor from './LayoutEditor.vue'
import pitchingHandImg from '@/assets/hands/pitching hand.png'

const store = useGameStore()
const { seatPositions, cardPositions, stackPositions, betPositions, avatarScale, dealerButtonPosition } = useTableLayout()

const showGoBackMenu = ref(false)

function handleGoBack() {
  store.undoLastAction()
  showGoBackMenu.value = false
}

// --- Pitch phase ---
const hoveredZone = ref<number | null>(null)

const animatingCards = ref<{
  id: string
  fromX: number
  fromY: number
  toX: number
  toY: number
  rotation: number
  active: boolean
  faceUp: boolean
  card: { suit: string; rank: string } | null
}[]>([])

// Returning card animation (face-up card going back to pitching hand)
const returningCard = ref<{
  fromX: number
  fromY: number
  toX: number
  toY: number
  active: boolean
  card: { suit: string; rank: string }
} | null>(null)

// Auto-deal state
const autoDealing = ref(false)
let autoDealTimer: ReturnType<typeof setTimeout> | null = null

// Track how many cards have visually arrived at each player (for delayed display)
const arrivedCards = ref<{ faceUp: boolean; card: { suit: string; rank: string } | null }[][]>(
  Array.from({ length: 9 }, () => [])
)

function resetArrivedCards() {
  arrivedCards.value = Array.from({ length: 9 }, () => [])
}

// Pitching hand position: bottom edge center of poker-table
const pitchHandPos = { x: 50, y: 97 }

// Mouse tracking for pitching hand rotation
const mouseX = ref(0)
const mouseY = ref(0)

// U key tracking for face-up dealing
const uKeyHeld = ref(false)

function handleKeyDown(event: KeyboardEvent) {
  if (event.key === 'u' || event.key === 'U') uKeyHeld.value = true
}
function handleKeyUp(event: KeyboardEvent) {
  if (event.key === 'u' || event.key === 'U') uKeyHeld.value = false
}

function handleMouseMove(event: MouseEvent) {
  const table = document.querySelector('.poker-table')
  if (!table) return
  const rect = table.getBoundingClientRect()
  mouseX.value = ((event.clientX - rect.left) / rect.width) * 100
  mouseY.value = ((event.clientY - rect.top) / rect.height) * 100
}

const pitchHandRotation = computed(() => {
  if (store.street !== 'pitch') return 0
  const dx = mouseX.value - pitchHandPos.x
  const dy = mouseY.value - pitchHandPos.y
  // atan2 gives angle from positive X axis; we want angle from "up" (negative Y)
  const angle = Math.atan2(dx, -dy) * (180 / Math.PI)
  return angle
})

onMounted(() => {
  window.addEventListener('mousemove', handleMouseMove)
  window.addEventListener('keydown', handleKeyDown)
  window.addEventListener('keyup', handleKeyUp)
})

onUnmounted(() => {
  window.removeEventListener('mousemove', handleMouseMove)
  window.removeEventListener('keydown', handleKeyDown)
  window.removeEventListener('keyup', handleKeyUp)
  stopAutoDeal()
})

// Reset arrived cards when entering pitch phase or starting a new hand
watch(() => store.street, (newStreet) => {
  if (newStreet === 'pitch') {
    resetArrivedCards()
  }
})

function handleZoneClick(playerIndex: number) {
  if (store.street !== 'pitch') return
  if (store.pitchState.hasMispitch) return
  if (returningCard.value) return

  // Replacement phase: only the exposed player's zone is clickable
  if (store.pitchState.replacementPhase) {
    if (playerIndex !== store.pitchState.replacementPlayerIndex) return
  } else {
    if (store.pitchState.playerCardCounts[playerIndex] >= 2) return
  }

  const from = pitchHandPos
  const to = cardPositions.value[playerIndex]
  const isFaceUp = uKeyHeld.value

  // Peek at the top card of the deck for face-up display
  const topCard = store.deck.length > 0 ? store.deck[store.deck.length - 1] : null

  const cardId = `pitch-${Date.now()}-${Math.random()}`

  const animCard = {
    id: cardId,
    fromX: from.x,
    fromY: from.y,
    toX: to.x,
    toY: to.y,
    rotation: 2520 + Math.random() * 360,
    active: false,
    faceUp: isFaceUp,
    card: isFaceUp && topCard ? { suit: topCard.suit, rank: topCard.rank } : null,
  }

  animatingCards.value.push(animCard)

  // Immediately update store state
  const wasReplacement = store.pitchState.replacementPhase
  const replacementPlayerIdx = store.pitchState.replacementPlayerIndex
  store.pitchCardToPlayer(playerIndex, isFaceUp)

  requestAnimationFrame(() => {
    const card = animatingCards.value.find(c => c.id === cardId)
    if (card) card.active = true
  })

  setTimeout(() => {
    animatingCards.value = animatingCards.value.filter(c => c.id !== cardId)

    // Card has arrived — add to visible arrived cards
    arrivedCards.value[playerIndex].push({
      faceUp: isFaceUp,
      card: isFaceUp && animCard.card ? { ...animCard.card } : null,
    })

    // After replacement: animate the old face-up card back to pitching hand
    if (wasReplacement && replacementPlayerIdx !== null) {
      const cardPos = cardPositions.value[replacementPlayerIdx]
      const removedFaceUp = store.pitchState.faceUpCards.find(f => f.playerIndex === replacementPlayerIdx)
      const cardInfo = removedFaceUp?.card ?? { suit: 'spades', rank: 'A' }
      returningCard.value = {
        fromX: cardPos.x,
        fromY: cardPos.y,
        toX: pitchHandPos.x,
        toY: pitchHandPos.y,
        active: false,
        card: { suit: cardInfo.suit, rank: cardInfo.rank },
      }
      requestAnimationFrame(() => {
        if (returningCard.value) returningCard.value.active = true
      })
      setTimeout(() => {
        returningCard.value = null
      }, 500)
    }
  }, 800)
}

function handleTableClick(event: MouseEvent) {
  if (store.street !== 'pitch') return
  if (store.pitchState.hasMispitch) return

  const table = document.querySelector('.poker-table')
  if (!table) return
  const rect = table.getBoundingClientRect()
  const x = ((event.clientX - rect.left) / rect.width) * 100
  const y = ((event.clientY - rect.top) / rect.height) * 100

  const from = pitchHandPos
  const cardId = `mispitch-${Date.now()}`

  const animCard = {
    id: cardId,
    fromX: from.x,
    fromY: from.y,
    toX: x,
    toY: y,
    rotation: 180 + Math.random() * 180,
    active: false,
    faceUp: false,
    card: null,
  }

  animatingCards.value.push(animCard)

  requestAnimationFrame(() => {
    const card = animatingCards.value.find(c => c.id === cardId)
    if (card) card.active = true
  })

  setTimeout(() => {
    store.mispitch(x, y)
    animatingCards.value = animatingCards.value.filter(c => c.id !== cardId)
  }, 800)
}

// Auto-deal: pitch all cards automatically in clockwise order
function startAutoDeal() {
  if (store.street !== 'pitch') return
  if (autoDealing.value) return
  autoDealing.value = true
  autoDealStep()
}

function autoDealStep() {
  if (store.street !== 'pitch' || store.pitchState.hasMispitch) {
    autoDealing.value = false
    return
  }
  if (store.pitchState.replacementPhase) {
    autoDealing.value = false
    return
  }

  const expectedIdx = store.pitchState.expectedPlayerIndex
  if (store.pitchState.cardsPitched >= store.players.length * 2) {
    autoDealing.value = false
    return
  }

  handleZoneClick(expectedIdx)

  autoDealTimer = setTimeout(() => {
    autoDealStep()
  }, 150)
}

function stopAutoDeal() {
  autoDealing.value = false
  if (autoDealTimer) {
    clearTimeout(autoDealTimer)
    autoDealTimer = null
  }
}
</script>

<template>
  <div class="table-wrapper">
    <div class="table-container">
      <div class="poker-table" @click="handleTableClick">
        <!-- Betting line -->
        <div class="betting-line"></div>

        <!-- Center logo -->
        <div class="table-logo">REG</div>

        <!-- Community cards -->
        <CommunityCards />

        <!-- Pot display -->
        <PotDisplay />

        <!-- Muck pile -->
        <MuckPile />

        <!-- Dealer button -->
        <DealerButton />

        <!-- Out-of-turn warning -->
        <div v-if="store.hasOutOfTurnAction" class="oot-warning" @click.stop="showGoBackMenu = !showGoBackMenu">
          <span class="oot-icon">!</span>
          <Transition name="oot-menu">
            <div v-if="showGoBackMenu" class="oot-menu">
              <button class="oot-goback-btn" @click.stop="handleGoBack">Go Back</button>
            </div>
          </Transition>
        </div>

        <!-- Player hole cards ON the table -->
        <div
          v-for="(player, index) in store.players"
          :key="'cards-' + player.id"
          class="table-cards"
          :style="{
            left: cardPositions[index].x + '%',
            top: cardPositions[index].y + '%',
          }"
        >
          <!-- During pitch: show cards only after they visually arrive -->
          <template v-if="store.street === 'pitch'">
            <div
              v-for="(ac, cIdx) in arrivedCards[index]"
              :key="'pitched-' + cIdx"
              class="card"
              :class="ac.faceUp ? 'face-up-pitched' : 'face-down'"
            >
              <template v-if="ac.faceUp && ac.card">
                <span class="card-face-label">{{ ac.card.rank }}{{ { hearts: '♥', diamonds: '♦', clubs: '♣', spades: '♠' }[ac.card.suit] }}</span>
              </template>
              <template v-else>
                <div class="card-pattern"></div>
              </template>
            </div>
          </template>
          <!-- After pitch: normal display -->
          <template v-else-if="player.holeCards.length > 0 && !player.folded">
            <div class="card face-down"><div class="card-pattern"></div></div>
            <div class="card face-down"><div class="card-pattern"></div></div>
          </template>
        </div>

        <!-- Player money-behind (stacks) ON the table -->
        <div
          v-for="(player, index) in store.players"
          :key="'stack-' + player.id"
          class="table-stack"
          :style="{
            left: stackPositions[index].x + '%',
            top: stackPositions[index].y + '%',
          }"
        >
          <span class="stack-amount">${{ player.chips }}</span>
        </div>

        <!-- Player bet areas -->
        <div
          v-for="(player, index) in store.players"
          :key="'bet-' + player.id"
          class="bet-area"
          :style="{
            left: betPositions[index].x + '%',
            top: betPositions[index].y + '%',
          }"
        >
          <Transition name="bet-pop">
            <span v-if="player.currentBet > 0" class="bet-chip">
              ${{ player.currentBet }}
            </span>
          </Transition>
        </div>

        <!-- === PITCH PHASE UI === -->

        <!-- Pitching Hand (bottom center, follows mouse rotation) -->
        <div
          v-if="store.street === 'pitch'"
          class="pitching-hand"
          :style="{
            left: pitchHandPos.x + '%',
            top: pitchHandPos.y + '%',
            transform: 'translate(-50%, -50%) rotate(' + pitchHandRotation + 'deg)',
          }"
          @click.stop
        >
          <img :src="pitchingHandImg" alt="Pitching hand" class="pitching-hand-img" />
          <div class="deck-count">{{ store.deck.length }}</div>
        </div>

        <!-- Auto-deal button -->
        <div
          v-if="store.street === 'pitch' && !store.pitchState.hasMispitch && !store.pitchState.replacementPhase"
          class="auto-deal-btn"
          @click.stop="autoDealing ? stopAutoDeal() : startAutoDeal()"
        >
          {{ autoDealing ? 'Stop' : 'Auto Deal' }}
        </div>

        <!-- Card Landing Zones (pitch only) -->
        <template v-if="store.street === 'pitch'">
          <div
            v-for="(player, index) in store.players"
            :key="'zone-' + player.id"
            class="card-zone"
            :class="{
              'zone-hover': hoveredZone === index,
              'zone-filled-1': store.pitchState.playerCardCounts[index] === 1 && !store.pitchState.replacementPhase,
              'zone-filled-2': store.pitchState.playerCardCounts[index] >= 2 && !store.pitchState.replacementPhase,
              'zone-replacement': store.pitchState.replacementPhase && store.pitchState.replacementPlayerIndex === index,
              'zone-disabled': store.pitchState.replacementPhase && store.pitchState.replacementPlayerIndex !== index,
            }"
            :style="{
              left: cardPositions[index].x + '%',
              top: cardPositions[index].y + '%',
            }"
            @mouseenter="hoveredZone = index"
            @mouseleave="hoveredZone = null"
            @click.stop="handleZoneClick(index)"
          >
            <span v-if="store.pitchState.replacementPhase && store.pitchState.replacementPlayerIndex === index" class="zone-label">Replace</span>
            <span v-else class="zone-label">{{ arrivedCards[index].length }}/2</span>
          </div>
        </template>

        <!-- Animating pitched cards (multiple can fly simultaneously) -->
        <div
          v-for="aCard in animatingCards"
          :key="aCard.id"
          class="pitch-card-anim"
          :class="{ 'pitch-card-face-up': aCard.faceUp }"
          :style="{
            left: (aCard.active ? aCard.toX : aCard.fromX) + '%',
            top: (aCard.active ? aCard.toY : aCard.fromY) + '%',
            transform: 'translate(-50%, -50%) rotate(' + (aCard.active ? aCard.rotation : 0) + 'deg)',
          }"
        >
          <template v-if="aCard.faceUp && aCard.card">
            <span class="card-face-label">{{ aCard.card.rank }}{{ { hearts: '♥', diamonds: '♦', clubs: '♣', spades: '♠' }[aCard.card.suit] }}</span>
          </template>
          <template v-else>
            <div class="card-pattern"></div>
          </template>
        </div>

        <!-- Returning face-up card animation (back to pitching hand) -->
        <div
          v-if="returningCard"
          class="pitch-card-anim pitch-card-face-up returning-card"
          :style="{
            left: (returningCard.active ? returningCard.toX : returningCard.fromX) + '%',
            top: (returningCard.active ? returningCard.toY : returningCard.fromY) + '%',
          }"
        >
          <span class="card-face-label">{{ returningCard.card.rank }}{{ { hearts: '♥', diamonds: '♦', clubs: '♣', spades: '♠' }[returningCard.card.suit] }}</span>
        </div>

        <!-- Mispitched card stuck at wrong position -->
        <div
          v-if="store.pitchState.hasMispitch && store.pitchState.mispitchPosition"
          class="mispitch-card"
          :style="{
            left: store.pitchState.mispitchPosition.x + '%',
            top: store.pitchState.mispitchPosition.y + '%',
          }"
        >
          <div class="card-pattern"></div>
        </div>

        <!-- Layout editor overlay (when in layout mode) -->
        <LayoutEditor v-if="store.layoutMode" />
      </div>

      <!-- Player seats OUTSIDE the table -->
      <PlayerSeat
        v-for="(player, index) in store.players"
        :key="player.id"
        :player="player"
        :position="seatPositions[index]"
        :is-current="store.currentPlayerIndex === index"
        :avatar-scale="avatarScale"
        :show-action-indicator="store.showAction"
        :is-aggressor="store.showAggressor && store.aggressorPlayerId === player.id"
        @click="store.openContextMenu(player.id)"
      />
    </div>

    <!-- Context menu -->
    <PlayerContextMenu v-if="store.contextMenuPlayerId !== null" />

    <!-- Raise/Bet dialog -->
    <RaiseDialog v-if="store.showRaiseDialog" />

    <!-- Misdeal Red X overlay -->
    <Teleport to="body">
      <div v-if="store.showMisdealX" class="misdeal-overlay">
        <div class="misdeal-x" @click.stop="store.showMisdealMenu = !store.showMisdealMenu">
          X
          <Transition name="misdeal-menu">
            <div v-if="store.showMisdealMenu" class="misdeal-menu">
              <button class="misdeal-btn" @click.stop="store.declareMisdeal()">Misdeal</button>
            </div>
          </Transition>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.table-wrapper {
  position: relative;
}

.table-container {
  position: relative;
  width: 1360px;
  height: 750px;
}

.poker-table {
  position: absolute;
  top: 80px;
  left: 80px;
  right: 80px;
  bottom: 80px;
  background: url('@/assets/poker table.png') center / 100% 100% no-repeat;
  overflow: visible;
}

/* No pseudo-elements needed - the PNG has everything */
.poker-table::before,
.poker-table::after {
  display: none;
}

.betting-line {
  display: none;
}

/* Center logo */
.poker-table .table-logo {
  display: none;
}

/* Hole cards on table */
.table-cards {
  position: absolute;
  transform: translate(-50%, -50%);
  display: flex;
  gap: 2px;
  z-index: 4;
  pointer-events: none;
}

.card {
  width: 26px;
  height: 36px;
  border-radius: 3px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
}

.card.face-down {
  background: linear-gradient(135deg, #c0392b, #922b21);
  border: 1.5px solid #e74c3c;
  display: flex;
  align-items: center;
  justify-content: center;
}

.card.face-up-pitched {
  background: #fff;
  border: 1.5px solid #999;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 0 8px rgba(231, 76, 60, 0.6);
}

.card-face-label {
  font-size: 9px;
  font-weight: 900;
  line-height: 1;
  color: #1a1a1a;
}

.card.face-up-pitched .card-face-label {
  color: #1a1a1a;
}

/* Red suits */
.card.face-up-pitched:has(.card-face-label) .card-face-label {
  color: #1a1a1a;
}

.card-pattern {
  width: 16px;
  height: 26px;
  border: 1px solid rgba(255, 255, 255, 0.25);
  border-radius: 2px;
  background: repeating-linear-gradient(
    45deg,
    transparent,
    transparent 3px,
    rgba(255, 255, 255, 0.08) 3px,
    rgba(255, 255, 255, 0.08) 6px
  );
}

/* Money behind on table */
.table-stack {
  position: absolute;
  transform: translate(-50%, -50%);
  z-index: 4;
  pointer-events: none;
}

.stack-amount {
  display: inline-block;
  background: rgba(0, 0, 0, 0.55);
  color: #2ecc71;
  font-size: 12px;
  font-weight: 700;
  padding: 2px 8px;
  border-radius: 8px;
  white-space: nowrap;
  border: 1px solid rgba(46, 204, 113, 0.3);
}

/* Bet areas */
.bet-area {
  position: absolute;
  transform: translate(-50%, -50%);
  z-index: 5;
  pointer-events: none;
}

.bet-chip {
  display: inline-block;
  background: linear-gradient(135deg, #e8c84a, #c9a82c);
  color: #1a1a1a;
  font-weight: 700;
  font-size: 13px;
  padding: 3px 10px;
  border-radius: 12px;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.4);
  white-space: nowrap;
}

.bet-pop-enter-active {
  transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.bet-pop-leave-active {
  transition: all 0.2s ease-in;
}
.bet-pop-enter-from {
  opacity: 0;
  transform: scale(0);
}
.bet-pop-leave-to {
  opacity: 0;
  transform: scale(0);
}

/* Out-of-turn warning */
.oot-warning {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 20;
  cursor: pointer;
}

.oot-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: #e74c3c;
  color: #fff;
  font-size: 24px;
  font-weight: 900;
  box-shadow: 0 0 12px rgba(231, 76, 60, 0.7), 0 2px 8px rgba(0, 0, 0, 0.5);
  animation: oot-pulse 1s ease-in-out infinite;
  user-select: none;
}

@keyframes oot-pulse {
  0%, 100% { transform: scale(1); box-shadow: 0 0 12px rgba(231, 76, 60, 0.7); }
  50% { transform: scale(1.1); box-shadow: 0 0 20px rgba(231, 76, 60, 0.9); }
}

.oot-menu {
  position: absolute;
  top: 48px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(30, 30, 30, 0.95);
  border: 1px solid #e74c3c;
  border-radius: 8px;
  padding: 4px;
  white-space: nowrap;
}

.oot-goback-btn {
  padding: 6px 18px;
  background: #e74c3c;
  color: #fff;
  border: none;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.15s;
}

.oot-goback-btn:hover {
  background: #c0392b;
}

.oot-menu-enter-active {
  transition: all 0.2s ease-out;
}
.oot-menu-leave-active {
  transition: all 0.15s ease-in;
}
.oot-menu-enter-from,
.oot-menu-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(-4px);
}

/* === PITCH PHASE STYLES === */

/* Pitching Hand */
.pitching-hand {
  position: absolute;
  z-index: 16;
  pointer-events: none;
  transform-origin: center center;
}

.pitching-hand-img {
  width: 90px;
  height: auto;
  filter: drop-shadow(0 3px 6px rgba(0, 0, 0, 0.5));
}

.deck-count {
  text-align: center;
  font-size: 9px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.6);
  margin-top: -2px;
}

/* Auto-deal button */
.auto-deal-btn {
  position: absolute;
  bottom: 8px;
  right: 12px;
  z-index: 16;
  padding: 6px 16px;
  background: linear-gradient(135deg, #2980b9, #1a5276);
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  border-radius: 8px;
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4);
  user-select: none;
  transition: background 0.15s;
}

.auto-deal-btn:hover {
  background: linear-gradient(135deg, #3498db, #2471a3);
}

/* Card Landing Zones */
.card-zone {
  position: absolute;
  transform: translate(-50%, -50%);
  width: 60px;
  height: 42px;
  border: 2px dashed rgba(255, 255, 255, 0.25);
  border-radius: 6px;
  cursor: pointer;
  z-index: 12;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
  pointer-events: all;
}

.card-zone:hover,
.card-zone.zone-hover {
  border-color: #f1c40f;
  box-shadow: 0 0 14px rgba(241, 196, 15, 0.6), 0 0 28px rgba(241, 196, 15, 0.25);
  background: rgba(241, 196, 15, 0.08);
}

.card-zone.zone-filled-1 {
  border-color: rgba(46, 204, 113, 0.5);
}

.card-zone.zone-filled-1:hover {
  border-color: #2ecc71;
  box-shadow: 0 0 14px rgba(46, 204, 113, 0.6);
  background: rgba(46, 204, 113, 0.08);
}

.card-zone.zone-filled-2 {
  border-color: rgba(46, 204, 113, 0.2);
  opacity: 0.35;
  pointer-events: none;
  cursor: default;
}

.card-zone.zone-replacement {
  border-color: #e74c3c;
  box-shadow: 0 0 14px rgba(231, 76, 60, 0.7), 0 0 28px rgba(231, 76, 60, 0.3);
  background: rgba(231, 76, 60, 0.1);
  animation: replacement-pulse 1s ease-in-out infinite;
}

@keyframes replacement-pulse {
  0%, 100% { box-shadow: 0 0 14px rgba(231, 76, 60, 0.7); }
  50% { box-shadow: 0 0 24px rgba(231, 76, 60, 1), 0 0 40px rgba(231, 76, 60, 0.4); }
}

.card-zone.zone-disabled {
  opacity: 0.2;
  pointer-events: none;
  cursor: default;
}

.zone-label {
  font-size: 10px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.45);
  pointer-events: none;
}

/* Pitch Card Animation */
.pitch-card-anim {
  position: absolute;
  width: 26px;
  height: 36px;
  border-radius: 3px;
  background: linear-gradient(135deg, #c0392b, #922b21);
  border: 1.5px solid #e74c3c;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 25;
  pointer-events: none;
  transition: left 0.8s cubic-bezier(0.22, 1, 0.36, 1),
              top 0.8s cubic-bezier(0.22, 1, 0.36, 1),
              transform 0.8s cubic-bezier(0.22, 1, 0.36, 1);
}

.pitch-card-anim.pitch-card-face-up {
  background: #fff;
  border: 1.5px solid #999;
}

.pitch-card-anim .card-face-label {
  font-size: 9px;
  font-weight: 900;
  color: #1a1a1a;
}

/* Returning card animation */
.returning-card {
  transition: left 0.5s cubic-bezier(0.22, 1, 0.36, 1),
              top 0.5s cubic-bezier(0.22, 1, 0.36, 1);
  transform: translate(-50%, -50%);
}

/* Mispitched card at wrong position */
.mispitch-card {
  position: absolute;
  transform: translate(-50%, -50%) rotate(23deg);
  width: 26px;
  height: 36px;
  border-radius: 3px;
  background: linear-gradient(135deg, #c0392b, #922b21);
  border: 1.5px solid #e74c3c;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 18;
  pointer-events: none;
  box-shadow: 0 0 10px rgba(231, 76, 60, 0.7);
}

/* Misdeal Overlay */
.misdeal-overlay {
  position: fixed;
  inset: 0;
  z-index: 150;
  display: flex;
  align-items: center;
  justify-content: center;
}

.misdeal-x {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  background: #e74c3c;
  color: #fff;
  font-size: 40px;
  font-weight: 900;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 0 24px rgba(231, 76, 60, 0.8), 0 4px 16px rgba(0, 0, 0, 0.5);
  animation: misdeal-pulse 1s ease-in-out infinite;
  position: relative;
  user-select: none;
}

@keyframes misdeal-pulse {
  0%, 100% { transform: scale(1); box-shadow: 0 0 24px rgba(231, 76, 60, 0.8); }
  50% { transform: scale(1.15); box-shadow: 0 0 40px rgba(231, 76, 60, 1); }
}

.misdeal-menu {
  position: absolute;
  top: 92px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(30, 30, 30, 0.95);
  border: 2px solid #e74c3c;
  border-radius: 10px;
  padding: 6px;
  white-space: nowrap;
}

.misdeal-btn {
  padding: 10px 24px;
  background: #e74c3c;
  color: #fff;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.15s;
}

.misdeal-btn:hover {
  background: #c0392b;
}

.misdeal-menu-enter-active {
  transition: all 0.2s ease-out;
}
.misdeal-menu-leave-active {
  transition: all 0.15s ease-in;
}
.misdeal-menu-enter-from,
.misdeal-menu-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(-6px);
}
</style>
