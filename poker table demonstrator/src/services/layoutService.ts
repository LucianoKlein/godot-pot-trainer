import { doc, getDoc, setDoc } from 'firebase/firestore'
import { db } from '@/firebase'
import type { LayoutConfig } from '@/types/poker'

const COLLECTION = 'layouts'
const DOC_ID = 'default'

export async function saveLayout(layout: LayoutConfig): Promise<void> {
  await setDoc(doc(db, COLLECTION, DOC_ID), layout)
}

export async function loadLayout(): Promise<LayoutConfig | null> {
  const snap = await getDoc(doc(db, COLLECTION, DOC_ID))
  if (snap.exists()) {
    return snap.data() as LayoutConfig
  }
  return null
}
