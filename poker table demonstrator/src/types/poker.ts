export type Suit = 'hearts' | 'diamonds' | 'clubs' | 'spades'
export type Rank = '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' | '10' | 'J' | 'Q' | 'K' | 'A'
export type Street = 'pitch' | 'preflop' | 'flop' | 'turn' | 'river' | 'showdown'

export interface Card {
  suit: Suit
  rank: Rank
  id: string
  faceUp: boolean
}

export interface Player {
  id: number
  name: string
  chips: number
  holeCards: Card[]
  currentBet: number
  folded: boolean
  hasActed: boolean
}

export interface SeatPosition {
  x: number
  y: number
  angle: number
}

export interface PositionXY {
  x: number
  y: number
}

export interface LayoutConfig {
  seats: PositionXY[]
  cards: PositionXY[]
  stacks: PositionXY[]
  bets: PositionXY[]
  dealerButtons: PositionXY[]
  pot: PositionXY
  muck: PositionXY
  communityCards: PositionXY
  avatarScale?: number
}

export interface PitchState {
  cardsPitched: number
  playerCardCounts: number[]
  hasMispitch: boolean
  mispitchPosition: PositionXY | null
  expectedPlayerIndex: number  // next player who should receive a card (clockwise)
  currentRound: number         // 0 = first card to each, 1 = second card to each
  faceUpCards: { playerIndex: number; cardIndex: number; card: Card }[]  // track exposed cards
  totalFaceUp: number
  replacementPhase: boolean    // after 18 cards, need to replace a single exposed card
  replacementPlayerIndex: number | null  // which player needs replacement
  returningCard: { fromX: number; fromY: number; active: boolean } | null  // animating card back
}
