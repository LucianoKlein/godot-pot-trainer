<script setup lang="ts">
import type { Player, PositionXY } from '../types/poker'

// Each player uses ONE color for both hair and shirt, all 9 distinct
const PLAYER_COLORS = [
  '#e74c3c',  // Red
  '#2980b9',  // Blue
  '#27ae60',  // Green
  '#8e44ad',  // Purple
  '#e67e22',  // Orange
  '#16a085',  // Teal
  '#d4a017',  // Gold
  '#c0392b',  // Crimson
  '#3498db',  // Sky blue
]

defineProps<{
  player: Player
  position: PositionXY
  isCurrent: boolean
  avatarScale: number
  showActionIndicator: boolean
  isAggressor: boolean
}>()

const emit = defineEmits<{
  click: []
}>()
</script>

<template>
  <div
    class="player-seat"
    :class="{
      'is-current': isCurrent,
      'is-folded': player.folded,
    }"
    :style="{
      left: position.x + '%',
      top: position.y + '%',
    }"
    @click.stop="emit('click')"
  >
    <!-- Avatar -->
    <div class="avatar-wrapper" :style="{ width: (56 * avatarScale) + 'px', height: (50 * avatarScale) + 'px' }">
      <svg class="avatar" viewBox="0 0 60 55" xmlns="http://www.w3.org/2000/svg">
        <!-- Hair -->
        <ellipse cx="30" cy="10" rx="13" ry="10"
          :fill="PLAYER_COLORS[(player.id - 1) % PLAYER_COLORS.length]"/>
        <!-- Head -->
        <circle cx="30" cy="15" r="10" fill="#f0c987" stroke="#d4a85c" stroke-width="1"/>
        <!-- Eyes -->
        <ellipse cx="26" cy="13" rx="1.8" ry="2.2" fill="#333"/>
        <ellipse cx="34" cy="13" rx="1.8" ry="2.2" fill="#333"/>
        <!-- Eye highlights -->
        <circle cx="26.8" cy="12.2" r="0.7" fill="#fff"/>
        <circle cx="34.8" cy="12.2" r="0.7" fill="#fff"/>
        <!-- Nose -->
        <ellipse cx="30" cy="16.5" rx="1.2" ry="0.8" fill="#dbb07a"/>
        <!-- Mouth -->
        <path d="M26 20 Q30 23.5 34 20" stroke="#b5651d" stroke-width="1" fill="none" stroke-linecap="round"/>
        <!-- Ears -->
        <ellipse cx="19.5" cy="15" rx="2" ry="3" fill="#f0c987" stroke="#d4a85c" stroke-width="0.5"/>
        <ellipse cx="40.5" cy="15" rx="2" ry="3" fill="#f0c987" stroke="#d4a85c" stroke-width="0.5"/>
        <!-- Collar -->
        <path d="M23 25 L30 29 L37 25" stroke="#fff" stroke-width="1.5" fill="none" stroke-linecap="round"/>
        <!-- Body / Shirt -->
        <path d="M20 26 Q20 24 24 24 L36 24 Q40 24 40 26 L42 48 Q42 50 40 50 L20 50 Q18 50 18 48 Z"
          :fill="PLAYER_COLORS[(player.id - 1) % PLAYER_COLORS.length]"
          stroke-width="0.5" stroke="#333" opacity="0.95"/>
        <!-- Arms -->
        <path d="M20 28 L10 38" stroke="#f0c987" stroke-width="3.5" stroke-linecap="round"/>
        <path d="M40 28 L50 38" stroke="#f0c987" stroke-width="3.5" stroke-linecap="round"/>
      </svg>

      <!-- Seat number badge -->
      <div class="seat-number">#{{ player.id }}</div>
    </div>

    <!-- Player name -->
    <div class="player-name-tag">{{ player.name }}</div>

    <!-- Action indicator arrow -->
    <div v-if="showActionIndicator && isCurrent && !player.folded" class="action-indicator">
      <div class="action-text">Action</div>
      <div class="action-arrow">&#9660;</div>
    </div>

    <!-- Aggressor indicator arrow -->
    <div v-if="isAggressor && !player.folded" class="aggressor-indicator">
      <div class="aggressor-text">Aggressor</div>
      <div class="aggressor-arrow">&#9660;</div>
    </div>

    <!-- Folded overlay -->
    <div v-if="player.folded" class="folded-label">FOLD</div>
  </div>
</template>

<style scoped>
.player-seat {
  position: absolute;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1px;
  cursor: pointer;
  z-index: 10;
  transition: filter 0.2s, transform 0.2s;
  user-select: none;
}

.player-seat:hover:not(.is-folded) {
  filter: brightness(1.25) drop-shadow(0 0 10px rgba(255, 255, 255, 0.5));
  transform: translate(-50%, -50%) scale(1.08);
  z-index: 20;
}

.player-seat.is-current {
  filter: drop-shadow(0 0 14px rgba(255, 215, 0, 0.9));
}

.player-seat.is-folded {
  opacity: 0.35;
  cursor: default;
}

.avatar-wrapper {
  position: relative;
}

.avatar {
  width: 100%;
  height: 100%;
}

.is-current .avatar-wrapper {
  filter: drop-shadow(0 0 8px rgba(241, 196, 15, 0.6));
}

.seat-number {
  position: absolute;
  top: -4px;
  right: -4px;
  background: #e67e22;
  color: #fff;
  font-size: 9px;
  font-weight: 800;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1.5px solid #fff;
  z-index: 3;
}

.player-name-tag {
  background: rgba(0, 0, 0, 0.65);
  color: #eee;
  font-size: 10px;
  font-weight: 600;
  padding: 1px 8px;
  border-radius: 4px;
  white-space: nowrap;
}

.folded-label {
  position: absolute;
  top: 40%;
  left: 50%;
  transform: translate(-50%, -50%);
  font-size: 14px;
  font-weight: 800;
  color: #e74c3c;
  text-shadow: 0 1px 4px rgba(0, 0, 0, 0.8);
  pointer-events: none;
}

.action-indicator {
  position: absolute;
  bottom: 100%;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  pointer-events: none;
  animation: action-bounce 1s ease-in-out infinite;
}

.action-text {
  background: #e74c3c;
  color: #fff;
  font-size: 11px;
  font-weight: 800;
  padding: 2px 10px;
  border-radius: 6px;
  white-space: nowrap;
  box-shadow: 0 2px 8px rgba(231, 76, 60, 0.5);
}

.action-arrow {
  color: #e74c3c;
  font-size: 16px;
  line-height: 1;
  margin-top: -3px;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.4);
}

@keyframes action-bounce {
  0%, 100% { transform: translateX(-50%) translateY(0); }
  50% { transform: translateX(-50%) translateY(-6px); }
}

.aggressor-indicator {
  position: absolute;
  bottom: 100%;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  pointer-events: none;
  margin-bottom: 28px;
}

.aggressor-text {
  background: #e67e22;
  color: #fff;
  font-size: 11px;
  font-weight: 800;
  padding: 2px 10px;
  border-radius: 6px;
  white-space: nowrap;
  box-shadow: 0 2px 8px rgba(230, 126, 34, 0.5);
}

.aggressor-arrow {
  color: #e67e22;
  font-size: 16px;
  line-height: 1;
  margin-top: -3px;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.4);
}
</style>
