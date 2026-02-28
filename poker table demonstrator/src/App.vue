<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue'
import { useGameStore } from './stores/gameStore'
import PokerTable from './components/PokerTable.vue'
import GameControls from './components/GameControls.vue'

const store = useGameStore()

function onKeydown(e: KeyboardEvent) {
  // Ignore when typing in inputs or when dialogs/layout mode are active
  if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return
  if (store.layoutMode || store.showRaiseDialog) return
  if (store.street === 'pitch') return
  if (!store.isHandInProgress || !store.currentPlayer) return

  const player = store.currentPlayer
  const key = e.key.toLowerCase()

  if (key === 'f') {
    store.playerAction(player.id, 'fold')
  } else if (key === 'c') {
    if (store.hasBetToMatch) {
      store.playerAction(player.id, 'call')
    } else {
      store.playerAction(player.id, 'check')
    }
  } else if (key === 'r' || key === 'b') {
    store.openRaiseDialog(player.id)
  } else {
    return
  }

  store.closeContextMenu()
}

onMounted(async () => {
  store.initGame()
  await store.loadLayoutFromDB()
  window.addEventListener('keydown', onKeydown)
})

onUnmounted(() => {
  window.removeEventListener('keydown', onKeydown)
})
</script>

<template>
  <div class="app">
    <GameControls />
    <PokerTable />
  </div>
</template>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  background: #0a0e14;
  color: #e0e0e0;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  min-height: 100vh;
  overflow: hidden;
}

.app {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-height: 100vh;
  padding: 10px;
}
</style>
