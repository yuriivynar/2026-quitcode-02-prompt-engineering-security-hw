/**
 * Розрахунок кошторису для проєкту автоматизації.
 * Усі суми — у центах (цілі числа), щоб уникнути похибок float.
 *
 * Це навчальний модуль-ціль для промптів з `prompts/`.
 * Він НАВМИСНЕ недосконалий — саме це ви і знайдете добре сформульованим
 * промптом з acceptance criteria (Task A).
 */

/**
 * Документована межа бізнес-логіки: план розстрочки не може мати більше
 * платежів, ніж 10 років щомісячних внесків. Без цієї межі `splitInstallments`
 * прийняв би, напр., `4_294_967_295` і спробував би виділити масив на мільярди
 * елементів — процес завис би або вичерпав пам’ять.
 */
export const MAX_INSTALLMENTS = 120;

export interface QuoteInput {
  /** Оцінка робіт у годинах */
  hours: number;
  /** Ставка за годину, у центах (напр. 5000 = $50.00) */
  rateCents: number;
  /** Знижка у відсотках, 0..100 */
  discountPercent?: number;
}

/**
 * Ціна проєкту в центах з урахуванням знижки. Повертає ЦІЛЕ число центів.
 * Кидає `RangeError`, якщо `hours`/`rateCents` не є скінченними числами,
 * якщо `discountPercent` виходить за документовані межі `0..100`, або якщо
 * сам результат не є безпечним цілим (`Number.isSafeInteger`) — скінченні
 * входи ще можуть переповнитись у проміжному добутку і дати `Infinity`/`NaN`,
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
  const totalCents = Math.round(gross - discount);
  if (!Number.isSafeInteger(totalCents)) {
    throw new RangeError(`total must be a safe integer number of cents, got ${totalCents}`);
  }
  return totalCents;
}

/**
 * Розбити суму на `parts` платежів (у центах).
 * Кидає `RangeError`, якщо `parts` не є цілим числом у межах
 * `1..MAX_INSTALLMENTS` або якщо `totalCents` не є цілим числом центів.
 * Повертає масив довжиною `parts`, сума якого ТОЧНО дорівнює `totalCents`:
 * залишок від ділення розкидається по одному центу на перші платежі, тож
 * платежі відрізняються не більше ніж на 1 цент.
 */
export function splitInstallments(totalCents: number, parts: number): number[] {
  if (!Number.isInteger(parts) || parts < 1 || parts > MAX_INSTALLMENTS) {
    throw new RangeError(
      `parts must be a positive integer within 1..${MAX_INSTALLMENTS}, got ${parts}`,
    );
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
