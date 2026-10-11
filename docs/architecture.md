# Architecture Specification

## 1. Manager Contract

All autoload managers in *Beauty, Rage, Balance* must adhere strictly to this contract:

1. **State & Rules Only**: Autoload managers hold state and business rules only. They must never hold node references to level nodes or transient scene tree instances.
2. **State Lifecycle & JSON Serialization**: Each manager implements:
   - `reset_state() -> void`
   - `to_dict() -> Dictionary`
   - `from_dict(data: Dictionary, version: int) -> void`
   Dictionaries must be strictly JSON-safe: no `Resource` or `Object` instances, enums serialized as `int`, content referenced via `ResRef` (`uid://` or `res://` strings), and money stored as `int` cents (not floats).
3. **Domain Signals**: Each manager emits its own domain signals using past tense naming (e.g. `stat_changed`, `phase_changed`). `EventBus` is reserved strictly for cross-feature gameplay events.
4. **Initialization Dependency Order**: `_ready()` in any manager may touch only autoloads registered strictly above it in the autoload order.
5. **Gameplay Timing**: Gameplay time comes from `GameClock` only; never use Godot `Timer` nodes for gameplay logic, deadlines, or countdowns.
6. **Test Isolation**: Automated unit tests must call `reset_state()` on every manager they touch in their `before_each()` hook.
7. **Time Integration & Listener Contract**: Managers that track decay, stats, schedules, or periodic updates must integrate `GameClock.minute_ticked(now)` as a 1-minute segment and `GameClock.time_skipped(from_min, to_min)` using the exact same code path (e.g. `_integrate_decay(from_min: int, to_min: int)`), ensuring that `skip(N)` and N individual minute ticks produce identical results.

---

## 2. Fixed Autoload Order

The autoload execution and registration order in `project.godot` is fixed as follows (1–13):

| Order | Singleton Name | Path | Purpose |
|---|---|---|---|
| 1 | `EventBus` | `res://autoload/event_bus.gd` | Cross-feature gameplay signals only |
| 2 | `GameClock` | `res://autoload/game_clock.gd` | In-game minutes, day rollover, countdowns, time-skip |
| 3 | `StatusManager` | `res://autoload/status_manager.gd` | Sanity/Health/Hygiene/Rage + StatModifier stack |
| 4 | `CycleManager` | `res://autoload/cycle_manager.gd` | Menstrual cycle phase tracking → registers StatModifiers |
| 5 | `FinanceManager` | `res://autoload/finance_manager.gd` | Wallet (cents), ledger, bills & income schedules |
| 6 | `InventoryManager` | `res://autoload/inventory_manager.gd` | Owned clothing/cosmetics, equipped outfit, deliveries |
| 7 | `OutingManager` | `res://autoload/outing_manager.gd` | Scheduled outings, prep state, evaluation, affinity |
| 8 | `NarrativeManager` | `res://autoload/narrative_manager.gd` | Event pool, trigger conditions, choice resolution |
| 9 | `SceneRouter` | `res://autoload/scene_router.gd` | Level transitions (fade), spawn points, per-level state |
| 10 | `DayDirector` | `res://autoload/day_director.gd` | Day beats, pass-out times, night summary stats |
| 11 | `SaveManager` | `res://autoload/save_manager.gd` | JSON save/load coordinator (`to_dict` / `from_dict`) |
| 12 | `Phone` | `res://features/phone/phone.tscn` | UI autoload: persistent app state across levels |
| 13 | `DebugPanel` | `res://ui/debug/debug_panel.tscn` | UI autoload: dev cheats & inspector (dev builds only) |

---

## 3. EventBus Signal Registry

`EventBus` routes cross-feature events between vertical slices without creating direct dependencies between systems. Signals are added as their payload types are created in their respective tasks.

| Signal | Payload | Emitter | Planned Listeners | Task Introduced |
|---|---|---|---|---|
| `outing_scheduled` | `outing_data: OutingData` | `DatingApp`, `NarrativeManager` | `OutingManager`, `Phone` | Task 15 |
| `item_purchased` | `item: Resource` | `ShopApp`, `ThriftStore` | `InventoryManager`, `FinanceManager` | Task 19 |
| `clutter_cleaned` | `amount: int` | `Clutter` | `DayDirector`, `StatusManager` | Task 20 |
| `dog_need_changed` | `dog_id: StringName, need: StringName, value: float` | `DogBrain` | `HUD`, `DayDirector` | Task 21 |
| `narrative_requested` | `event_id: StringName` | Systems / triggers | `NarrativeManager` | Task 23 |
