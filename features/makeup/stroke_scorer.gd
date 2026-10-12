class_name StrokeScorer
extends RefCounted

const DEFAULT_GRID_SIZE: int = 128


## Scores a player stroke against a target MakeupGuide.
## - stroke can be a PackedVector2Array, an Array[Vector2], or an Array of polylines.
## - stroke_width <= 0 defaults to guide.width.
## - smudge_angle >= 0 forces a deterministic smudge angle in radians (useful for tests).
## Returns a Dictionary with:
##   "accuracy": float (0.0 .. 1.0)
##   "coverage": float (covered_guide_cells / guide_cells)
##   "bleed": float (stroke_cells_outside_guide / guide_cells)
##   "opacity": float (lerped between guide.opacity_range.x and .y)
##   "smudge": Vector2 (smudge vector with magnitude (1.0 - accuracy) * guide.max_smudge)
##   "guide_cells": int
##   "stroke_cells": int
##   "covered_cells": int
##   "bleed_cells": int
static func score_stroke(
	guide: MakeupGuide,
	stroke: Variant,
	stroke_width: float = -1.0,
	smudge_angle: float = -1.0,
	grid_size: int = DEFAULT_GRID_SIZE
) -> Dictionary:
	var result := {
		"accuracy": 0.0,
		"coverage": 0.0,
		"bleed": 0.0,
		"opacity": 0.0,
		"smudge": Vector2.ZERO,
		"guide_cells": 0,
		"stroke_cells": 0,
		"covered_cells": 0,
		"bleed_cells": 0,
	}

	if guide == null or guide.points.is_empty() or guide.width <= 0.0:
		return result

	var n: int = grid_size
	var total_cells: int = n * n

	# 1. Rasterize guide polyline into grid (or use cached grid if available)
	var guide_grid: PackedByteArray
	var guide_cells: int = 0
	if guide.has_meta(&"raster_grid") and guide.get_meta(&"raster_grid_n", 0) == n:
		guide_grid = guide.get_meta(&"raster_grid") as PackedByteArray
		guide_cells = int(guide.get_meta(&"raster_cells", 0))
	else:
		guide_grid = PackedByteArray()
		guide_grid.resize(total_cells)
		guide_cells = _rasterize_polyline(guide_grid, guide.points, guide.width, n, null)
		guide.set_meta(&"raster_grid", guide_grid)
		guide.set_meta(&"raster_cells", guide_cells)
		guide.set_meta(&"raster_grid_n", n)

	result["guide_cells"] = guide_cells

	if guide_cells == 0:
		return result

	# 2. Extract and rasterize stroke
	var s_width: float = stroke_width if stroke_width > 0.0 else guide.width
	var stroke_polylines: Array[PackedVector2Array] = _extract_polylines(stroke)

	var stroke_grid := PackedByteArray()
	stroke_grid.resize(total_cells)
	var stroke_indices: Array[int] = []

	var stroke_cells: int = 0
	for poly: PackedVector2Array in stroke_polylines:
		stroke_cells += _rasterize_polyline(stroke_grid, poly, s_width, n, stroke_indices)
	result["stroke_cells"] = stroke_cells

	if stroke_cells == 0:
		result["accuracy"] = 0.0
		result["coverage"] = 0.0
		result["bleed"] = 0.0
		result["opacity"] = guide.opacity_range.x
		var angle: float = smudge_angle if smudge_angle >= 0.0 else randf() * TAU
		result["smudge"] = Vector2(cos(angle), sin(angle)) * guide.max_smudge
		return result

	# 3. Compute overlap metrics only over the touched stroke cells
	var covered_cells: int = 0
	var bleed_cells: int = 0

	for idx: int in stroke_indices:
		if guide_grid[idx] != 0:
			covered_cells += 1
		else:
			bleed_cells += 1

	result["covered_cells"] = covered_cells
	result["bleed_cells"] = bleed_cells

	var coverage: float = float(covered_cells) / float(guide_cells)
	var bleed: float = float(bleed_cells) / float(guide_cells)
	var accuracy: float = clampf(coverage - bleed, 0.0, 1.0)

	result["coverage"] = coverage
	result["bleed"] = bleed
	result["accuracy"] = accuracy

	# 4. Map to opacity and smudge
	var opacity: float = lerp(guide.opacity_range.x, guide.opacity_range.y, accuracy)
	result["opacity"] = opacity

	var smudge_mag: float = (1.0 - accuracy) * guide.max_smudge
	var angle: float = smudge_angle if smudge_angle >= 0.0 else randf() * TAU
	result["smudge"] = Vector2(cos(angle), sin(angle)) * smudge_mag

	return result


## Rasterizes a thick polyline onto an n x n byte grid.
## Each point coordinate is normalized in [0, 1].
## If touched_indices is provided, each newly marked cell index is recorded.
## Returns the count of newly marked cells.
static func _rasterize_polyline(
	grid: PackedByteArray,
	points: PackedVector2Array,
	width: float,
	n: int,
	touched_indices: Variant = null
) -> int:
	if points.is_empty() or width <= 0.0:
		return 0

	var r: float = width * 0.5
	var r2: float = r * r
	var fn: float = float(n)
	var inv_n: float = 1.0 / fn
	var newly_marked: int = 0

	if points.size() == 1:
		var p0: Vector2 = points[0]
		var min_x: int = clampi(int(floor((p0.x - r) * fn)), 0, n - 1)
		var max_x: int = clampi(int(ceil((p0.x + r) * fn)), 0, n - 1)
		var min_y: int = clampi(int(floor((p0.y - r) * fn)), 0, n - 1)
		var max_y: int = clampi(int(ceil((p0.y + r) * fn)), 0, n - 1)

		for y: int in range(min_y, max_y + 1):
			var py: float = (float(y) + 0.5) * inv_n
			var dy: float = py - p0.y
			var dy2: float = dy * dy
			var row_off: int = y * n
			for x: int in range(min_x, max_x + 1):
				var idx: int = row_off + x
				if grid[idx] != 0:
					continue
				var px: float = (float(x) + 0.5) * inv_n
				var dx: float = px - p0.x
				if dx * dx + dy2 <= r2:
					grid[idx] = 1
					newly_marked += 1
					if touched_indices != null:
						touched_indices.append(idx)
		return newly_marked

	for i: int in range(points.size() - 1):
		var ax: float = points[i].x
		var ay: float = points[i].y
		var bx: float = points[i + 1].x
		var by: float = points[i + 1].y
		var abx: float = bx - ax
		var aby: float = by - ay
		var l2: float = abx * abx + aby * aby

		var min_val_x: float = ax if ax < bx else bx
		var max_val_x: float = bx if ax < bx else ax
		var min_val_y: float = ay if ay < by else by
		var max_val_y: float = by if ay < by else ay

		var min_x: int = clampi(int(floor((min_val_x - r) * fn)), 0, n - 1)
		var max_x: int = clampi(int(ceil((max_val_x + r) * fn)), 0, n - 1)
		var min_y: int = clampi(int(floor((min_val_y - r) * fn)), 0, n - 1)
		var max_y: int = clampi(int(ceil((max_val_y + r) * fn)), 0, n - 1)

		if l2 < 1e-8:
			for y: int in range(min_y, max_y + 1):
				var py: float = (float(y) + 0.5) * inv_n
				var dy: float = py - ay
				var dy2: float = dy * dy
				if dy2 > r2:
					continue
				var row_off: int = y * n
				var px: float = (float(min_x) + 0.5) * inv_n
				var dx: float = px - ax
				for x: int in range(min_x, max_x + 1):
					var idx: int = row_off + x
					if grid[idx] == 0 and dx * dx + dy2 <= r2:
						grid[idx] = 1
						newly_marked += 1
						if touched_indices != null:
							touched_indices.append(idx)
					dx += inv_n
			continue

		var inv_l2: float = 1.0 / l2
		var step_dot: float = inv_n * abx
		var px0: float = (float(min_x) + 0.5) * inv_n
		var dx0: float = px0 - ax

		for y: int in range(min_y, max_y + 1):
			var py: float = (float(y) + 0.5) * inv_n
			var dy: float = py - ay
			var dy_aby: float = dy * aby
			var row_off: int = y * n
			var dot_val: float = dx0 * abx + dy_aby
			var dx: float = dx0

			for x: int in range(min_x, max_x + 1):
				var idx: int = row_off + x
				if grid[idx] == 0:
					var t: float = clampf(dot_val * inv_l2, 0.0, 1.0)
					var diff_y: float = dy - aby * t
					var dy2: float = diff_y * diff_y
					if dy2 <= r2:
						var diff_x: float = dx - abx * t
						if diff_x * diff_x + dy2 <= r2:
							grid[idx] = 1
							newly_marked += 1
							if touched_indices != null:
								touched_indices.append(idx)
				dot_val += step_dot
				dx += inv_n

	return newly_marked


static func _extract_polylines(stroke: Variant) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if stroke == null:
		return result
	if stroke is PackedVector2Array:
		if not (stroke as PackedVector2Array).is_empty():
			result.append(stroke as PackedVector2Array)
		return result
	if stroke is Array:
		var arr: Array = stroke as Array
		if arr.is_empty():
			return result
		if arr[0] is Vector2:
			var pv := PackedVector2Array()
			for v: Variant in arr:
				if v is Vector2:
					pv.append(v as Vector2)
			if not pv.is_empty():
				result.append(pv)
			return result
		for item: Variant in arr:
			if item is PackedVector2Array:
				if not (item as PackedVector2Array).is_empty():
					result.append(item as PackedVector2Array)
			elif item is Array:
				var pv := PackedVector2Array()
				for v: Variant in (item as Array):
					if v is Vector2:
						pv.append(v as Vector2)
				if not pv.is_empty():
					result.append(pv)
	return result
