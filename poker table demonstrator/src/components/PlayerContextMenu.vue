<script setup lang="ts">
import { computed, ref, onMounted, nextTick, watch } from 'vue'
import { useGameStore } from '../stores/gameStore'
import { useTableLayout } from '../composables/useTableLayout'

const store = useGameStore()
const { seatPositions } = useTableLayout()

const menuRef = ref<HTMLElement | null>(null)
const menuStyle = ref({ left: '0px', top: '0px' })

const menuPlayer = computed(() =>
  store.players.find(p => p.id === store.contextMenuPlayerId)
)

const menuPlayerIndex = computed(() =>
  store.players.findIndex(p => p.id === store.contextMenuPlayerId)
)

const hasBet = computed(() => {
  if (!menuPlayer.value) return false
  return store.currentBet > menuPlayer.value.currentBet
})

function positionMenu() {
  nextTick(() => {
    if (menuPlayerIndex.value < 0 || !menuRef.value) return

    const pos = seatPositions.value[menuPlayerIndex.value]
    const container = document.querySelector('.table-container')
    if (!container) return
    const containerRect = container.getBoundingClientRect()

    const px = containerRect.left + (pos.x / 100) * containerRect.width
    const py = containerRect.top + (pos.y / 100) * containerRect.height

    const menuEl = menuRef.value
    const menuW = menuEl.offsetWidth
    const menuH = menuEl.offsetHeight
    const margin = 8

    // Place menu close to the player: 8px gap
    let left = px - menuW / 2
    let top = py - menuH - 8

    // If player is in the top half, place menu below instead
    if (pos.y < 40) {
      top = py + 8
    }

    // Clamp horizontally
    if (left < margin) left = margin
    if (left + menuW > window.innerWidth - margin) left = window.innerWidth - margin - menuW

    // Clamp vertically
    if (top < margin) top = py + 8
    if (top + menuH > window.innerHeight - margin) {
      top = window.innerHeight - margin - menuH
    }

    menuStyle.value = { left: left + 'px', top: top + 'px' }
  })
}

watch(() => store.contextMenuPlayerId, () => {
  if (store.contextMenuPlayerId !== null) {
    positionMenu()
  }
})

onMounted(() => {
  positionMenu()
})

function handleFold() {
  if (menuPlayer.value) store.playerAction(menuPlayer.value.id, 'fold')
}
function handleCall() {
  if (menuPlayer.value) store.playerAction(menuPlayer.value.id, 'call')
}
function handleCheck() {
  if (menuPlayer.value) store.playerAction(menuPlayer.value.id, 'check')
}
function handleRaise() {
  if (menuPlayer.value) store.openRaiseDialog(menuPlayer.value.id)
}
function handleBet() {
  if (menuPlayer.value) store.openRaiseDialog(menuPlayer.value.id)
}
function handleClickOutside() {
  store.closeContextMenu()
}
</script>

<template>
  <Teleport to="body">
    <div class="context-overlay" @click.self="handleClickOutside">
      <div
        ref="menuRef"
        class="context-menu"
        :style="menuStyle"
      >
        <div class="menu-header">{{ menuPlayer?.name }}</div>
        <template v-if="hasBet">
          <button class="menu-btn fold-btn" @click="handleFold">Fold</button>
          <button class="menu-btn call-btn" @click="handleCall">
            Call ${{ store.currentBet - (menuPlayer?.currentBet ?? 0) }}
          </button>
          <button class="menu-btn raise-btn" @click="handleRaise">Raise</button>
        </template>
        <template v-else>
          <button class="menu-btn check-btn" @click="handleCheck">Check</button>
          <button class="menu-btn bet-btn" @click="handleBet">Bet</button>
          <button class="menu-btn fold-btn" @click="handleFold">Fold</button>
        </template>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.context-overlay {
  position: fixed;
  inset: 0;
  z-index: 100;
}

.context-menu {
  position: fixed;
  background: linear-gradient(135deg, #2a2a3e, #1c1c2e);
  border: 2px solid #555;
  border-radius: 10px;
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 130px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.6);
  z-index: 101;
}

.menu-header {
  font-size: 12px;
  font-weight: 700;
  color: #aaa;
  text-align: center;
  padding-bottom: 4px;
  border-bottom: 1px solid #444;
  margin-bottom: 2px;
}

.menu-btn {
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s, transform 0.1s;
  color: #fff;
}

.menu-btn:hover { transform: scale(1.03); }
.menu-btn:active { transform: scale(0.97); }

.fold-btn { background: #c0392b; }
.fold-btn:hover { background: #e74c3c; }
.call-btn { background: #27ae60; }
.call-btn:hover { background: #2ecc71; }
.raise-btn { background: #e67e22; }
.raise-btn:hover { background: #f39c12; }
.check-btn { background: #2980b9; }
.check-btn:hover { background: #3498db; }
.bet-btn { background: #e67e22; }
.bet-btn:hover { background: #f39c12; }
</style>
