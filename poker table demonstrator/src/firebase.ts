import { initializeApp } from 'firebase/app'
import { getFirestore } from 'firebase/firestore'

const firebaseConfig = {
  apiKey: 'AIzaSyBcP_UiGT7IPLmDY5ZYsRhFpbp3KqE5JvE',
  authDomain: 'reg-action-teacher.firebaseapp.com',
  projectId: 'reg-action-teacher',
  storageBucket: 'reg-action-teacher.firebasestorage.app',
  messagingSenderId: '718134753203',
  appId: '1:718134753203:web:70677e4f5409c9034e7dc6',
}

const app = initializeApp(firebaseConfig)
export const db = getFirestore(app)
