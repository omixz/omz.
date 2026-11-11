# 3. Monetisation & Revenue Strategy

## 3.1 Principles (non-negotiable)

1. **Nothing sold affects gameplay power.** No stats, no satchel space, no revives, no
   characters with abilities sold for Robux, no XP boosts that change balance.
2. **No paid random rewards.** No loot boxes, gacha, mystery crates or random
   cosmetics bought with Robux. Every purchase shows exactly what you get.
3. **Direct Robux pricing, with no premium currency.** Each item has a Robux price.
   A middle currency hides real costs and leaves players with "leftover" balances. We
   don't use one.
4. **Honest bundles and sales.** A bundle may show "worth X" only if every component
   is genuinely sold separately at those prices. A "was/now" price appears only if the
   item really sold at the "was" price for a meaningful period. Fake reference prices
   can breach the Australian Consumer Law; see doc 4.
5. **No manipulative scarcity.** Regular shop items have no countdown timers. Seasonal
   items return in later "Archive" rotations. No streak punishments, and no paywalled
   pop-ups after losing a run.
6. **Free players matter.** They fill co-op lobbies, make content and drive the
   discovery metrics that bring in buyers. The free game must be the complete game.

Monetisation is built into the architecture from day one: one `Catalog` module (doc 2)
defines every item and its price and source, whether *earned, shop, pass, season or
subscription*. The UI, the server grant logic and analytics all read from it.

## 3.2 How Roblox money works (gross vs earned vs cash)

| Stage | What it is | Rate (verify on the Creator Hub before relying on it) |
|---|---|---|
| **Gross player spend** | What players pay in real money for Robux | Roughly US$0.0100 to $0.0125 per Robux depending on pack size and Premium. The model uses **$0.0115**. |
| **Earned Robux** | What reaches you from a sale | **70%** of the price for game passes, developer products and private servers. Roblox keeps 30%, which covers app-store fees, hosting and payments. |
| **Pending period** | Sales Robux are held before they become available | Several days; plan cash flow for it |
| **DevEx cash-out** | Converting earned Robux to USD | **US$0.0038 per Robux** for Robux earned after 5 Sep 2025 (older Robux at $0.0035) |
| **DevEx eligibility** | Requirements | 13+, verified email, ID verification, a minimum of **30,000 earned Robux**, good standing with Roblox, a DevEx portal account, US tax form (**W-8BEN** for Australian residents) |
| **Your taxes** | Australian income tax on business or hobby income; GST registration if turnover reaches A$75k | Get an accountant. Exported services can be GST-free, but confirm that. |

**Rule of thumb:** for every **US$1.00** a player spends, about **80 to 100 Robux**
are bought, you **earn about 56 to 70 Robux**, and you **cash out about US$0.21 to
$0.27**. That's about **a quarter** of player spend.

Other income streams:

- **Premium Payouts:** Roblox pays creators based on how long Roblox Premium
  subscribers spend in your experience. Long, engaging sessions (our 25 to 40 minute
  runs) suit this well. The model assumes **+15% on top of earned Robux**, which is
  speculative.
- **Subscriptions** are priced in local currency. The model assumes about **30% of the
  sticker price** reaches you as cash after store fees, Roblox's share and conversion.
  Confirm the current payout terms in the Creator Hub before launch.

## 3.3 Product catalogue & pricing

### A. Cosmetics (individual developer products, owned permanently)

| Item | Price (R$) | Player value |
|---|---|---|
| Character outfit, standard (e.g. "Oilskin & Wool", Mara) | **199** | Full model swap with unique silhouette and material set |
| Character outfit, deluxe (with animated element, e.g. a coat that blows in the wind, custom footstep sounds) | **349** | Premium craft; the hero item of the shop |
| Colourway of an owned outfit | **79** | Personalisation |
| Accessory (scarf, satchel skin, hat, mask filter) | **49 to 99** | Mix-and-match identity |
| Lantern / torch skin (beam brightness and colour fixed for fairness) | **99** | Visible signature in every encounter |
| Tide-hook skin (Quieting tool) | **99** | Visible in the most cinematic moment |
| Emote / idle animation (ferry and lobby) | **79 to 149** | Social expression in co-op and the lobby |
| Quieting animation variant (non-graphic, styled per character) | **149** | Cinematic flair |
| Dispersal effect (colour and pattern of the salt burst) | **99** | A satisfying moment, purely visual |
| Photo-mode frame and film pack ("Darkroom") | **149** | Content creators love it, and it markets the game |

### B. Hideout customisation (developer products)

| Item | Price (R$) |
|---|---|
| Cabin furniture piece | **25 to 99** |
| Cabin theme bundle (8 to 12 pieces + lighting preset) | **399** |
| Galley radio station (original music pack, if music rights allow) | **149** |
| Ferry paint & flags (visible to co-op partners) | **199** |

### C. Premium content

| Product | Type | Price (R$) | Contents |
|---|---|---|---|
| **Character Story Pack** (one per character) | Dev product | **599** | 2 outfits + 1 emote + 1 Quieting variant + cabin memento + an exclusive voiced logbook story (about 900 R$ if bought separately, so the bundle is genuinely cheaper) |
| **Founder's Lantern** (available for the first 6 months, clearly stated up front) | Game pass | **499** | Founder lantern skin, ferry banner, "Founding Crew" nameplate, Archive outfit. Cosmetic only. |
| **Darkroom Pro** | Game pass | **149** | Extra photo-mode filters, poses and frames (basic photo mode is free) |
| **Crew Wardrobe+** | Game pass | **149** | +6 saved cosmetic loadout presets per character (convenience, not power) |
| **Expansion: "Saltworks"** *(year 2)* | — | — | **Free** new region for everyone (it grows the player base); the money comes from that region's cosmetic line and story pack. Paywalling maps splits co-op lobbies. |

### D. Recurring

**Tide Pass (seasonal premium track)**, sold as a developer product per season, **499 R$**.

- Seasons of about 10 weeks. 50 tiers. A **free track** (around 40% of rewards:
  cosmetics, Ferry Scrip, logbook entries) and a **premium track** (cosmetics only).
- Finishing it takes about **25 hours of normal play** across the season, around 2.5
  hours a week. You can still complete it if you play casually.
- **No tier skips at launch.** After the season ends, owners get a 2-week grace period
  to finish. Unclaimed premium items return in a future Archive rotation.
- The premium track does **not** refund itself (no "earn back the pass price in
  currency" loop), because we have no premium currency.

**Harbour Crew subscription** (Roblox experience subscription, priced in local
currency, about **US$4.99 a month**). Launches about 8 to 12 weeks after release.

- One exclusive **monthly outfit or cosmetic drop**, yours to keep even after you
  cancel.
- **Crew Wardrobe+** included while subscribed.
- Member radio station and a members-only galley décor set that rotates monthly.
- A monthly *Darkroom* film stock.
- *Not included:* anything that affects gameplay, early access to characters, or
  discounts presented in misleading ways.

### E. Other revenue

| Source | Price | Notes |
|---|---|---|
| **Private Harbour** (private server for the lobby) | **100 R$/month** | Creators, clans and friend groups. Co-op runs already use free reserved servers. |
| **Premium Payouts** | — | Comes automatically from engagement |
| **In-experience avatar item sales** *(year 2)* | Varies | Sell AFTERTIDE-branded avatar items (UGC) for players' normal Roblox avatars. Roblox pays the experience a commission on in-experience sales, separate from the item creator's share. A strong brand-awareness loop. |
| **Physical merch** *(after traction)* | — | Through Roblox's commerce integrations, if available in Australia then |
| **Rewarded video ads** | — | **Not at launch.** They hurt the premium feel. Revisit only as an opt-in at the ferry radio for small cosmetic or Scrip rewards. |

What we **won't** sell: revives, extra satchel space, resource packs, XP or salt
boosts, paid characters with abilities, loot boxes, or "skip the run" purchases.

## 3.4 Revenue model

Assumptions are in [`tools/revenue_model.py`](../tools/revenue_model.py). Steady state
6 to 12 months after launch. MAU is about 6× DAU. Monthly buyer rates per product, as a
share of MAU: cosmetics 2.0%, story packs 0.4%, Tide Pass 0.6%, passes 0.4%,
hideout 0.3%, private servers 0.15%. Subscribers are 0.4% of MAU.

### Headline (per month unless stated)

| Scenario | DAU | MAU | Robux spent by players | Robux earned (incl. Premium Payouts) | **Gross player spend** | **Cash to you** | **Cash per year** |
|---|---:|---:|---:|---:|---:|---:|---:|
| Conservative | 1,500 | 9,000 | 125,010 | 100,633 | US$1,617 | **US$436** | **US$5,235** |
| Moderate | 12,000 | 72,000 | 1,000,080 | 805,064 | US$12,938 | **US$3,490** | **US$41,884** |
| Optimistic | 75,000 | 450,000 | 6,250,500 | 5,031,652 | US$80,862 | **US$21,814** | **US$261,778** |

### Cash per product per month

| Product | Conservative | Moderate | Optimistic |
|---|---:|---:|---:|
| Cosmetics | $153 | $1,226 | $7,661 |
| Character Story Packs | $57 | $459 | $2,868 |
| Tide Pass | $72 | $573 | $3,584 |
| Founder's Lantern + passes | $29 | $230 | $1,436 |
| Hideout bundles | $18 | $144 | $898 |
| Private Harbour servers | $4 | $29 | $180 |
| Subscription (36 / 288 / 1,800 subs) | $54 | $431 | $2,695 |
| Premium Payouts (assumed) | $50 | $399 | $2,494 |
| **Total** | **$437** | **$3,491** | **$21,816** |

### How to read this honestly

- **The real floor is zero.** Most Roblox experiences never reach 1,500 DAU. The
  "conservative" scenario already assumes we succeed at getting a stable player base.
- Revenue grows with **DAU × conversion × content cadence**. The big lever is
  **retention** (D1 above 30%, D7 above 10%, average session above 25 minutes). Good
  retention gets the experience recommended by Roblox's discovery algorithm, which
  brings in DAU.
- These figures are **ethical-model** numbers. Games that use loot boxes or pay-to-win
  earn more per user. Our trade-off is a better reputation, a broader audience and
  longer lifetime value.
- Early DevEx is limited by the 30,000 earned Robux minimum. At the conservative
  scenario you reach it within about the first month.
- **Costs are not subtracted:** art, mocap, music, sound, contractors, Roblox
  advertising, legal review, accountant. A realistic small-team budget runs to several
  thousand dollars to the low tens of thousands before launch.
- **Reaching the Optimistic case** means sustained top-few-hundred status on Roblox.
  It's possible for a standout game, but don't plan around it.

## 3.5 Pricing guidance

- Price anchors: 49 / 79 / 99 / 149 / 199 / 349 / 499 / 599. Items should cost about
  as much as a standard Robux pack so players aren't left with awkward leftovers.
- Use Roblox's **price optimisation and regional pricing tools** (where available for
  our product types) to test prices, but never show different prices for the same item
  in a way that looks like a fake discount.
- Have 1 or 2 fair-value bundles per season and **no** "93% OFF!!" banners.

## 3.6 Launch sequencing

| Phase | Live products |
|---|---|
| Closed testing | None (test purchases in Studio only) |
| Launch (v1.0) | Cosmetics (about 40 items), 4 Character Story Packs, Founder's Lantern, Darkroom Pro, Crew Wardrobe+, Private Harbour |
| +4 to 6 weeks | Season 1 Tide Pass |
| +8 to 12 weeks | Harbour Crew subscription (once 2 or more content drops have shipped) |
| Year 2 | Free region expansion + its cosmetic line, avatar-item (UGC) sales, possibly merch |

## 3.7 Metrics to instrument from day one

Conversion funnel (shop open → item preview → prompt → purchase), first-purchase
timing, ARPDAU, ARPPU, payer conversion, refund and chargeback signals, Tide Pass
completion rate (target 55 to 70% of buyers finish), subscriber churn, and the share of
revenue by product. Use `AnalyticsService` economy and custom events.

## 3.8 The in-world shop: *The Purser's Office*

The shop is a **place on the ferry**, not a pop-up.

- A cramped purser's cabin behind a steel grille window. **Agnes Pell**, the ferry's
  quartermaster, comments on what you're looking at (short original voice lines).
- Outfits hang on a **clothes rail**. Pick one and the camera moves to a **mirror**
  where your current character wears it, with a choice of lighting presets (ferry,
  fog, lantern) so you can see it in game conditions.
- Hideout items appear as small **catalogue cards** pinned to a corkboard. Selecting
  one previews it placed in your cabin.
- The Tide Pass is a **tide chart on the wall**. Tiers are marked as tide heights.
- Prices are shown clearly in Robux with the Robux icon. The purchase always goes
  through the standard Roblox purchase prompt; we never imitate or hide it.
- **Earned** items are shown alongside shop items, with exactly how to earn them
  ("Mastery 12 with Sefa"). This shows the game's free content is real and keeps the
  shop honest.
- In the Harbour lobby, a smaller **trader barge** stall gives the same catalogue
  for players who aren't in a run.
- There are no shop pop-ups after a run fails, no notification badges on the shop,
  and no "limited time!" interruptions.
