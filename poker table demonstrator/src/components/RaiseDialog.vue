<script setup lang="ts">
import { ref, computed } from 'vue'
import { useGameStore } from '../stores/gameStore'

const store = useGameStore()

const inputAmount = ref('')

const player = computed(() =>
  store.players.find(p => p.id === store.raiseDialogPlayerId)
)

const isRaise = computed(() => store.currentBet > 0)

const minAmount = computed(() => {
  if (isRaise.value) {
    // Min raise = current bet + last raise increment
    return store.currentBet + store.lastRaiseIncrement
  }
  return store.bigBlind
})

const maxAmount = computed(() => {
  if (!player.value) return 0
  return player.value.chips + player.value.currentBet
})

function handleConfirm() {
  const amount = parseInt(inputAmount.value)
  if (!player.value || isNaN(amount) || amount < minAmount.value) return

  if (isRaise.value) {
    store.playerAction(player.value.id, 'raise', amount)
  } else {
    store.playerAction(player.value.id, 'bet', amount)
  }
  inputAmount.value = ''
}

function handleCancel() {
  store.closeRaiseDialog()
  inputAmount.value = ''
}

function handleKeydown(e: KeyboardEvent) {
  if (e.key === 'Enter') handleConfirm()
  if (e.key === 'Escape') handleCancel()
}
</script>

<template>
  <Teleport to="body">
    <div class="dialog-overlay" @click.self="handleCancel">
      <div class="raise-dialog" @keydown="handleKeydown">
        <div class="dialog-title">
          {{ isRaise ? 'Raise' : 'Bet' }} - {{ player?.name }}
        </div>
        <div class="dialog-info">
          <span>Min: ${{ minAmount }}</span>
          <span>Stack: ${{ player?.chips ?? 0 }}</span>
        </div>
        <input
          v-model="inputAmount"
          type="number"
          class="amount-input"
          :placeholder="`$${minAmount}`"
          :min="minAmount"
          :max="maxAmount"
          autofocus
        />
        <div class="dialog-actions">
          <button class="btn btn-cancel" @click="handleCancel">Cancel</button>
          <button class="btn btn-confirm" @click="handleConfirm">Confirm</button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.dialog-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 200;
}

.raise-dialog {
  background: linear-gradient(135deg, #2a2a3e, #1c1c2e);
  border: 2px solid #555;
  border-radius: 14px;
  padding: 20px 28px;
  min-width: 280px;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.7);
}

.dialog-title {
  font-size: 18px;
  font-weight: 700;
  color: #f1c40f;
  text-align: center;
  margin-bottom: 12px;
}

.dialog-info {
  display: flex;
  justify-content: space-between;
  font-size: 13px;
  color: #aaa;
  margin-bottom: 12px;
}

.amount-input {
  width: 100%;
  padding: 10px 14px;
  font-size: 18px;
  font-weight: 700;
  border: 2px solid #555;
  border-radius: 8px;
  background: #1a1a2e;
  color: #fff;
  text-align: center;
  outline: none;
  margin-bottom: 16px;
}

.amount-input:focus {
  border-color: #f1c40f;
}

/* Hide number input spinners */
.amount-input::-webkit-outer-spin-button,
.amount-input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

.dialog-actions {
  display: flex;
  gap: 10px;
}

.btn {
  flex: 1;
  padding: 10px;
  border: none;
  border-radius: 8px;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
  color: #fff;
}

.btn-cancel {
  background: #555;
}
.btn-cancel:hover {
  background: #777;
}

.btn-confirm {
  background: #27ae60;
}
.btn-confirm:hover {
  background: #2ecc71;
}
</style>
