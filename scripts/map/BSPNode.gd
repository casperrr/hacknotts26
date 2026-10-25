extends RefCounted # IM NEW TO GODOT IDK IF I NEED TO BOTHER EXTENDING THIS
class_name BSPNode

var rect:  Rect2i
var left:  BSPNode 
var right: BSPNode
var is_vert := false # True where self is to be split vertically

func _init(r: Rect2i) -> void:
	rect = r

func is_leaf() -> bool:
	return left == null && right == null

func get_leaves() -> Array:
	if is_leaf():
		return [self]
	return left.get_leaves() + right.get_leaves()

func split(rng: RandomNumberGenerator, min_size: int, max_size: int, gap: int) -> void:
	var w := rect.size.x
	var h := rect.size.y
	# Opsec level: Sergio Ramos
	if w <= max_size and h <= max_size:
		return
	
	is_vert = w > h if w != h else rng.randf() < 0.5
	var length  := w if is_vert else h # Where we are cutting across the 'length'; the semantics change to height if we are cutting horiontally across the width
	if length   < min_size * 2 + gap:  # Where min_size denotes the smallest space we can instantiate
		return
	
	var cut := rng.randi_range(min_size, length - min_size - gap) # First piece
	var p   := rect.position
	if is_vert:
		left     = BSPNode.new(Rect2i(p.x, p.y, cut, h))
		right    = BSPNode.new(Rect2i(p.x + cut + gap, p.y, w - cut - gap, h))
	else:
		left     = BSPNode.new(Rect2i(p.x, p.y, w, cut))
		right    = BSPNode.new(Rect2i(p.x, p.y + cut + gap, w, h - cut - gap))

	left.split (rng, min_size, max_size, gap)
	right.split(rng, min_size, max_size, gap)
