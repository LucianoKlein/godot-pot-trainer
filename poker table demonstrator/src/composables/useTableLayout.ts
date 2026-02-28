import { computed } from 'vue'
import { useGameStore } from '@/stores/gameStore'
import type { PositionXY } from '@/types/poker'

export function useTableLayout() {
  const store = useGameStore()

  const seatPositions = computed(() => store.layoutConfig.seats)
  const cardPositions = computed(() => store.layoutConfig.cards)
  const stackPositions = computed(() => store.layoutConfig.stacks)
  const betPositions = computed(() => store.layoutConfig.bets)
  const dealerButtonPositions = computed(() => store.layoutConfig.dealerButtons)
  const potPosition = computed(() => store.layoutConfig.pot)
  const muckPosition = computed(() => store.layoutConfig.muck)
  const communityCardsPosition = computed(() => store.layoutConfig.communityCards)
  const avatarScale = computed(() => store.layoutConfig.avatarScale ?? 1)

  const dealerButtonPosition = computed(() => {
    return (dealerIndex: number): PositionXY => {
      return dealerButtonPositions.value[dealerIndex] ?? { x: 50, y: 50 }
    }
  })

  return {
    seatPositions,
    cardPositions,
    stackPositions,
    betPositions,
    dealerButtonPositions,
    dealerButtonPosition,
    potPosition,
    muckPosition,
    communityCardsPosition,
    avatarScale,
  }
}
