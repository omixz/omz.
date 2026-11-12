# 3. Monetisation & Revenue Strategy

## 3.1 Principles (non-negotiable)

1. **No permanent power for sale, and run aids are capped.** No stats, satchel space, paid
   characters or XP boosts. The one exception (your decision, 11 Nov 2026) is **run aids**:
   Second Wind (an extra life) and Resupply (ammo and consumables). Each is limited to **once
   per crossing**, also **earned free by playing**, offered only when the player asks for
   it, and the whole system can be switched off with one setting (`Game.RunAidsEnabled`). See §3.3 B2.
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

- **Creator Rewards** (engagement-based payouts; Roblox replaced Premium Payouts with
  this programme in 2025): Roblox pays based on how much engaged players play your
  experience, plus a bonus for bringing in new or returning players. Long, engaging sessions
  (our 25 to 40 minute runs) suit it. The model assumes **+15% on top of earned Robux**, which
  is speculative. Check the current terms in the Creator Hub.
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

### B2. Run aids (developer products, sold as tokens)

Added at your request so that more than cosmetics can earn money. Built into Slice 0
(`Config/Commerce.luau`, `CommerceService`, `ActionService`).

| Product | Price (R$) | What it does | Limits that keep it fair |
|---|---|---|---|
| **Second Wind** | **49** | Get back up from downed with 60 HP | Max **1 per crossing**. Doesn't work after you're "lost to the Pall". Never auto-prompted: the purchase prompt appears only when *you* press Second Wind with 0 tokens. |
| **Second Wind ×3** | **129** | Three tokens (genuinely cheaper than 3 × 49 = 147) | Same once-per-crossing limit |
| **Resupply Satchel** | **29** | +4 Salt Shot, +1 Bottle, +1 Bandage (fixed contents, never random) | Max **1 per crossing**, capped by satchel limits |

**Earned free:** new players start with 1 of each. Every successful crossing gives +1
Resupply, and your first successful crossing each day gives +1 Second Wind.

**The honest trade-off.** In a co-op PvE game this is "pay to recover", not pay-to-win against
other players, and Roblox players are used to it. The risks:
(1) players who feel it's needed to win leave bad reviews, (2) it weakens the "no pay-to-win"
message, (3) hard difficulty tiers lose prestige. Mitigations: tune the game so a clear
never needs it, keep the limits above, and (from Stage 7) mark clears that used Second Wind
as *assisted* on the top difficulty tier (King Tide) so its prestige cosmetics stay meaningful.
If reviews or retention drop, turn `RunAidsEnabled` off.

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
| **Creator Rewards** | — | Comes automatically from engagement |
| **In-experience avatar item sales** *(year 2)* | Varies | Sell AFTERTIDE-branded avatar items (UGC) for players' normal Roblox avatars. Roblox pays the experience a commission on in-experience sales, separate from the item creator's share. A strong brand-awareness loop. |
| **Physical merch** *(after traction)* | — | Through Roblox's commerce integrations, if available in Australia then |
| **Rewarded video ads** | — | **Not at launch.** They hurt the premium feel. Revisit only as an opt-in at the ferry radio for small cosmetic or Scrip rewards. |

What we **won't** sell: unlimited revives (Second Wind stays capped at once per crossing),
extra satchel space, permanent stat upgrades, XP or salt boosts, paid characters with abilities,
loot boxes, or "skip the run" purchases.

### What's built (in the game now)

| Item | Type | Robux | What you get | Free route |
|------|------|------:|--------------|------------|
| Deckhand Starter Pack | product, **one time** | 99 | 2 Second Wind, 2 Resupply, 3 Ammo Cache + Deckhand outfit for all 4 crew | - |
| Second Wind / x3 | product | 49 / 129 | get up once when downed (max 1 per crossing) | 1 for your first win each day |
| Resupply Satchel | product | 29 | +6 rounds, +1 dressing, +1 bottle (1 per crossing) | 1 per successful crossing |
| Ammo Cache / x5 | product | 25 / 99 | refills reserve ammo for both guns (1 per encounter, key **V**) | 1 per successful crossing |
| Outfits (Night Pilot, Boiler Stoker, Field Surgeon, Reef Diver) | product | 79 each | cosmetic recolour of one crew member | or 1,500 Scrip each |
| Scrip outfits (Storm Watch, Rust Bucket, Mourning Grey, Dune Walker) | earned | - | cosmetic | 400 Scrip each |
| Meridian Supporter | **game pass** | 149 | officer outfits for all crew, +10% Scrip, a badge on your name | - |

Everything is in `src/shared/Config/Commerce.luau` (prices, contents) and
`Config/Cosmetics.luau` (outfits). Players browse it in the **Purser's Office** (Supplies /
Wardrobe / Supporter tabs) or at the **crew lockers** on the ferry (Wardrobe).
Purchases and Scrip flows are logged to Creator Hub Analytics (economy + custom events).

**Creating the products on Roblox (one command):**

1. Publish the place once (File > Publish to Roblox) and copy its **Place ID** (Creator Hub URL).
2. Creator Hub > Open Cloud > API Keys > edit your key > add **Developer Products** (write)
   and **Game Passes** (write) for this experience. (Already added Assets.)
3. `python3 tools/create_products.py --place-id <id>` creates all 10 products and the pass
   and writes their IDs into `Commerce.luau`. Run with `--dry-run` first to see the list.

## 3.4 Revenue model

Assumptions are in [`tools/revenue_model.py`](../tools/revenue_model.py). Steady state
6 to 12 months after launch. MAU is about 6× DAU. Monthly buyer rates per product, as a
share of MAU: cosmetics 2.0%, story packs 0.4%, Tide Pass 0.6%, passes 0.4%,
hideout 0.3%, private servers 0.15%, run aids 3.0% at about 110 R$ each.
Subscribers are 0.4% of MAU.

### Headline (per month unless stated)

| Scenario | DAU | MAU | Robux spent by players | Robux earned (incl. Creator Rewards) | **Gross player spend** | **Cash to you** | **Cash per year** |
|---|---:|---:|---:|---:|---:|---:|---:|
| Conservative | 1,500 | 9,000 | 154,710 | 124,541 | US$1,958 | **US$527** | **US$6,325** |
| Moderate | 12,000 | 72,000 | 1,237,680 | 996,332 | US$15,670 | **US$4,217** | **US$50,606** |
| Optimistic | 75,000 | 450,000 | 7,735,500 | 6,227,077 | US$97,940 | **US$26,357** | **US$316,289** |

### Cash per product per month

| Product | Conservative | Moderate | Optimistic |
|---|---:|---:|---:|
| Cosmetics | $153 | $1,226 | $7,661 |
| Character Story Packs | $57 | $459 | $2,868 |
| Tide Pass | $72 | $573 | $3,584 |
| Founder's Lantern + passes | $29 | $230 | $1,436 |
| Hideout bundles | $18 | $144 | $898 |
| Private Harbour servers | $4 | $29 | $180 |
| Run aids (Second Wind, Resupply) | $79 | $632 | $3,950 |
| Subscription (36 / 288 / 1,800 subs) | $54 | $431 | $2,695 |
| Creator Rewards (assumed) | $62 | $494 | $3,086 |
| **Total** | **$528** | **$4,218** | **$26,358** |

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
| Slice 0 / early access | Run aids (Second Wind, Second Wind ×3, Resupply): already implemented |
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
