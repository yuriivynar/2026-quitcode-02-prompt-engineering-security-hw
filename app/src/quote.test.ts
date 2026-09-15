import { describe, expect, it } from "vitest";
import {
  MAX_INSTALLMENTS,
  estimateTotalCents,
  formatMoney,
  splitInstallments,
} from "./quote.js";

describe("estimateTotalCents", () => {
  it("рахує суму без знижки", () => {
    expect(estimateTotalCents({ hours: 10, rateCents: 5000 })).toBe(50000);
  });

  it("застосовує знижку", () => {
    expect(estimateTotalCents({ hours: 10, rateCents: 5000, discountPercent: 10 })).toBe(45000);
  });

  it("нуль годин — нуль вартості", () => {
    expect(estimateTotalCents({ hours: 0, rateCents: 5000 })).toBe(0);
  });

  it("знижка 100% обнуляє суму", () => {
    expect(estimateTotalCents({ hours: 10, rateCents: 5000, discountPercent: 100 })).toBe(0);
  });

  it("явний discountPercent: 0 дорівнює відсутності знижки", () => {
    expect(estimateTotalCents({ hours: 3, rateCents: 7500, discountPercent: 0 })).toBe(
      estimateTotalCents({ hours: 3, rateCents: 7500 }),
    );
  });

  it("дробові години дають цілі центи", () => {
    const total = estimateTotalCents({ hours: 2.5, rateCents: 5000 });
    expect(total).toBe(12500);
    expect(Number.isInteger(total)).toBe(true);
  });

  it("округлює залишок центів, а не відкидає його", () => {
    // gross = 333, знижка 10% = 33.3, 333 - 33.3 = 299.7 -> 300
    expect(estimateTotalCents({ hours: 1, rateCents: 333, discountPercent: 10 })).toBe(300);
  });

  it("завжди повертає ціле число центів", () => {
    const cases = [
      { hours: 7, rateCents: 3333, discountPercent: 17 },
      { hours: 1.25, rateCents: 999, discountPercent: 3 },
      { hours: 40, rateCents: 12345, discountPercent: 33 },
    ];
    for (const input of cases) {
      expect(Number.isInteger(estimateTotalCents(input))).toBe(true);
    }
  });
});

describe("splitInstallments", () => {
  it("ділить суму, що ділиться націло", () => {
    expect(splitInstallments(90000, 3)).toEqual([30000, 30000, 30000]);
  });

  it("один платіж — це вся сума", () => {
    expect(splitInstallments(12345, 1)).toEqual([12345]);
  });

  it("не втрачає центи, коли сума не ділиться націло", () => {
    expect(splitInstallments(100, 3)).toEqual([34, 33, 33]);
  });

  it("не створює зайвих центів при округленні вгору", () => {
    // 100 / 6 = 16.67 -> наївний Math.round дав би 6 x 17 = 102 (клієнт переплачує 2 центи)
    expect(splitInstallments(100, 6)).toEqual([17, 17, 17, 17, 16, 16]);
  });

  it("сума платежів завжди дорівнює загальній сумі", () => {
    const cases: Array<[number, number]> = [
      [100, 3],
      [100, 6],
      [1, 4],
      [0, 5],
      [99999, 7],
      [45000, 12],
      [-100, 3],
    ];
    for (const [total, parts] of cases) {
      const installments = splitInstallments(total, parts);
      expect(installments).toHaveLength(parts);
      expect(installments.reduce((a, b) => a + b, 0)).toBe(total);
    }
  });

  it("платежі відрізняються не більше ніж на 1 цент", () => {
    const installments = splitInstallments(1000, 7);
    expect(Math.max(...installments) - Math.min(...installments)).toBeLessThanOrEqual(1);
  });

  it("усі платежі — цілі центи", () => {
    for (const cents of splitInstallments(1000, 7)) {
      expect(Number.isInteger(cents)).toBe(true);
    }
  });

  it("від'ємна сума (повернення) ділиться так само коректно", () => {
    expect(splitInstallments(-100, 3)).toEqual([-34, -33, -33]);
  });

  it("відхиляє некоректну кількість платежів", () => {
    expect(() => splitInstallments(100, 0)).toThrow(RangeError);
    expect(() => splitInstallments(100, -3)).toThrow(RangeError);
    expect(() => splitInstallments(100, 2.5)).toThrow(RangeError);
  });
});

describe("formatMoney", () => {
  it("форматує центи", () => {
    expect(formatMoney(123450)).toBe("$1,234.50");
  });

  it("форматує нуль", () => {
    expect(formatMoney(0)).toBe("$0.00");
  });

  it("додає провідний нуль для сум менше долара", () => {
    expect(formatMoney(5)).toBe("$0.05");
    expect(formatMoney(50)).toBe("$0.50");
  });

  it("ставить знак мінус перед символом валюти", () => {
    expect(formatMoney(-123450)).toBe("-$1,234.50");
    expect(formatMoney(-5)).toBe("-$0.05");
  });

  it("групує тисячі комами", () => {
    expect(formatMoney(123456789)).toBe("$1,234,567.89");
  });
});

describe("estimateTotalCents — межі контракту", () => {
  it("приймає межові знижки 0 і 100", () => {
    expect(estimateTotalCents({ hours: 2, rateCents: 1000, discountPercent: 0 })).toBe(2000);
    expect(estimateTotalCents({ hours: 2, rateCents: 1000, discountPercent: 100 })).toBe(0);
  });

  it("відхиляє знижку поза документованими межами 0..100", () => {
    // без перевірки 150% давало -25000 (від'ємний рахунок), а -50% — надбавку
    for (const discountPercent of [150, 100.5, -10, -0.5, Number.NaN]) {
      expect(() => estimateTotalCents({ hours: 10, rateCents: 5000, discountPercent })).toThrow(RangeError);
    }
  });

  it("відхиляє нескінченні або NaN години й ставку замість тихого NaN", () => {
    const cases = [
      { hours: Number.NaN, rateCents: 5000 },
      { hours: Number.POSITIVE_INFINITY, rateCents: 5000 },
      { hours: 10, rateCents: Number.NaN },
      { hours: 10, rateCents: Number.NEGATIVE_INFINITY },
    ];
    for (const input of cases) {
      expect(() => estimateTotalCents(input)).toThrow(RangeError);
    }
  });

  it("не мутує вхідний об'єкт і не дописує знижку за замовчуванням", () => {
    const input = { hours: 3, rateCents: 7500 };
    estimateTotalCents(input);
    expect(input).toEqual({ hours: 3, rateCents: 7500 });
    expect("discountPercent" in input).toBe(false);
  });
});

describe("splitInstallments — межі контракту", () => {
  it("відхиляє дробову суму, яка ламала інваріант точної суми", () => {
    // без перевірки 100.5 на 3 частини давало [34, 34, 33] — сума 101
    for (const total of [100.5, 0.1, -99.9]) {
      expect(() => splitInstallments(total, 3)).toThrow(RangeError);
    }
  });

  it("відхиляє NaN та нескінченну суму", () => {
    for (const total of [Number.NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY]) {
      expect(() => splitInstallments(total, 3)).toThrow(RangeError);
    }
  });

  it("найбільше безпечне ціле в одній частині лишається незмінним", () => {
    expect(splitInstallments(Number.MAX_SAFE_INTEGER, 1)).toEqual([Number.MAX_SAFE_INTEGER]);
  });
});

describe("formatMoney — межі контракту", () => {
  it("округлює дробові центи, тож у рядку завжди одна крапка", () => {
    // без округлення 0.5 давало "$0.0.5", а 1234.5 — "$12.34.5"
    expect(formatMoney(0.5)).toBe("$0.01");
    expect(formatMoney(0.4)).toBe("$0.00");
    expect(formatMoney(1234.5)).toBe("$12.35");
    expect(formatMoney(-0.5)).toBe("-$0.01");
  });

  it("переносить округлення в долари, а не лише в центи", () => {
    // виправлення лише дробової частини дало б "$0.100"
    expect(formatMoney(99.6)).toBe("$1.00");
  });

  it("відхиляє NaN і нескінченність замість рядка $NaN.NaN", () => {
    for (const cents of [Number.NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY]) {
      expect(() => formatMoney(cents)).toThrow(RangeError);
    }
  });
});

describe("композиція estimate → split → format", () => {
  it("платежі сумуються назад до кошторису і форматуються коректно", () => {
    // 7 год × $125.00 = 87500; знижка 15% → 74375; 74375 / 3 = 24791 залишок 2
    const total = estimateTotalCents({ hours: 7, rateCents: 12500, discountPercent: 15 });
    expect(total).toBe(74375);
    const parts = splitInstallments(total, 3);
    expect(parts).toEqual([24792, 24792, 24791]);
    expect(parts.reduce((a, b) => a + b, 0)).toBe(total);
    expect(parts.map(formatMoney)).toEqual(["$247.92", "$247.92", "$247.91"]);
  });
});

describe("переповнення й межі розміру", () => {
  it("відхиляє переповнення у проміжному добутку замість тихого NaN", () => {
    // MAX_VALUE × 2 = Infinity; зі знижкою 100 це Infinity - Infinity = NaN.
    expect(() =>
      estimateTotalCents({ hours: Number.MAX_VALUE, rateCents: 2, discountPercent: 100 }),
    ).toThrow(RangeError);
    // Без знижки той самий добуток дає Infinity — теж не безпечне ціле.
    expect(() => estimateTotalCents({ hours: Number.MAX_VALUE, rateCents: 2 })).toThrow(RangeError);
  });

  it("відхиляє суму поза межами безпечного цілого", () => {
    expect(() => estimateTotalCents({ hours: 1e9, rateCents: 1e9 })).toThrow(RangeError);
  });

  it("приймає найбільшу суму, яка ще є безпечним цілим", () => {
    expect(estimateTotalCents({ hours: Number.MAX_SAFE_INTEGER, rateCents: 1 })).toBe(
      Number.MAX_SAFE_INTEGER,
    );
  });

  it("відхиляє кількість платежів понад документовану межу до виділення масиву", () => {
    expect(() => splitInstallments(100000, MAX_INSTALLMENTS + 1)).toThrow(RangeError);
    // Значення, яке проходило перевірку "додатне ціле" і вичерпувало пам'ять.
    expect(() => splitInstallments(100000, 4_294_967_295)).toThrow(RangeError);
  });

  it("приймає рівно MAX_INSTALLMENTS платежів", () => {
    const parts = splitInstallments(100000, MAX_INSTALLMENTS);
    expect(parts).toHaveLength(MAX_INSTALLMENTS);
    expect(parts.reduce((a, b) => a + b, 0)).toBe(100000);
  });
});
