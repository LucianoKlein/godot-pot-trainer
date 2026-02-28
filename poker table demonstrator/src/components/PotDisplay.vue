<script setup lang="ts">
import { useGameStore } from '../stores/gameStore'
import { useTableLayout } from '../composables/useTableLayout'

const store = useGameStore()
const { potPosition } = useTableLayout()
</script>

<template>
  <div
    class="pot-display"
    v-if="store.pot > 0 || store.isHandInProgress"
    :style="{
      left: potPosition.x + '%',
      top: potPosition.y + '%',
    }"
  >
    <div class="pot-label">POT</div>
    <div class="pot-amount">${{ store.pot }}</div>
  </div>
</template>

<style scoped>
.pot-display {
  position: absolute;
  transform: translate(-50%, -50%);
  text-align: center;
  z-index: 8;
  pointer-events: none;
}

.pot-label {
  font-size: 11px;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.5);
  letter-spacing: 2px;
  text-transform: uppercase;
}

.pot-amount {
  font-size: 20px;
  font-weight: 800;
  color: #f1c40f;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
}
</style>
