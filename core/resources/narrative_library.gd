class_name NarrativeLibrary
extends Resource

@export var events: Array[NarrativeEvent] = []


func get_event(id: StringName) -> NarrativeEvent:
	for ev: NarrativeEvent in events:
		if ev and ev.id == id:
			return ev
	return null


func has_event(id: StringName) -> bool:
	return get_event(id) != null
