<script setup lang="ts">
import { computed } from 'vue'
import { useGameStore } from '../stores/gameStore'
import { useTableLayout } from '../composables/useTableLayout'

const store = useGameStore()
const { dealerButtonPosition } = useTableLayout()

const position = computed(() => dealerButtonPosition.value(store.dealerIndex))
</script>

<template>
  <div
    class="dealer-button"
    :style="{
      left: position.x + '%',
      top: position.y + '%',
    }"
  >
    D
  </div>
</template>

<style scoped>
.dealer-button {
  position: absolute;
  transform: translate(-50%, -50%);
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: linear-gradient(135deg, #fff, #ddd);
  color: #333;
  font-size: 14px;
  font-weight: 800;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.4);
  z-index: 15;
  pointer-events: none;
  border: 2px solid #999;
  transition: left 0.4s ease, top 0.4s ease;
}
</style>
