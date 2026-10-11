class_name ResRef
extends RefCounted

## Helper for content references in saves (ADR-11).
## Stores references as "uid://" strings when available (survives moves/renames),
## falling back to "res://" paths if no UID exists.

static func to_ref(res: Resource) -> String:
	if res == null:
		return ""
	var path: String = res.resource_path
	if path.is_empty():
		return ""
	if path.begins_with("uid://"):
		return path

	var uid: int = ResourceLoader.get_resource_uid(path)
	if uid != ResourceUID.INVALID_ID:
		return ResourceUID.id_to_text(uid)

	return path

static func load_ref(ref: String) -> Resource:
	if ref.is_empty():
		return null

	if ref.begins_with("uid://"):
		var uid: int = ResourceUID.text_to_id(ref)
		if uid == ResourceUID.INVALID_ID or not ResourceUID.has_id(uid):
			return null
		var resolved_path: String = ResourceUID.get_id_path(uid)
		if resolved_path.is_empty() or not ResourceLoader.exists(resolved_path):
			return null
		return ResourceLoader.load(resolved_path)

	if ResourceLoader.exists(ref):
		return ResourceLoader.load(ref)

	return null
