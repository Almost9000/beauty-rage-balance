extends Node

# EventBus (Autoload Singleton #1)
#
# ADR-01: Cross-feature gameplay signals only.
# Feature-specific domain signals belong to their respective domain managers.
# Signals are declared by the task that first emits them so payload types exist.
#
signal outing_scheduled(outing_ref: String, departure_min: int, partner_ref: String)
signal item_purchased(item_ref: String, price_cents: int)
signal clutter_cleaned(clutter_type: StringName, weight: float)

signal dog_need_changed(dog_id: StringName, need: StringName, value: float)

signal narrative_requested(event_id: StringName)

