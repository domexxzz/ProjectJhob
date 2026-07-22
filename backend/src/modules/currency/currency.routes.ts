import { Router } from "express";
import { z } from "zod";
import { asyncHandler } from "../../lib/http";
import { cache } from "../../lib/cache";

export const currencyRouter = Router();

const querySchema = z.object({
  from: z.enum(["THB"]).default("THB"),
  to: z.enum(["USD"]).default("USD"),
});

type ExchangeRate = {
  from: "THB";
  to: "USD";
  rate: number;
  date: string;
  source: "Frankfurter / ECB" | "bundled-fallback";
  stale: boolean;
};

const fallbackRate: ExchangeRate = {
  from: "THB",
  to: "USD",
  rate: 0.0297,
  date: "2026-07-21",
  source: "bundled-fallback",
  stale: true,
};

currencyRouter.get(
  "/rate",
  asyncHandler(async (req, res) => {
    const { from, to } = querySchema.parse(req.query);
    const cacheKey = `exchange-rate:${from}:${to}`;
    const cached = await cache.get<ExchangeRate>(cacheKey);
    if (cached) {
      res.json({ exchangeRate: cached });
      return;
    }

    try {
      const response = await fetch(
        `https://api.frankfurter.app/latest?from=${from}&to=${to}`,
        { signal: AbortSignal.timeout(5000) },
      );
      if (!response.ok)
        throw new Error(`rate provider returned ${response.status}`);
      const body = (await response.json()) as {
        date?: string;
        rates?: Record<string, number>;
      };
      const rate = body.rates?.[to];
      if (!rate || !Number.isFinite(rate) || rate <= 0 || !body.date) {
        throw new Error("invalid exchange-rate response");
      }
      const exchangeRate: ExchangeRate = {
        from,
        to,
        rate,
        date: body.date,
        source: "Frankfurter / ECB",
        stale: false,
      };
      await cache.set(cacheKey, exchangeRate, 6 * 60 * 60);
      res.json({ exchangeRate });
    } catch (error) {
      console.warn(
        "[currency] using bundled fallback:",
        (error as Error).message,
      );
      res.json({ exchangeRate: fallbackRate });
    }
  }),
);
