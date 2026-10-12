extends Node

# EventBus (Autoload Singleton #1)
#
# ADR-01: Cross-feature gameplay signals only.
# Feature-specific domain signals belong to their respective domain managers.
# Signals are declared by the task that first emits them so payload types exist.
#
signal outing_scheduled(outing_ref: String, departure_min: int, partner_ref: String)

# Planned signals:
# - item_purchased(item: Resource)            -> Task 19
# - clutter_cleaned(amount: int)              -> Task 20
# - dog_need_changed(dog_id: StringName, need: StringName, value: float) -> Task 21
# - narrative_requested(event_id: StringName) -> Task 23
