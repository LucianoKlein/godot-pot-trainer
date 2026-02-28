<script setup lang="ts">
import { ref } from 'vue'
import { useGameStore } from '../stores/gameStore'
import { useTableLayout } from '../composables/useTableLayout'

const store = useGameStore()
const { communityCardsPosition } = useTableLayout()

const suitSymbol: Record<string, string> = {
  hearts: '\u2665',
  diamonds: '\u2666',
  clubs: '\u2663',
  spades: '\u2660',
}

const suitColor: Record<string, string> = {
  hearts: '#e74c3c',
  diamonds: '#3498db',
  clubs: '#2ecc71',
  spades: '#2c3e50',
}

const placeholderCards = [
  { rank: 'A', suit: 'spades' },
  { rank: 'K', suit: 'hearts' },
  { rank: 'Q', suit: 'clubs' },
  { rank: 'J', suit: 'diamonds' },
  { rank: '10', suit: 'spades' },
]

const dragging = ref(false)

function onMouseDown(e: MouseEvent) {
  if (!store.layoutMode) return
  e.preventDefault()
  e.stopPropagation()
  dragging.value = true

  const onMouseMove = (ev: MouseEvent) => {
    if (!dragging.value) return
    const container = document.querySelector('.poker-table')
    if (!container) return
    const rect = container.getBoundingClientRect()
    const x = ((ev.clientX - rect.left) / rect.width) * 100
    const y = ((ev.clientY - rect.top) / rect.height) * 100
    const clampedX = Math.round(Math.max(0, Math.min(100, x)) * 100) / 100
    const clampedY = Math.round(Math.max(0, Math.min(100, y)) * 100) / 100
    store.updateLayoutPosition('communityCards', null, clampedX, clampedY)
  }

  const onMouseUp = () => {
    dragging.value = false
    window.removeEventListener('mousemove', onMouseMove)
    window.removeEventListener('mouseup', onMouseUp)
  }

  window.addEventListener('mousemove', onMouseMove)
  window.addEventListener('mouseup', onMouseUp)
}
</script>

<template>
  <div
    class="community-cards"
    :class="{ 'layout-draggable': store.layoutMode, 'is-dragging': dragging }"
    :style="{
      left: communityCardsPosition.x + '%',
      top: communityCardsPosition.y + '%',
    }"
    @mousedown="onMouseDown"
  >
    <!-- Layout mode: show 5 placeholder cards -->
    <template v-if="store.layoutMode">
      <div
        v-for="(pc, i) in placeholderCards"
        :key="'ph-' + i"
        class="card placeholder"
      >
        <span class="card-rank">{{ pc.rank }}</span>
        <span class="card-suit" :style="{ color: suitColor[pc.suit] }">
          {{ suitSymbol[pc.suit] }}
        </span>
      </div>
    </template>

    <!-- Normal mode: show actual community cards -->
    <TransitionGroup v-else name="card-deal">
      <div
        v-for="card in store.communityCards"
        :key="card.id"
        class="card"
      >
        <span class="card-rank">{{ card.rank }}</span>
        <span class="card-suit" :style="{ color: suitColor[card.suit] }">
          {{ suitSymbol[card.suit] }}
        </span>
      </div>
    </TransitionGroup>
  </div>
</template>

<style scoped>
.community-cards {
  position: absolute;
  transform: translate(-50%, -50%);
  display: flex;
  gap: 6px;
  z-index: 8;
}

.community-cards.layout-draggable {
  cursor: grab;
  z-index: 55;
}

.community-cards.is-dragging {
  cursor: grabbing;
}

.card {
  width: 48px;
  height: 66px;
  background: #fff;
  border-radius: 5px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  box-shadow: 0 3px 8px rgba(0, 0, 0, 0.35);
}

.card.placeholder {
  opacity: 0.85;
  border: 2px dashed #9b59b6;
}

.card-rank {
  font-size: 17px;
  font-weight: 700;
  color: #333;
  line-height: 1;
}

.card-suit {
  font-size: 20px;
  line-height: 1;
}

.card-deal-enter-active {
  transition: all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.card-deal-enter-from {
  opacity: 0;
  transform: translateY(-30px) scale(0.5);
}
</style>
