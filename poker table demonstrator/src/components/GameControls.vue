<script setup lang="ts">
import { ref, computed } from 'vue'
import { useGameStore } from '../stores/gameStore'

const store = useGameStore()
const saving = ref(false)

const avatarScaleValue = computed({
  get: () => store.layoutConfig.avatarScale ?? 1,
  set: (v: number) => store.setAvatarScale(v),
})

const streetLabels: Record<string, string> = {
  pitch: 'Pitch',
  preflop: 'Pre-Flop',
  flop: 'Flop',
  turn: 'Turn',
  river: 'River',
  showdown: 'Showdown',
}

function handleExport() {
  const json = store.exportLayout()
  const blob = new Blob([json], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'layout.json'
  a.click()
  URL.revokeObjectURL(url)
}

function handleImport() {
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = '.json'
  input.onchange = () => {
    const file = input.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = () => {
      store.importLayout(reader.result as string)
    }
    reader.readAsText(file)
  }
  input.click()
}

async function handleSaveToDB() {
  saving.value = true
  try {
    await store.saveLayoutToDB()
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="game-controls">
    <div class="controls-left">
      <button class="ctrl-btn deal-btn" @click="store.startHand" :disabled="store.isHandInProgress || store.layoutMode">
        New Hand
      </button>
      <button class="ctrl-btn reset-btn" @click="store.resetGame" :disabled="store.layoutMode">
        Reset
      </button>
      <button class="ctrl-btn dealer-move-btn" @click="store.moveDealerButton" :disabled="store.isHandInProgress || store.layoutMode">
        Move Dealer
      </button>
    </div>
    <div class="controls-center">
      <div class="street-badge" v-if="store.isHandInProgress && !store.layoutMode">
        {{ streetLabels[store.street] ?? store.street }}
      </div>
      <div class="layout-badge" v-if="store.layoutMode">
        LAYOUT MODE
      </div>
      <div class="last-action" v-if="store.lastAction && !store.layoutMode">
        {{ store.lastAction }}
      </div>
    </div>
    <div class="controls-right">
      <template v-if="store.layoutMode">
        <div class="avatar-size-control">
          <span class="size-label">Size</span>
          <input type="range" min="0.5" max="2.5" step="0.1" v-model.number="avatarScaleValue" class="size-slider" />
          <span class="size-value">{{ avatarScaleValue.toFixed(1) }}x</span>
        </div>
        <button class="ctrl-btn export-btn" @click="handleExport">Export</button>
        <button class="ctrl-btn import-btn" @click="handleImport">Import</button>
        <button class="ctrl-btn save-db-btn" @click="handleSaveToDB" :disabled="saving">
          {{ saving ? 'Saving...' : 'Save to DB' }}
        </button>
        <button class="ctrl-btn reset-layout-btn" @click="store.resetLayout">Reset Layout</button>
      </template>
      <div class="blind-info" v-if="!store.layoutMode">
        Blinds: ${{ store.smallBlind }} / ${{ store.bigBlind }}
      </div>
      <label class="oot-toggle" v-if="!store.layoutMode">
        <input type="checkbox" v-model="store.outOfTurnMode" />
        <span>Out of Turn</span>
      </label>
      <label class="oot-toggle" v-if="!store.layoutMode">
        <input type="checkbox" v-model="store.showAction" />
        <span>Show Action</span>
      </label>
      <label class="oot-toggle" v-if="!store.layoutMode">
        <input type="checkbox" v-model="store.showAggressor" />
        <span>Show Aggressor</span>
      </label>
      <button
        class="ctrl-btn layout-btn"
        :class="{ active: store.layoutMode }"
        @click="store.toggleLayoutMode"
      >
        {{ store.layoutMode ? 'Exit Layout' : 'Layout' }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.game-controls {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 1360px;
  padding: 8px 16px;
  background: linear-gradient(135deg, #2a2a3e, #1c1c2e);
  border-radius: 10px;
  border: 1px solid #444;
  gap: 16px;
}

.controls-left,
.controls-right {
  display: flex;
  gap: 6px;
  align-items: center;
}

.controls-center {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}

.ctrl-btn {
  padding: 7px 14px;
  border: none;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s, opacity 0.15s;
  color: #fff;
  white-space: nowrap;
}

.ctrl-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.deal-btn { background: #27ae60; }
.deal-btn:hover:not(:disabled) { background: #2ecc71; }

.reset-btn { background: #c0392b; }
.reset-btn:hover:not(:disabled) { background: #e74c3c; }

.dealer-move-btn { background: #2980b9; }
.dealer-move-btn:hover:not(:disabled) { background: #3498db; }

.layout-btn { background: #8e44ad; }
.layout-btn:hover { background: #9b59b6; }
.layout-btn.active { background: #e74c3c; }

.export-btn { background: #27ae60; }
.export-btn:hover { background: #2ecc71; }

.import-btn { background: #2980b9; }
.import-btn:hover { background: #3498db; }

.save-db-btn { background: #16a085; }
.save-db-btn:hover:not(:disabled) { background: #1abc9c; }

.reset-layout-btn { background: #e67e22; }
.reset-layout-btn:hover { background: #f39c12; }

.street-badge {
  background: #f1c40f;
  color: #1a1a1a;
  font-size: 22px;
  font-weight: 800;
  padding: 5px 24px;
  border-radius: 12px;
  letter-spacing: 1px;
  text-transform: uppercase;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.15);
}

.layout-badge {
  background: #e74c3c;
  color: #fff;
  font-size: 13px;
  font-weight: 700;
  padding: 3px 14px;
  border-radius: 10px;
  animation: pulse 1.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}

.last-action {
  font-size: 12px;
  color: #aaa;
  max-width: 300px;
  text-align: center;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.blind-info {
  font-size: 13px;
  color: #aaa;
  font-weight: 600;
  white-space: nowrap;
}

.oot-toggle {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  color: #ccc;
  cursor: pointer;
  white-space: nowrap;
}

.oot-toggle input[type="checkbox"] {
  accent-color: #e74c3c;
  width: 14px;
  height: 14px;
  cursor: pointer;
}

.avatar-size-control {
  display: flex;
  align-items: center;
  gap: 4px;
  white-space: nowrap;
}

.size-label {
  font-size: 11px;
  color: #ccc;
  font-weight: 600;
}

.size-slider {
  width: 70px;
  height: 4px;
  accent-color: #9b59b6;
  cursor: pointer;
}

.size-value {
  font-size: 11px;
  color: #aaa;
  font-weight: 600;
  min-width: 28px;
}
</style>
