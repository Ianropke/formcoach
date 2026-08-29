/**
 * AudioCoachService — Zero-latency Web Audio sound synthesizer
 * and Danish voice cues via Web Speech API for AirPods / gym headphones.
 */
export class AudioCoachService {
  private static instance: AudioCoachService | null = null;
  private audioCtx: AudioContext | null = null;
  private isMuted = false;
  private isVoiceEnabled = true;
  private lastSpokenText = "";
  private lastSpokenTime = 0;

  public static getInstance(): AudioCoachService {
    if (!AudioCoachService.instance) {
      AudioCoachService.instance = new AudioCoachService();
    }
    return AudioCoachService.instance;
  }

  /**
   * Unlocks AudioContext on user gesture (required by iOS Safari)
   */
  public unlockAudio(): void {
    try {
      if (!this.audioCtx) {
        const AudioCtxClass = window.AudioContext || (window as any).webkitAudioContext;
        if (AudioCtxClass) {
          this.audioCtx = new AudioCtxClass();
        }
      }
      if (this.audioCtx && this.audioCtx.state === "suspended") {
        this.audioCtx.resume();
      }
    } catch (e) {
      console.warn("AudioContext initialization bypassed:", e);
    }
  }

  public setMuted(muted: boolean): void {
    this.isMuted = muted;
    if (muted && "speechSynthesis" in window) {
      window.speechSynthesis.cancel();
    }
  }

  public getIsMuted(): boolean {
    return this.isMuted;
  }

  public setVoiceEnabled(enabled: boolean): void {
    this.isVoiceEnabled = enabled;
  }

  /**
   * Play high-pitched double-chime (880Hz -> 1320Hz) when approved depth / ROM peak is hit
   */
  public playDepthMilestone(): void {
    if (this.isMuted) return;
    this.unlockAudio();
    if (!this.audioCtx) return;

    try {
      const now = this.audioCtx.currentTime;
      const osc = this.audioCtx.createOscillator();
      const gain = this.audioCtx.createGain();

      osc.type = "sine";
      osc.frequency.setValueAtTime(880, now);
      osc.frequency.exponentialRampToValueAtTime(1320, now + 0.08);

      gain.gain.setValueAtTime(0.18, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.16);

      osc.connect(gain);
      gain.connect(this.audioCtx.destination);

      osc.start(now);
      osc.stop(now + 0.16);
    } catch (e) {
      console.warn("Depth milestone audio chime failed:", e);
    }
  }

  /**
   * Play short low-frequency warning tone (320Hz) when form fault (e.g. shoulder swing) is detected
   */
  public playFormWarning(): void {
    if (this.isMuted) return;
    this.unlockAudio();
    if (!this.audioCtx) return;

    try {
      const now = this.audioCtx.currentTime;
      const osc = this.audioCtx.createOscillator();
      const gain = this.audioCtx.createGain();

      osc.type = "triangle";
      osc.frequency.setValueAtTime(320, now);
      osc.frequency.setValueAtTime(240, now + 0.1);

      gain.gain.setValueAtTime(0.2, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.22);

      osc.connect(gain);
      gain.connect(this.audioCtx.destination);

      osc.start(now);
      osc.stop(now + 0.22);
    } catch (e) {
      console.warn("Warning tone audio failed:", e);
    }
  }

  /**
   * Play countdown beep (440Hz standard beep, 880Hz final "GO" tone)
   */
  public playCountdownBeep(isFinal = false): void {
    if (this.isMuted) return;
    this.unlockAudio();
    if (!this.audioCtx) return;

    try {
      const now = this.audioCtx.currentTime;
      const osc = this.audioCtx.createOscillator();
      const gain = this.audioCtx.createGain();

      osc.type = "sine";
      osc.frequency.setValueAtTime(isFinal ? 880 : 440, now);

      gain.gain.setValueAtTime(0.15, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + (isFinal ? 0.35 : 0.15));

      osc.connect(gain);
      gain.connect(this.audioCtx.destination);

      osc.start(now);
      osc.stop(now + (isFinal ? 0.35 : 0.15));
    } catch (e) {
      console.warn("Countdown audio beep failed:", e);
    }
  }

  /**
   * Speaks Danish coach phrases (e.g. rep counts, form cues) via Web Speech API
   */
  public speak(text: string, priority = false): void {
    if (this.isMuted || !this.isVoiceEnabled) return;
    if (!("speechSynthesis" in window)) return;

    const now = Date.now();
    // Throttle duplicate phrases within 2.5s unless marked priority
    if (!priority && text === this.lastSpokenText && now - this.lastSpokenTime < 2500) {
      return;
    }

    try {
      if (priority) {
        window.speechSynthesis.cancel();
      }

      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = "da-DK";
      utterance.rate = 1.15; // Crisp, sporty tempo
      utterance.pitch = 1.0;
      utterance.volume = 0.9;

      this.lastSpokenText = text;
      this.lastSpokenTime = now;

      window.speechSynthesis.speak(utterance);
    } catch (e) {
      console.warn("Speech synthesis utterance bypassed:", e);
    }
  }
}
