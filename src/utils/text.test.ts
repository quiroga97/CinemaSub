import { describe, expect, it } from 'vitest';
import { formatDelay, isSignificantChange, normalizeForCompare, splitTwoLines } from './text';

describe('normalizeForCompare', () => {
  it('ignora caso, espacios y puntuación', () => {
    expect(normalizeForCompare('  We   have to go. ')).toBe(normalizeForCompare('we have to go'));
  });
});

describe('isSignificantChange', () => {
  it('cambios de puntuación/espacios no son significativos', () => {
    expect(isSignificantChange('Tenemos que irnos', 'Tenemos que irnos.')).toBe(false);
    expect(isSignificantChange('No abras esa puerta', 'no abras esa puerta!')).toBe(false);
  });

  it('cambios de palabras sí son significativos', () => {
    expect(isSignificantChange('Nosotros', 'Nosotros tenemos')).toBe(true);
    expect(isSignificantChange('Open the door', 'Open that door')).toBe(true);
  });
});

describe('splitTwoLines', () => {
  it('devuelve una línea si cabe', () => {
    expect(splitTwoLines('No abras esa puerta', 40)).toEqual(['No abras esa puerta']);
  });

  it('nunca devuelve más de 2 líneas', () => {
    const result = splitTwoLines(
      'Tenemos que irnos ahora mismo antes de que sea demasiado tarde para todos',
      24,
    );
    expect(result.length).toBeLessThanOrEqual(2);
  });

  it('equilibra las dos líneas cuando hay corte válido', () => {
    const [a, b] = splitTwoLines('tenemos que irnos ahora', 12);
    expect(a).toBe('tenemos que');
    expect(b).toBe('irnos ahora');
  });

  it('si no hay corte válido, llena la primera línea hasta el límite', () => {
    const [a, b] = splitTwoLines('one two three four five six seven', 12);
    expect(a).toBe('one two');
    expect(b).toBe('three four five six seven');
  });
});

describe('formatDelay', () => {
  it('formatea segundos con signo y coma decimal', () => {
    expect(formatDelay(0)).toBe('0 s');
    expect(formatDelay(500)).toBe('+0,5 s');
    expect(formatDelay(-1500)).toBe('−1,5 s');
    expect(formatDelay(4000)).toBe('+4 s');
  });
});
