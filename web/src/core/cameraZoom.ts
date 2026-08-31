export interface ZoomTrack {
  getCapabilities(): MediaTrackCapabilities & { zoom?: { min: number; max: number } };
  getSettings(): MediaTrackSettings & { zoom?: number };
  applyConstraints(constraints: MediaTrackConstraints): Promise<void>;
}

export function readZoom(track: ZoomTrack): { levels: number[]; current: number | null } {
  const range = track.getCapabilities().zoom;
  const actual = track.getSettings().zoom;
  if (!range || !Number.isFinite(actual)) return { levels: [], current: null };
  return { levels: [0.5, 1, 2].filter(n => n >= range.min && n <= range.max), current: actual! };
}

export async function applyZoom(track: ZoomTrack, level: number): Promise<number | null> {
  if (!readZoom(track).levels.includes(level)) throw new Error('Zoomniveau understøttes ikke.');
  await track.applyConstraints({ advanced: [{ zoom: level } as MediaTrackConstraintSet] });
  return readZoom(track).current;
}
