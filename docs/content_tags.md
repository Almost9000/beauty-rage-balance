# Content Tags Specification

This document defines the formal content and style tags used across garments, outfits, outings, and narrative systems in *Beauty, Rage, Balance*.

## Style Tags

Style tags are free `StringName` identifiers assigned to `ClothingItem.style_tags`. They classify the aesthetic and functional characteristics of clothing, driving wardrobe filtering, outfit synergy, and outing dress code matching (e.g. `GirlsDayOut` vs `DateNight`).

### Primary Style Categories

| Tag | Name | Aesthetic & Function | Typical Use Cases | Outing Affinity |
|---|---|---|---|---|
| `casual` | Casual | Everyday comfort, effortless style, relaxed silhouettes. | T-shirts, basic tunics, day skirts, flat shoes. | Girls' Day Out, running errands, park walks. |
| `chic` | Chic | Tailored, elegant, polished, sophisticated. | Blouses, slacks, blazers, designer dresses, stylish heels. | Date Night, fine dining, cultural events. |
| `sporty` | Sporty | Athletic, functional, moisture-wicking, flexible. | Tank tops, leggings, shorts, sneakers, athletic wear. | Fitness, jogging, high-activity days. |
| `party` | Party | Vibrant, glamorous, bold, eye-catching. | Cocktail dresses, evening gowns, statement heels, sparkly jewelry. | Date Night, clubs, evening celebrations. |
| `cozy` | Cozy | Soft, warm, relaxing, soothing loungewear. | Knit sweaters, peasant skirts, oversized tunics, slippers. | Home lounging, recovery, self-care days. |

### Secondary Descriptive Tags

Secondary tags provide additional descriptive metadata for specific garment properties, silhouettes, and themes:

| Tag | Description | Example Items |
|---|---|---|
| `rustic` | Traditional, cottagecore, natural fibers. | Peasant tunic, peasant skirt. |
| `sturdy` | Durable, weather-resistant, protective. | Leather boots, heavy outerwear. |
| `one_piece` | Full-body single garment occupying dress slot. | Peasant ensemble, jumpsuit, one-piece gown. |

---

## Outing Requirements

Outings specify dress code preferences using style tags:
- **Girls' Day Out (`GIRLS_DAY_OUT`)**: Prefers outfits featuring `chic` or `casual` tags; penalizes overly restrictive or incongruent tags.
- **Date Night (`DATE_NIGHT`)**: Prefers outfits featuring `party` or `chic` tags; boosts Sanity and confidence when dressed appropriately.

---

## Technical Conventions

1. **Tag Storage**: Tags are stored as `Array[StringName]` on `ClothingItem` resources.
2. **Comparison**: Comparisons should use `item.style_tags.has(&"tag_name")`.
3. **UI Display**: Style tags are displayed in the Wardrobe UI as tag chips formatted with a leading hash (e.g. `#chic`, `#casual`).
