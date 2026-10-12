# Writing Bible: Beauty, Rage, Balance

## Core Premise & Creative Vision
*Beauty, Rage, Balance* explores the self-directed life of an independent woman navigating modern aesthetic expectations, relationships, creative ambitions, and bodily autonomy. The game treats the menstrual cycle and physical symptoms as lived realities—expressive, authentic, and integral to the rhythm of life—rather than dirty secrets, inconveniences to laugh at, or clinical pathologies.

---

## 1. Tone Principles

### 1. No Stereotypes or Monolithic Experiences
- Cycle experiences vary drastically between individuals and across different months.
- Avoid tropes such as "she is angry only because she has PMS" or "women are incapacitated during their period."
- Characters must possess real agency, motivations, boundaries, and complex emotional lives that are influenced by, but never solely reduced to, hormonal phases.

### 2. Player Agency & Customization
- The player controls both the **cycle length** (standard 28 days or 12-day demo/fast-paced) and the **symptom intensity** (0.0 to 1.0).
- When the player sets symptom intensity to 0, mechanical stat modifiers are completely neutralized (rate additions become 0, rate multipliers become 1.0). Narrative remains supportive without mechanical burden.
- The game never forces a one-size-fits-all experience.

### 3. Authenticity & Normalization (Never Shameful or Comic)
- Menstruation, hygiene routines, pain relief, and emotional fluctuations are normal aspects of adult life.
- Never write bodily functions as shameful, unclean, grotesque, or punchlines for cheap slapstick humor.
- The tone is grounded, honest, empathetic, and occasionally dry/wry, reflecting the real internal monologue of an adult dealing with bodily realities while keeping up with life and deadlines.

### 4. Holism & Nuance Across All Phases
- Each of the four phases brings distinct physiological and psychological qualities:
  - **Menstrual (Days 1–5)**: Lower energy, heightened sensory/physical vulnerability, cramps, craving for warmth and rest. A time to slow down and protect boundaries.
  - **Follicular (Days 6–13)**: Rising vitality, mental clarity, creative curiosity, readiness to take on new projects and social initiatives.
  - **Ovulatory (Days 14–16)**: Peak confidence, social magnetism, peak physical stamina, heightened assertiveness.
  - **Luteal (Days 17–28)**: Introspection, emotional sensitivity, heightened awareness of friction or unmet needs, lower tolerance for pretense or disrespect.
- Do not romanticize or pathologize any phase; acknowledge both advantages and frictions.

### 5. Rage as an Assertive Resource, Not a Failure State
- In *Beauty, Rage, Balance*, Rage is not an uncontrolled hysterical tantrum. It represents righteous indignity, boundary awareness, and protective heat in response to disrespect, unfair burdens, or social pressure.
- Rage can be spent constructively (via the `ASSERT` stance in narrative choices) to reclaim self-respect and restore sanity.

---

## 2. Guidelines for Cycle-Related Writing

### Descriptive Labels & UI Strings
- Use clear, respectful, and direct terminology (e.g., "Menstrual phase", "Mild cramps", "Rising vitality", "Introspective sensitivity").
- Avoid patronizing euphemisms ("time of the month", "Aunt Flo") unless a specific flawed NPC uses it to highlight their own awkwardness or dismissiveness.
- In-game item descriptions (hot water bottles, pain relief, comfortable loungewear) should emphasize comfort, care, and practical relief.

### Narrative Dialogue & Monologues
- Protagonist internal monologues should reflect authentic self-talk: "I don't have the energy for small talk tonight," "My focus is razor-sharp right now," "I need tea, a heating pad, and two hours without emails."
- Avoid dismissive reactions from friends or love interests. Healthy relationships acknowledge how the other person feels without making it an ordeal or a joke.

---

## 3. Stance Guidelines

Social-pressure narrative events present the protagonist with three core stances:

### 1. Placate (Muted Teal / Cyan)
- **Mindset**: Swallowing discomfort, prioritizing social harmony, or bowing to guilt/obligation to appease family, coworkers, or acquaintances.
- **Tone**: Apologetic, accommodating, weary compliance ("I know, Aunt Mira... I haven't given up.", "I guess I can boot up my laptop for a couple hours...").
- **Mechanical Consequence**:
  - Internal friction accumulates: **Rage builds** (Instant positive delta).
  - Emotional energy depletes: **Sanity drops** (Instant negative delta).
  - No `self_respect` gained.

### 2. Deflect (Amber / Warm Yellow)
- **Mindset**: Diffusing tension, pivoting the topic, or using wry humor and practical excuses to avoid direct conflict without submitting.
- **Tone**: Dry, witty, evasive, gently ironic ("Did Mom show you photos of my rescue dogs instead? Maja and Čipa are plenty of commitment.", "That's just my actual human face under fluorescent lighting.").
- **Mechanical Consequence**:
  - Low friction: Neutral or modest **Sanity gain** (+5 to +10).
  - Minor or no Rage change.
  - Safe middle ground that protects immediate peace without setting permanent boundaries.

### 3. Assert (Bold Magenta / Crimson)
- **Mindset**: Explicitly articulating boundaries, rejecting unsolicited expectations, and protecting bodily and emotional sovereignty.
- **Tone**: Grounded, firm, respectful but uncompromising ("My life is whole and fulfilling as it is, Aunt Mira. Please stop treating marriage like the only measure of my happiness.", "My body needs rest tonight, and I'm listening to it.").
- **Mechanical Consequence**:
  - Turns indignation into empowerment: **Rage spends down** (Instant negative delta, e.g. -20 to -30).
  - Restores internal alignment: **Sanity rises** (Instant positive delta, e.g. +15 to +25).
  - Earns lasting boundary equity: **Increments flag `self_respect`** (+1).
  - Triggers the visual screen flash and impact shake (`RageReleaseFx`).

---

## 4. Narrative Event Authoring Checklist

When authoring a new `NarrativeEvent` resource:
1. **Grounded Conflict**: Is the situation rooted in real-world friction (familial expectations, appearance commentary, workplace boundaries, physical fatigue)?
2. **Channel Authenticity**: Does the channel (`PHONE_CALL` vs `IN_PERSON`) fit the dramatic context?
3. **Pacing & Lines**: Are lines broken into digestible beats (1–3 sentences per page) that read naturally when spoken aloud?
4. **Three Clear Stances**: Does the event provide distinct `PLACATE`, `DEFLECT`, and `ASSERT` choices?
5. **Assert Economy**:
   - Does Assert drop Rage, increase Sanity, and increment `self_respect`?
   - Does Placate increase Rage and decrease Sanity?
   - Does Deflect provide a mild buffer?
6. **Condition Precision**: Are triggers constrained cleanly via `NarrativeCondition` (day range, cycle phase tags, stat thresholds, level location, flags)?
7. **Chain & Follow-up**: If an Assert stance transforms the relationship or sets a precedent, is a follow-up event or flag linked (e.g. `work_boundary_set` leading to `event_follow_up_confrontation`)?

---

## 5. Review & Escalation

- Any writer or designer introducing new cycle phase descriptions, dialogue triggers, or symptoms must review against these principles.
- If unsure about the authenticity or tone of specific symptom text, keep the phrasing neutral and flag it for sensitivity review prior to milestone approval.
