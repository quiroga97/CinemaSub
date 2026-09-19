/**
 * Utilidades puras de texto para subtítulos. Testeables sin nativo.
 */

/** Normaliza para comparar si dos textos son "significativamente" distintos. */
export function normalizeForCompare(text: string): string {
  return text
    .toLowerCase()
    .replace(/[\s\u00A0]+/g, ' ')
    .replace(/[.,!?;:¡¿"'\u201C\u201D]/g, '')
    .trim();
}

/**
 * ¿Merece la pena sustituir el subtítulo rápido por el final?
 * Tras normalizar (sin puntuación/espacios/caso), cualquier diferencia real
 * es un cambio de palabras y merece re-pintar; las diferencias de
 * puntuación pura ya se eliminan al normalizar.
 */
export function isSignificantChange(previous: string, next: string): boolean {
  return normalizeForCompare(previous) !== normalizeForCompare(next);
}

/**
 * Parte un texto en (como mucho) 2 líneas equilibradas por palabras.
 * Devuelve 1 línea si cabe; nunca más de 2.
 */
export function splitTwoLines(text: string, maxCharsPerLine: number): [string] | [string, string] {
  const clean = text.replace(/\s+/g, ' ').trim();
  if (clean.length <= maxCharsPerLine) return [clean];

  const words = clean.split(' ');

  // corte equilibrado que respete el límite en ambas líneas
  let best: [string, string] | null = null;
  let bestScore = Number.POSITIVE_INFINITY;
  for (let i = 1; i < words.length; i += 1) {
    const l1 = words.slice(0, i).join(' ');
    const l2 = words.slice(i).join(' ');
    if (l1.length > maxCharsPerLine || l2.length > maxCharsPerLine) continue;
    const score = Math.abs(l1.length - l2.length);
    if (score < bestScore) {
      bestScore = score;
      best = [l1, l2];
    }
  }
  if (best !== null) return best;

  // sin corte que cumpla el límite: primera línea con lo máximo que quepa,
  // el resto en la segunda (la UI lo trunca si aún excede).
  let fitCount = 0;
  let length = 0;
  for (let i = 0; i < words.length; i += 1) {
    const candidate = length === 0 ? words[i].length : length + 1 + words[i].length;
    if (candidate > maxCharsPerLine) break;
    length = candidate;
    fitCount = i + 1;
  }
  if (fitCount > 0 && fitCount < words.length) {
    return [words.slice(0, fitCount).join(' '), words.slice(fitCount).join(' ')];
  }
  return [clean];
}

/** Formatea el retardo para el indicador discreto: "+0,5 s". */
export function formatDelay(ms: number): string {
  if (ms === 0) return '0 s';
  const seconds = ms / 1000;
  const sign = seconds > 0 ? '+' : '−';
  const abs = Math.abs(seconds);
  const text = Number.isInteger(abs) ? String(abs) : abs.toFixed(1).replace('.', ',');
  return `${sign}${text} s`;
}
