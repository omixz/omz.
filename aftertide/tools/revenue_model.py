#!/usr/bin/env python3
"""AFTERTIDE revenue model.

Edit the ASSUMPTIONS block and run:  python3 revenue_model.py
Every number here is an assumption, not a forecast. Re-check the Roblox
rates against the Creator Hub before relying on them.
"""

# ---------------------------------------------------------------- ASSUMPTIONS
USD_PER_ROBUX_PAID = 0.0115   # blended price players pay per Robux (packs, Premium, gift cards)
CREATOR_SHARE = 0.70          # creator keeps 70% of passes / dev products / private servers
DEVEX_USD_PER_ROBUX = 0.0038  # DevEx rate for Robux earned after 5 Sep 2025 (verify)
DAU_TO_MAU = 6.0              # MAU is roughly 6x DAU for a healthy Roblox title

# Steady-state DAU at months 6-12 after launch.
SCENARIOS = {"Conservative": 1_500, "Moderate": 12_000, "Optimistic": 75_000}

# product: (share of MAU buying per month, average Robux per buyer per month)
PRODUCTS = {
    "Cosmetics (outfits, emotes, items)": (0.020, 320),
    "Character Story Packs":              (0.004, 599),
    "Tide Pass (seasonal premium track)": (0.006, 499),
    "Founder's Lantern + other passes":   (0.004, 300),
    "Hideout bundles":                    (0.003, 250),
    "Private Harbour servers":            (0.0015, 100),
    # Run aids: Second Wind (49), Second Wind x3 (129), Resupply (29). Capped once per crossing
    # and also earned free, so spend per buyer stays modest.
    "Run aids (Second Wind, Resupply)":   (0.030, 110),
}

# Subscription is priced in local currency, not Robux.
SUB_PRICE_USD = 4.99
SUB_SHARE_OF_MAU = 0.004         # active subscribers as a share of MAU
SUB_NET_CASH_SHARE = 0.30        # assumed cash reaching you after store fees, Roblox share, DevEx

# Creator Rewards (engagement-based payouts; replaced Premium Payouts in 2025), modelled as a
# share of earned Robux. Highly uncertain: check your Creator Hub analytics once live.
PREMIUM_PAYOUT_FACTOR = 0.15
# ---------------------------------------------------------------------------


def run(name, dau):
    mau = dau * DAU_TO_MAU
    spent = sum(mau * share * robux for share, robux in PRODUCTS.values())
    earned = spent * CREATOR_SHARE
    premium = earned * PREMIUM_PAYOUT_FACTOR
    sub_gross = mau * SUB_SHARE_OF_MAU * SUB_PRICE_USD
    sub_cash = sub_gross * SUB_NET_CASH_SHARE
    gross_usd = spent * USD_PER_ROBUX_PAID + sub_gross
    cash = (earned + premium) * DEVEX_USD_PER_ROBUX + sub_cash
    return dict(name=name, dau=dau, mau=mau, spent=spent, earned=earned,
                premium=premium, gross_usd=gross_usd, sub_gross=sub_gross,
                sub_cash=sub_cash, cash=cash)


def main():
    print(f"{'Scenario':<13}{'DAU':>8}{'MAU':>9}{'R$ spent/mo':>14}{'R$ earned/mo':>14}"
          f"{'Gross US$/mo':>14}{'Cash US$/mo':>13}{'Cash US$/yr':>13}")
    for name, dau in SCENARIOS.items():
        r = run(name, dau)
        print(f"{name:<13}{dau:>8,}{int(r['mau']):>9,}{int(r['spent']):>14,}"
              f"{int(r['earned'] + r['premium']):>14,}{int(r['gross_usd']):>14,}"
              f"{int(r['cash']):>13,}{int(r['cash'] * 12):>13,}")
    print("\nPer-product earned Robux per month (before Creator Rewards):")
    for prod, (share, robux) in PRODUCTS.items():
        cells = "".join(f"{int(dau * DAU_TO_MAU * share * robux * CREATOR_SHARE):>14,}"
                        for dau in SCENARIOS.values())
        print(f"  {prod:<38}{cells}")
    subs = "".join(f"{int(dau * DAU_TO_MAU * SUB_SHARE_OF_MAU):>14,}" for dau in SCENARIOS.values())
    print(f"  {'Active subscribers':<38}{subs}")


if __name__ == "__main__":
    main()
