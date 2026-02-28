<script setup lang="ts">
import { useTableLayout } from '../composables/useTableLayout'

const { chipTrayPosition } = useTableLayout()
</script>

<template>
  <div
    class="chip-tray"
    :style="{
      left: chipTrayPosition.x + '%',
      top: chipTrayPosition.y + '%',
    }"
  >
    <!-- Tray body -->
    <div class="tray-body">
      <!-- Chip stacks (decorative) -->
      <div class="chip-stack">
        <div class="chip" style="background: #e74c3c;"></div>
        <div class="chip" style="background: #c0392b;"></div>
        <div class="chip" style="background: #e74c3c;"></div>
      </div>
      <div class="chip-stack">
        <div class="chip" style="background: #2ecc71;"></div>
        <div class="chip" style="background: #27ae60;"></div>
        <div class="chip" style="background: #2ecc71;"></div>
        <div class="chip" style="background: #27ae60;"></div>
      </div>
      <div class="chip-stack">
        <div class="chip" style="background: #3498db;"></div>
        <div class="chip" style="background: #2980b9;"></div>
        <div class="chip" style="background: #3498db;"></div>
      </div>
      <div class="chip-stack">
        <div class="chip" style="background: #1a1a1a;"></div>
        <div class="chip" style="background: #333;"></div>
        <div class="chip" style="background: #1a1a1a;"></div>
        <div class="chip" style="background: #333;"></div>
        <div class="chip" style="background: #1a1a1a;"></div>
      </div>
      <div class="chip-stack">
        <div class="chip" style="background: #e67e22;"></div>
        <div class="chip" style="background: #d35400;"></div>
        <div class="chip" style="background: #e67e22;"></div>
      </div>
    </div>
    <div class="tray-label">CHIP TRAY</div>
  </div>
</template>

<style scoped>
.chip-tray {
  position: absolute;
  transform: translate(-50%, -50%);
  z-index: 3;
  pointer-events: none;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}

.tray-body {
  display: flex;
  gap: 6px;
  background: linear-gradient(180deg, #2a2a2a, #1a1a1a);
  border: 2px solid #444;
  border-radius: 8px;
  padding: 6px 12px;
  box-shadow: inset 0 2px 6px rgba(0, 0, 0, 0.5), 0 2px 8px rgba(0, 0, 0, 0.4);
}

.chip-stack {
  display: flex;
  flex-direction: column-reverse;
  gap: 1px;
  align-items: center;
}

.chip {
  width: 18px;
  height: 4px;
  border-radius: 2px;
  border: 0.5px solid rgba(255, 255, 255, 0.2);
  box-shadow: 0 1px 1px rgba(0, 0, 0, 0.3);
}

.tray-label {
  font-size: 8px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.3);
  letter-spacing: 1.5px;
  text-transform: uppercase;
}
</style>
