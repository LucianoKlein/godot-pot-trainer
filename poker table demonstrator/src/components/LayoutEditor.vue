<script setup lang="ts">
import { ref } from 'vue'
import { useGameStore } from '../stores/gameStore'
import type { LayoutConfig } from '../types/poker'

const store = useGameStore()

const dragging = ref<{ category: keyof LayoutConfig; index: number | null } | null>(null)

interface HandleDef {
  category: keyof LayoutConfig
  index: number | null
  color: string
  label: string
  x: number
  y: number
}

// Categories whose coordinates are relative to table-container
const TABLE_CONTAINER_CATEGORIES = new Set(['seats'])

function getHandles(): HandleDef[] {
  const handles: HandleDef[] = []
  const cfg = store.layoutConfig

  for (let i = 0; i < 9; i++) {
    handles.push({ category: 'seats', index: i, color: '#3498db', label: `S${i + 1}`, x: cfg.seats[i].x, y: cfg.seats[i].y })
    handles.push({ category: 'cards', index: i, color: '#e74c3c', label: `C${i + 1}`, x: cfg.cards[i].x, y: cfg.cards[i].y })
    handles.push({ category: 'stacks', index: i, color: '#2ecc71', label: `$${i + 1}`, x: cfg.stacks[i].x, y: cfg.stacks[i].y })
    handles.push({ category: 'bets', index: i, color: '#f1c40f', label: `B${i + 1}`, x: cfg.bets[i].x, y: cfg.bets[i].y })
    handles.push({ category: 'dealerButtons', index: i, color: '#fff', label: `D${i + 1}`, x: cfg.dealerButtons[i].x, y: cfg.dealerButtons[i].y })
  }

  handles.push({ category: 'pot', index: null, color: '#9b59b6', label: 'POT', x: cfg.pot.x, y: cfg.pot.y })
  handles.push({ category: 'muck', index: null, color: '#9b59b6', label: 'MUCK', x: cfg.muck.x, y: cfg.muck.y })

  return handles
}

function onMouseDown(e: MouseEvent, category: keyof LayoutConfig, index: number | null) {
  e.preventDefault()
  e.stopPropagation()
  dragging.value = { category, index }

  // Pick the correct reference container
  const selector = TABLE_CONTAINER_CATEGORIES.has(category) ? '.table-container' : '.poker-table'

  const onMouseMove = (ev: MouseEvent) => {
    if (!dragging.value) return
    const container = document.querySelector(selector)
    if (!container) return
    const rect = container.getBoundingClientRect()
    const x = ((ev.clientX - rect.left) / rect.width) * 100
    const y = ((ev.clientY - rect.top) / rect.height) * 100
    const clampedX = Math.round(Math.max(0, Math.min(100, x)) * 100) / 100
    const clampedY = Math.round(Math.max(0, Math.min(100, y)) * 100) / 100
    store.updateLayoutPosition(dragging.value.category, dragging.value.index, clampedX, clampedY)
  }

  const onMouseUp = () => {
    dragging.value = null
    window.removeEventListener('mousemove', onMouseMove)
    window.removeEventListener('mouseup', onMouseUp)
  }

  window.addEventListener('mousemove', onMouseMove)
  window.addEventListener('mouseup', onMouseUp)
}
</script>

<template>
  <div class="layout-editor">
    <div
      v-for="(h, idx) in getHandles()"
      :key="idx"
      class="drag-handle"
      :style="{
        left: h.x + '%',
        top: h.y + '%',
        borderColor: h.color,
        color: h.color,
      }"
      @mousedown="onMouseDown($event, h.category, h.index)"
    >
      <span class="handle-label">{{ h.label }}</span>
    </div>
  </div>
</template>

<style scoped>
.layout-editor {
  position: absolute;
  inset: 0;
  z-index: 50;
  pointer-events: none;
}

.drag-handle {
  position: absolute;
  transform: translate(-50%, -50%);
  width: 22px;
  height: 22px;
  border-radius: 50%;
  border: 2.5px solid;
  background: rgba(0, 0, 0, 0.7);
  cursor: grab;
  pointer-events: all;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 51;
  transition: transform 0.05s;
}

.drag-handle:hover {
  transform: translate(-50%, -50%) scale(1.4);
  z-index: 52;
}

.drag-handle:active {
  cursor: grabbing;
}

.handle-label {
  font-size: 6px;
  font-weight: 800;
  white-space: nowrap;
  pointer-events: none;
}
</style>
