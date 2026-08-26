import { RecordedSet, ExerciseType } from './models';

const STORAGE_KEY = 'formcoach_workout_history_v1';

export class LocalStorageManager {
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
      sets.unshift(set); // newest first
      localStorage.setItem(STORAGE_KEY, JSON.stringify(sets));
    } catch (e) {
      console.error('Failed to save workout set locally:', e);
    }
  }

  public static getSetsForExercise(exercise: ExerciseType): RecordedSet[] {
    return this.getRecordedSets().filter(s => s.exercise === exercise);
  }

  public static clearHistory(): void {
    localStorage.removeItem(STORAGE_KEY);
  }
}
