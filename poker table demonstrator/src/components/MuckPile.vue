<script setup lang="ts">
import { useGameStore } from '../stores/gameStore'
import { useTableLayout } from '../composables/useTableLayout'

const store = useGameStore()
const { muckPosition } = useTableLayout()
</script>

<template>
  <div
    class="muck-pile"
    v-if="store.muckPile.length > 0"
    :style="{
      left: muckPosition.x + '%',
      top: muckPosition.y + '%',
    }"
  >
    <div
      v-for="(_, index) in store.muckPile.slice(0, 6)"
      :key="index"
      class="muck-card"
      :style="{
        transform: `rotate(${index * 15 - 30}deg) translate(${index * 2}px, ${index * 1}px)`,
      }"
    ></div>
    <div class="muck-count">{{ store.muckPile.length }}</div>
  </div>
</template>

<style scoped>
.muck-pile {
  position: absolute;
  transform: translate(-50%, -50%);
  z-index: 6;
  pointer-events: none;
  width: 50px;
  height: 40px;
}

.muck-card {
  position: absolute;
  width: 30px;
  height: 42px;
  background: linear-gradient(135deg, #2c3e8c, #1a237e);
  border: 1px solid #3f51b5;
  border-radius: 3px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
}

.muck-count {
  position: absolute;
  bottom: -14px;
  left: 50%;
  transform: translateX(-50%);
  font-size: 10px;
  color: rgba(255, 255, 255, 0.4);
}
</style>
