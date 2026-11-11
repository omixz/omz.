# 4. IP & Legal Compliance Assessment

> **This isn't legal advice.** It's a working checklist to reduce risk and to prepare
> for a review by an Australian IP lawyer **before commercial launch**. No checklist
> can make a project legally risk-free.

## 4.1 Where the line is

| Generally free to use (ideas, genre, mechanics) | Protected (specific expression) |
|---|---|
| Third-person stealth survival | Character names, designs, likenesses, voices |
| Roguelike runs, node maps, hideouts between levels | Story, dialogue, cutscenes, lore text |
| Crafting, scavenging, limited inventory | Maps, level layouts, recognisable locations |
| AI with sight and hearing, alert states | Music, sound recordings, sound effects |
| Enemy archetypes (a slow tank, a "screamer") | Specific creature designs, sounds and animations |
| Wave-defence, escort and chase objectives | Mode names, logos, UI art, trade marks, trade dress |

Under the **Copyright Act 1968 (Cth)** copyright protects *expression*, not *ideas*.
Infringement is about reproducing a **substantial part**, judged by **quality, not
quantity**. A small but distinctive element can be enough. The closer the overall
"look and feel" gets to the inspiration, the higher the risk. Trade mark law and
**passing off / misleading conduct** (Australian Consumer Law s18) also apply, even if
nothing is copied, when the presentation suggests a connection that doesn't exist.

## 4.2 Trade marks & brand

- [ ] **Search the title.** Check "AFTERTIDE" and the alternates in IP Australia's
      trade mark search, USPTO (TESS successor), EUIPO and WIPO Global Brand Database.
      Classes: **9** (downloadable game software), **41** (online game services),
      **25** (apparel/merch), **28** (toys and games). Also search Roblox itself, Steam,
      app stores and domain and social handles.
- [ ] Get a lawyer's clearance opinion **before** commissioning the logo.
- [ ] File an Australian application in classes 9 and 41 at minimum, then consider a
      **Madrid Protocol** extension to the US, UK and EU once there's traction.
- [ ] Secure matching social handles, a domain, and a Roblox group name.
- [ ] Never use "The Last of Us", "No Return", "Naughty Dog", "PlayStation", "Sony"
      or their logos in the title, description, thumbnails, icons, tags, ads, video
      titles or keywords. **No "like TLOU" or "TLOU-inspired" marketing.** It
      implies affiliation and invites claims of misleading conduct and passing off.

## 4.3 Distinctiveness audit (run at every milestone)

Check each item against the inspiration. Any "yes" needs a redesign.

| Area | Avoid | Our approach |
|---|---|---|
| Premise | Fungal infection, spore-based contagion, a post-outbreak America | A tidal sea-fog phenomenon on a fictional coast |
| Enemies | Fungal growths, plated faces, clicking echolocation sounds, "stalker / runner / clicker"-style names | Silent, salt-crusted Hushed that disperse into fog |
| Protagonists | A teen girl with a guitar, a bow and a fern tattoo; a muscular woman with a braid; a grizzled father figure; their outfits and silhouettes | An ensemble crew of varied ages and backgrounds, with salt and sea-themed gear |
| Factions | Militia and cult analogues, scars and symbol iconography | (Post-launch) Tollkeepers, a toll-bridge cartel that captures rather than kills |
| Mode structure | Encounter names "Assault / Holdout / Hunted / Capture", the mode name "No Return" | Salvage, Lantern Watch, Drift, Lost Signal, Silent Passage |
| Hideout | A farm or theatre-style hub layout | A beached car ferry |
| Listen-mode visual | A grey world with white enemy silhouettes | Tide Sense: salt glints in fog, short range, world colour unchanged |
| UI | A specific crafting wheel or backpack style, typography | A waxed canvas satchel, tide-chart map, hull-stencil type |
| Audio | Signature guitar/ronroco-style score, creature sounds | Low strings, detuned brass, silence-led |
| Locations | Seattle, Santa Barbara, Jackson, any real landmark copies | The fictional Marrow Coast |

Keep a **design-reference log**: when you use reference images, record why and what
general quality you took from them, such as "fog density". Never trace or copy
paintovers.

## 4.4 Assets, licensing & ownership

**Contractors (critical in Australia):** for commissioned work, **copyright stays with
the creator unless it's assigned in writing**. Employees are different: work they make
in the course of their job belongs to the employer. Without a written assignment, you
may not own your game's art, music or code.

- [ ] Every contractor signs an agreement before work starts, covering:
  - **Assignment** of all copyright (present and future) to you or your company.
  - **Moral rights consent** under Part IX of the Copyright Act, covering attribution
    and integrity, so you can modify and use the work without credit disputes.
  - A **warranty** that the work is original, and that any third-party parts, AI use
    and licences are disclosed.
  - Confidentiality, payment terms and portfolio-use terms.
- [ ] **Voice actors:** a written release for recordings and likeness, covering
      in-game and marketing use worldwide and permanently. Check union rules if
      applicable.
- [ ] **Free models from the Roblox Creator Store:** **banned in production.** They
      create licence uncertainty (re-uploaded stolen assets are common) and security
      risk (hidden backdoor scripts). Use them only as clearly marked placeholders in
      prototypes, and remove them before release.
- [ ] **Bought asset packs, mocap and SFX libraries:** keep the licence text and proof
      of purchase. Check that the licence allows **commercial use, use in a game**,
      **and use on Roblox**. Some licences forbid uploading to platforms where the raw
      asset could be extracted, and Roblox assets can be extracted.
- [ ] **Mixamo and similar free animation services:** check the current terms. Prefer
      our own mocap or explicitly licensed packs for hero animations.
- [ ] **AI-generated assets:** copyright protection under Australian law requires
      human authorship, so purely AI-generated assets may not be protectable, and a
      competitor could copy them. Check each tool's terms of service. Record the tool,
      the prompts and how much a human modified the result. Avoid AI for core brand
      assets (logo, key characters, main theme).
- [ ] **Fonts:** in-game UI uses Roblox's font library. For the logo and marketing,
      use fonts with a licence covering commercial logo use (for example OFL, or a paid
      desktop + app licence).
- [ ] **Code libraries:** permissive licences only (MIT, Apache 2.0, BSD). Keep
      `LICENSE` notices in the repo.

### Music & audio

- [ ] **Original score** commissioned with full assignment, *or* an exclusive
      licence that explicitly covers: Roblox in-game use, trailers, social media,
      streams and VODs, and any soundtrack release.
- [ ] **Roblox's built-in licensed audio library:** licensed for use **inside Roblox
      only**. Don't use it in trailers or off-platform marketing unless its terms say
      you can.
- [ ] **Content ID:** if the composer registers the score with YouTube Content ID or a
      similar system, whitelist our channels, and make sure players' videos won't be
      claimed. Claims on creators' videos kill organic marketing.
- [ ] **Sound effects:** commercial-licence libraries (for example bundles whose
      licence covers royalty-free game use), plus our own Foley recordings. Log each
      source.
- [ ] **No commercial songs** on the in-game radio unless a sync licence and a master
      licence are both obtained. In practice, use only originals.

### Asset register (keep from the very first asset)

One spreadsheet. Each row:

`Asset name | Roblox asset ID | Type | Creator | Source (own / contractor / purchased / library) | Licence name + link/file | Commercial use OK? | Roblox use OK? | Marketing use OK? | Proof of purchase / contract file | Date | AI involvement | Notes`

Run an audit before each release: every asset ID in the place file must have a row.

## 4.5 Roblox platform rules

- [ ] **Terms of Use:** you keep ownership of your content but grant Roblox a broad
      licence to host, display and use it on the platform. Roblox can remove content.
      Don't build a business that relies on content Roblox might moderate.
- [ ] **Community Standards:** fictional violence only. No realistic gore. No
      real-world weapons instruction. Keep themes non-graphic. The Hushed disperse into
      fog and there is no blood. No real-world extremist or hate symbols, even on
      enemy factions.
- [ ] **Maturity & Compliance Questionnaire:** answer it accurately. Our target label
      is **Moderate**, because of fear and horror themes and fictional violence. That
      label restricts access for the youngest age group by default. Accept that: it
      fits the premium positioning and an audience that spends. Answering inaccurately
      can lead to moderation and removal. Re-check the questionnaire whenever content
      changes.
- [ ] **Paid random items:** if any were ever added, Roblox policy requires disclosed
      odds, and Australian classification rules since Sept 2024 treat paid loot boxes
      as a rating factor. **Our policy is none.**
- [ ] **Advertising Standards** for any Roblox ads or sponsored placements. **No
      misleading thumbnails** showing features or graphics that aren't in the game.
- [ ] **Privacy:** don't collect personal information outside Roblox's systems, no
      off-platform links that ask for personal details, no social links in the
      experience unless they're Roblox-approved, and follow Roblox's rules for
      communication features.
- [ ] **DevEx Terms:** age, ID, tax forms and good standing (see doc 3).

## 4.6 Australian consumer & business law

- [ ] **Australian Consumer Law:** no misleading or deceptive conduct (s18) and no
      false or misleading representations about price, value or affiliation (s29).
      This applies to bundle values, "was/now" prices, scarcity claims and
      "official" claims. Digital goods carry **consumer guarantees**; Roblox handles
      refunds, but don't make statements that contradict those rights.
- [ ] **Influencer marketing:** sponsored creators must clearly disclose the paid
      relationship (ACCC influencer guidance, and the YouTube/TikTok disclosure tools).
- [ ] **Business structure:** sole trader with an ABN at the start; consider a **Pty
      Ltd company** to hold the IP and contracts before signing contractors or earning
      significant revenue. That keeps IP ownership clean if you take investment or sell
      the business later.
- [ ] **Tax:** DevEx income is assessable. Register for GST at A$75k turnover (an
      accountant can confirm the GST treatment of supplies to Roblox Corp). File a
      W-8BEN with DevEx to claim the US–Australia treaty rate where applicable.

## 4.7 Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Title conflicts with an existing trade mark | Medium | High (rebrand) | Search and get a lawyer's opinion before building the brand |
| Overall look and feel judged too close to the inspiration | Low to medium (with this design) | High | Distinctiveness audit at each milestone; outside review |
| Contractor still owns key assets | Medium if unmanaged | High | Assignment and moral-rights consent before work starts |
| Free or stolen asset in the build | Medium | Medium to high | Ban on free models; asset register audit |
| Music claims on player videos | Medium | Medium | Original score, whitelisting, clear licence terms |
| Maturity label mis-set → moderation | Low | High | Accurate questionnaire, re-checked each update |
| Misleading pricing (ACL) | Low with our principles | Medium | Honest bundle and sale rules (doc 3 §3.1) |
| Roblox policy or economics change (DevEx rate, payout terms, ad rules) | Medium | Medium | Diversify (merch, possible standalone port later), keep IP ownership clean |
| Players "hacking" purchases or items | Low | Medium | Server-only grants, idempotent receipts |

## 4.8 Pre-launch legal gate

Before the public commercial launch:

1. Book an **IP lawyer review**: title clearance, the distinctiveness audit, contractor
   agreements and the asset register.
2. Have an **accountant review** the business structure, GST and DevEx tax forms.
3. Get an **internal sign-off** that no third-party placeholder assets remain.
4. Re-check the maturity questionnaire and confirm marketing contains no protected
   brand references.
