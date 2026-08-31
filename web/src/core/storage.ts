import { RecordedSet, ExerciseType } from './models';

const STORAGE_KEY = 'formcoach_workout_history_v1';
const DB_NAME = 'formcoach_offline_db';
const STORE_NAME = 'workout_sets';

// Object URLs belong to the current page, never to durable history.
function durableSet({ videoUrl: _videoUrl, ...set }: RecordedSet): RecordedSet {
  return set;
}

export class LocalStorageManager {
  private static dbPromise: Promise<IDBDatabase> | null = null;

  private static getDB(): Promise<IDBDatabase> {
    if (!this.dbPromise) {
      this.dbPromise = new Promise<IDBDatabase>((resolve, reject) => {
        const req = indexedDB.open(DB_NAME, 1);
        req.onupgradeneeded = () => {
          if (!req.result.objectStoreNames.contains(STORE_NAME)) {
            req.result.createObjectStore(STORE_NAME, { keyPath: 'id' });
          }
        };
        req.onsuccess = () => {
          req.result.onversionchange = () => {
            req.result.close();
            this.dbPromise = null;
          };
          resolve(req.result);
        };
        req.onerror = () => reject(req.error ?? new Error('Historikdatabasen kunne ikke åbnes.'));
        req.onblocked = () => reject(new Error('Luk andre FormCoach-faner og prøv igen.'));
      }).catch(error => {
        this.dbPromise = null;
        throw error;
      });
    }
    return this.dbPromise;
  }

  private static legacySets(): RecordedSet[] {
    const json = localStorage.getItem(STORAGE_KEY);
    if (!json) return [];
    const sets = JSON.parse(json);
    if (!Array.isArray(sets) || sets.some(s => !s || typeof s.id !== 'string' || !Array.isArray(s.reps))) {
      throw new Error('Eksisterende historik kunne ikke læses. Data er bevaret.');
    }
    return sets.map(durableSet);
  }

  public static async getRecordedSets(): Promise<RecordedSet[]> {
    return (await this.getHistory()).sets;
  }

  public static async getHistory(): Promise<{ sets: RecordedSet[]; complete: boolean }> {
    const legacy = this.legacySets();
    let db: IDBDatabase;
    try {
      db = await this.getDB();
    } catch {
      // The old cache may be only the last 50 sets. Never claim a complete
      // baseline when the archive is unavailable, and do not clear the cache.
      return { sets: legacy, complete: false };
    }
    // Migrate the old cache without overwriting newer durable records. Keep the
    // legacy copy until the transaction has committed successfully.
    const sets = await new Promise<RecordedSet[]>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      let merged: RecordedSet[] = [];
      const req = store.getAll();
      req.onsuccess = () => {
        const known = new Map<string, RecordedSet>(req.result.map((s: RecordedSet) => [s.id, durableSet(s)]));
        for (const set of legacy) {
          if (!known.has(set.id)) {
            store.put(set);
            known.set(set.id, set);
          }
        }
        merged = [...known.values()].sort((a, b) => b.date.localeCompare(a.date));
      };
      tx.oncomplete = () => resolve(merged);
      tx.onerror = tx.onabort = () => reject(tx.error ?? new Error('Historikken kunne ikke læses.'));
    });
    if (legacy.length > 0) {
      try { localStorage.removeItem(STORAGE_KEY); } catch { /* Durable transaction already committed. */ }
    }
    return { sets, complete: true };
  }

  public static async saveSet(set: RecordedSet): Promise<void> {
    const db = await this.getDB();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).put(durableSet(set));
      tx.oncomplete = () => resolve();
      tx.onerror = tx.onabort = () => reject(tx.error ?? new Error('Sættet kunne ikke gemmes.'));
    });
  }

  public static async getSetsForExercise(exercise: ExerciseType): Promise<RecordedSet[]> {
    return (await this.getRecordedSets()).filter(s => s.exercise === exercise);
  }

  public static async clearHistory(): Promise<void> {
    const db = await this.getDB();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).clear();
      tx.oncomplete = () => resolve();
      tx.onerror = tx.onabort = () => reject(tx.error ?? new Error('Historikken kunne ikke slettes.'));
    });
    localStorage.removeItem(STORAGE_KEY);
  }
}
