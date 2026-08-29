import { RecordedSet, ExerciseType } from './models';

const STORAGE_KEY = 'formcoach_workout_history_v1';
const DB_NAME = 'formcoach_offline_db';
const DB_VERSION = 1;
const STORE_NAME = 'workout_sets';

export class LocalStorageManager {
  private static dbPromise: Promise<IDBDatabase | null> | null = null;

  private static getDB(): Promise<IDBDatabase | null> {
    if (typeof window === 'undefined' || !window.indexedDB) {
      return Promise.resolve(null);
    }
    if (!this.dbPromise) {
      this.dbPromise = new Promise(resolve => {
        try {
          const req = indexedDB.open(DB_NAME, DB_VERSION);
          req.onupgradeneeded = () => {
            const db = req.result;
            if (!db.objectStoreNames.contains(STORE_NAME)) {
              db.createObjectStore(STORE_NAME, { keyPath: 'id' });
            }
          };
          req.onsuccess = () => resolve(req.result);
          req.onerror = () => resolve(null);
        } catch {
          resolve(null);
        }
      });
    }
    return this.dbPromise;
  }

  public static getRecordedSets(): RecordedSet[] {
    try {
      const data = localStorage.getItem(STORAGE_KEY);
      if (!data) return [];
      return JSON.parse(data);
    } catch {
      return [];
    }
  }

  public static saveSet(set: RecordedSet): void {
    try {
      const sets = this.getRecordedSets();
      // Remove any existing set with same id, then prepend
      const filtered = sets.filter(s => s.id !== set.id);
      filtered.unshift(set);
      // Keep last 50 in localStorage for instant sync, full set in IndexedDB
      localStorage.setItem(STORAGE_KEY, JSON.stringify(filtered.slice(0, 50)));

      // Persist to IndexedDB asynchronously for unlimited storage
      this.getDB().then(db => {
        if (db) {
          try {
            const tx = db.transaction(STORE_NAME, 'readwrite');
            tx.objectStore(STORE_NAME).put(set);
          } catch (err) {
            console.warn('IndexedDB write error:', err);
          }
        }
      });
    } catch (e) {
      console.error('Failed to save workout set locally:', e);
    }
  }

  public static getSetsForExercise(exercise: ExerciseType): RecordedSet[] {
    return this.getRecordedSets().filter(s => s.exercise === exercise);
  }

  public static clearHistory(): void {
    localStorage.removeItem(STORAGE_KEY);
    this.getDB().then(db => {
      if (db) {
        try {
          const tx = db.transaction(STORE_NAME, 'readwrite');
          tx.objectStore(STORE_NAME).clear();
        } catch {}
      }
    });
  }
}
