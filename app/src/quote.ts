/**
 * Розрахунок кошторису для проєкту автоматизації.
 * Усі суми — у центах (цілі числа), щоб уникнути похибок float.
 *
 * Це навчальний модуль-ціль для промптів з `prompts/`.
 * Він НАВМИСНЕ недосконалий — саме це ви і знайдете добре сформульованим
 * промптом з acceptance criteria (Task A).
 */

export interface QuoteInput {
  /** Оцінка робіт у годинах */
  hours: number;
  /** Ставка за годину, у центах (напр. 5000 = $50.00) */
  rateCents: number;
  /** Знижка у відсотках, 0..100 */
  discountPercent?: number;
}

/**
 * Ціна проєкту в центах з урахуванням знижки.
 * Кидає `RangeError`, якщо `hours`/`rateCents` не є скінченними числами
 * або якщо `discountPercent` виходить за документовані межі `0..100` —
 * інакше помилка вводу тихо перетворюється на від'ємний або завищений рахунок.
 */
export function estimateTotalCents(input: QuoteInput): number {
  const { hours, rateCents, discountPercent = 0 } = input;
  if (!Number.isFinite(hours) || !Number.isFinite(rateCents)) {
    throw new RangeError(`hours and rateCents must be finite, got ${hours} and ${rateCents}`);
  }
  if (!Number.isFinite(discountPercent) || discountPercent < 0 || discountPercent > 100) {
    throw new RangeError(`discountPercent must be within 0..100, got ${discountPercent}`);
  }
  const gross = hours * rateCents;
  const discount = (gross * discountPercent) / 100;
  return Math.round(gross - discount);
}

/**
 * Розбити суму на `parts` платежів (у центах).
 * Повертає масив довжиною `parts`, сума якого ТОЧНО дорівнює `totalCents`:
 * залишок від ділення розкидається по одному центу на перші платежі, тож
 * платежі відрізняються не більше ніж на 1 цент.
 */
export function splitInstallments(totalCents: number, parts: number): number[] {
  if (!Number.isInteger(parts) || parts < 1) {
    throw new RangeError(`parts must be a positive integer, got ${parts}`);
  }
  if (!Number.isInteger(totalCents)) {
    throw new RangeError(`totalCents must be an integer number of cents, got ${totalCents}`);
  }
  const base = Math.trunc(totalCents / parts);
  const remainder = totalCents - base * parts;
  const step = remainder < 0 ? -1 : 1;
  const extra = Math.abs(remainder);
  return Array.from({ length: parts }, (_, i) => (i < extra ? base + step : base));
}

/**
 * Форматування центів у рядок на кшталт "$1,234.50".
 * Кидає `RangeError` для нескінченних значень і `NaN`; дробові центи
 * округлюються до найближчого цента, щоб рядок завжди мав рівно одну крапку.
 */
export function formatMoney(cents: number): string {
  if (!Number.isFinite(cents)) {
    throw new RangeError(`cents must be a finite number, got ${cents}`);
  }
  const sign = cents < 0 ? "-" : "";
  const abs = Math.round(Math.abs(cents));
  const whole = Math.floor(abs / 100).toLocaleString("en-US");
  const frac = String(abs % 100).padStart(2, "0");
  return `${sign}$${whole}.${frac}`;
}
