extends Node
## The pack's gallery: each prop on its own or all of them laid out, turned with the mouse, its
## animations on buttons. With PSX Look installed (res://addons/psx_look/), they show through it.
## Keys: left / right, 1 to 3 for the animations, A for all, P for PSX Look. A pack with a level
## (props.json's "layout") opens on it (a kit's first prop is a floor tile), shows it on L and
## walks it on W: WASD and the mouse, Shift to run, E to
## open what is in front, F for the torch, Esc to stop. A pack with guns (a held prop's "gun" in
## props.json) has a range on G: its targets downrange, its ammunition on the floor to walk over,
## the guns in hand on the wheel or 1 to 9; left button to fire, right to aim, R to reload. A pack
## of melee weapons and tools (a held prop's "melee") has them on the range too, its targets close:
## left button to swing, right to use (a flashlight lit, a chainsaw started). With first-person arms
## (a view model's "arms" in props.json), the range has them in hand instead: drawn as taken, I to
## inspect. A pack
## of machines (a prop's "use" in props.json, run by its scene's machine.gd) is used with E on foot:
## what the dot is on, taking what it needs from what you carry; the layout's "machines" wire the
## level's ones together (an id, the ids it needs), its lights can need one, and its "puzzle" is
## the uses that get its door open. A pack of pickups (a prop's "pickup", run by its scene's
## pickup.gd) has them taken, saved at or opened the same way, an item held up in inspect.gd as it
## is taken, and a prop's own on I. The layout's "running" names the pieces whose loop plays in the
## level (trees swaying, a fire). With a sky in res://sky/ (a PSX Skyboxes panorama and its fog
## and light, put in the web demo's build), the level is under it, in the layout's "fog" density
## if it gives one (a clear day's thinner than the night woods'), its light (and the sky) turned to
## the layout's "sun" (degrees about the up axis; 180, from the north, if it gives none) and in its
## "light" (a colour and an energy, a desert noon's warmer than the sky's own) if it gives one.

const PSX_LOOK := "res://addons/psx_look/"
const SKY := "res://sky/"
const FLOOR := Color(0.13, 0.12, 0.11)
const WALL := Color(0.2, 0.19, 0.17)
const GAP := 0.05
const WRAP := 24.0  # the widest line of the all-props view
const EYE := 1.6
const STEP := 0.3  # the highest edge the walker steps up
const CUT := 2.9  # the level's view leaves out what stands this high: an upper storey
const BACKSTOP := 16.0  # the range's far wall
const HOLES := 64  # bullet holes kept

## Hides the panel and stops the camera turning on its own, for the store captures.
@export var still := false
## Opens on the first prop. Off for the captures of a set: Godot 4.7 errors on a converted prop's
## scene put up again in the frame after its first instance went.
@export var start := true

var dir: String
var props: Array
var level: Dictionary
var walker: CharacterBody3D
var guns: Array  # what the range puts in hand: the guns, and the melee weapons and tools
var kind := ""  # the group of what is in hand (the weapon's, for arms)
var machines := {}  # the level's, by id
var items: Array = []  # carried
var inspect: CanvasLayer  # a pickups pack's, for what is taken
var prompt := Label.new()
var ranging := false
var view := Node3D.new()  # the gun in hand, under the camera
var gun_node: Node3D
var gun: Dictionary
var loaded := {}  # rounds in each gun, by its name
var spare := {}  # rounds carried, by the ammunition's name
var aim := 0.0  # 0 from the hip, 1 down the sights
var aiming := false
var firing := false
var wait := 0.0  # until the gun fires again
var reloading := 0.0
var reload_time := 1.0
var swinging := 0.0  # left of the swing in hand
var swing_time := 1.0
var struck := false  # this swing's blow has landed
var using := 0.0  # left of the use in hand
var lit := false  # what is in hand is on: its use's first half played
var kick := 0.0
var sway := Vector2.ZERO
var bob := 0.0
var flash := MeshInstance3D.new()
var flash_light := OmniLight3D.new()
var flash_left := 0.0
var holes: Array = []
var hud := CanvasLayer.new()
var scope := ColorRect.new()  # a scope's ring and cross, over the view through it
var ammo_label := Label.new()
var note := Label.new()
var note_left := 0.0
var torch: SpotLight3D
var sun := DirectionalLight3D.new()
var rim := DirectionalLight3D.new()
var moon := DirectionalLight3D.new()  # the sky's, over the level
var night: Dictionary  # res://sky/sky.json: its fog colour, light colour and energy
var index := 0
var all_view := false
var world := Node3D.new()
var shown := Node3D.new()
var cam := Camera3D.new()
var wall := MeshInstance3D.new()
var ground := MeshInstance3D.new()
var env := Environment.new()
var yaw := 0.5
var pitch := -0.4
var rise := 0.2  # how far below its target the camera may go
var dist := 1.0
var target := Vector3.ZERO
var idle := 0.0
var psx_screen: Control
var psx_on := false
var psx_made := {}  # PSX Look material by the material it stands for
var ui := CanvasLayer.new()
var icon := TextureRect.new()
var title := Label.new()
var info := Label.new()
var anim_bar := HBoxContainer.new()
var psx_button := Button.new()


func _ready() -> void:
	dir = (get_script() as Script).resource_path.get_base_dir().get_base_dir()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/props.json"))
	props = data["props"]
	level = data.get("layout", {})
	guns = props.filter(func(p): return p.has("gun") or p.has("melee"))
	var armed := props.filter(func(p): return p.has("arms")).map(func(p): return p["arms"]["holds"])
	guns = guns.filter(func(p): return not (p["name"] in armed))  # a weapon with arms is held in them
	add_child(world)
	_stage()
	world.add_child(shown)
	world.add_child(cam)
	cam.add_child(view)
	_flash()
	cam.current = true
	cam.fov = 40
	_ui()
	if props.any(func(p): return p.has("pickup")):
		inspect = load(dir + "/inspect.gd").new()
		inspect.closed.connect(_inspected)
		add_child(inspect)
	if ResourceLoader.exists(PSX_LOOK + "psx_screen.gd"):
		psx_screen = load(PSX_LOOK + "psx_screen.gd").new()
		psx_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(psx_screen)
		move_child(psx_screen, 0)
		set_psx(true)
	else:
		psx_button.hide()
	if start:  # a pack with a level opens on it: a kit's first prop is a floor tile
		if level.is_empty() or still:
			show_prop(0)
		else:
			show_level()


func _stage() -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.62)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.04, 0.05)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color(1.0, 0.9, 0.75)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	world.add_child(sun)
	rim.rotation_degrees = Vector3(-25, 150, 0)
	rim.light_color = Color(0.5, 0.6, 0.9)
	rim.light_energy = 0.4
	world.add_child(rim)
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.position.y = -0.003  # under a floor piece, not through it
	ground.material_override = _flat(FLOOR)
	world.add_child(ground)
	var quad := QuadMesh.new()
	quad.size = Vector2(40, 6)
	wall.mesh = quad
	wall.position = Vector3(0, 3, -0.002)
	wall.material_override = _flat(WALL)
	world.add_child(wall)
	if FileAccess.file_exists(SKY + "sky.json"):
		night = JSON.parse_string(FileAccess.get_file_as_string(SKY + "sky.json"))
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = load(SKY + "panorama.png")
		mat.filter = false
		env.sky = Sky.new()
		env.sky.sky_material = mat
		var sun: float = level.get("sun", 180.0)
		env.sky_rotation.y = deg_to_rad(sun)
		moon.rotation_degrees = Vector3(-40, sun, 0)
		# brighter than its sky says: out here it is most of the light
		var light: Array = level.get("light", [night["light"], night["energy"] * 2.5])
		moon.light_color = Color(light[0])
		moon.light_energy = light[1]
		moon.shadow_enabled = true
	moon.hide()
	world.add_child(moon)


## The muzzle flash: a six-pointed star drawn here, and its light, up for a frame or two.
func _flash() -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5)
			var v := clampf(1.0 - d.length() / 16.0 / (0.45 + 0.55 * absf(cos(d.angle() * 3.0))), 0, 1)
			img.set_pixel(x, y, Color(1, 0.7 + 0.3 * v, 0.3 + 0.6 * v, v))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_texture = ImageTexture.create_from_image(img)
	flash.mesh = QuadMesh.new()
	flash.mesh.size = Vector2(0.3, 0.3)
	flash.material_override = m
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_light.light_color = Color(1.0, 0.75, 0.4)
	flash_light.light_energy = 6.0
	flash_light.omni_range = 6.0
	for n in [flash, flash_light]:
		n.hide()
		view.add_child(n)
	var key := OmniLight3D.new()  # the gun in hand's own, over the shoulder: the gun is on layer 2
	key.light_cull_mask = 2
	key.position = Vector3(0.35, 0.35, 0.25)
	key.light_color = Color(1.0, 0.93, 0.82)
	key.light_energy = 0.9
	key.omni_range = 2.0
	view.add_child(key)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.0
	return m


func _ui() -> void:
	add_child(ui)
	var top := VBoxContainer.new()
	top.position = Vector2(20, 16)
	ui.add_child(top)
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(icon)
	for l in [title, info]:
		l.add_theme_color_override("font_shadow_color", Color.BLACK)
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		top.add_child(l)
	title.add_theme_font_size_override("font_size", 26)
	info.add_theme_font_size_override("font_size", 15)
	info.modulate = Color(0.85, 0.82, 0.75)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.position.y -= 16
	ui.add_child(bar)
	_button(bar, "<", func() -> void: show_prop(index - 1))
	_button(bar, ">", func() -> void: show_prop(index + 1))
	bar.add_child(anim_bar)
	_button(bar, "All", toggle_all)
	if not level.is_empty():
		_button(bar, "Level", show_level)
		_button(bar, "Walk", walk.bind(true))
	if not guns.is_empty():
		_button(bar, "Range", firing_range.bind(true))
	psx_button.text = "PSX Look"
	psx_button.toggle_mode = true
	psx_button.focus_mode = Control.FOCUS_NONE
	psx_button.toggled.connect(set_psx)
	bar.add_child(psx_button)
	var hint := Label.new()
	hint.text = "drag to turn, wheel to zoom"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.position += Vector2(-16, 16)
	ui.add_child(hint)
	ui.visible = not still
	add_child(hud)
	hud.hide()
	var lens := CanvasLayer.new()
	add_child(lens)
	scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := Shader.new()  # its code set before it goes on a material, or the material keeps none
	ring.code = """shader_type canvas_item;
void fragment() {
	vec2 p = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float d = length(p);
	float line = 0.9 * step(min(abs(p.x), abs(p.y)), mix(0.0022, 0.006, step(0.12, d)));
	COLOR = vec4(0.0, 0.0, 0.0, max(smoothstep(0.43, 0.45, d), line));
}"""
	scope.material = ShaderMaterial.new()
	(scope.material as ShaderMaterial).shader = ring
	scope.hide()
	lens.add_child(scope)
	ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ammo_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.position += Vector2(-24, -20)
	ammo_label.add_theme_font_size_override("font_size", 24)
	note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	note.position.y -= 90
	var dot := ColorRect.new()
	dot.name = "Dot"
	dot.color = Color(1, 1, 1, 0.7)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)
	var keys := Label.new()
	keys.name = "Keys"
	var melee := guns.any(func(g): return g.has("melee"))
	keys.text = ("left button swing, right use" if melee else "left button fire, right aim, R reload") \
			+ ", wheel or 1-%d %s%s, F torch, Esc out" % [mini(9, guns.size()), "to change" if melee else "guns",
					", I inspect" if guns.any(func(g): return g.has("arms")) else ""]
	keys.position = Vector2(20, 16)
	keys.modulate = Color(1, 1, 1, 0.5)
	keys.visible = not still
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.position.y += 40
	prompt.modulate = Color(1, 1, 1, 0.8)
	for c in [ammo_label, note, keys, prompt]:
		c.add_theme_color_override("font_shadow_color", Color.BLACK)
		c.add_theme_constant_override("shadow_offset_x", 2)
		c.add_theme_constant_override("shadow_offset_y", 2)
	for c in [ammo_label, note, dot, keys, prompt]:
		hud.add_child(c)


func _button(box: Container, text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = 44
	b.pressed.connect(pressed)
	box.add_child(b)
	return b


## Shows the prop at `i` (wrapping round) alone, framed.
func show_prop(i: int) -> void:
	index = posmod(i, props.size())
	all_view = false
	_clear()
	_dark(false)
	var p: Dictionary = props[index]
	var held: bool = p["place"] == "hand"
	var lift := Vector3(0, 0.2 - p["min"][2], 0) if held else Vector3.ZERO  # upright in the air, room below for a magazine to drop
	_place(p, lift)
	var lo := _gd(p["min"]) + lift
	var hi := _gd(p["max"]) + lift
	var box := AABB(lo, Vector3.ZERO).expand(hi)
	ground.position.y = minf(lo.y, 0.0) - 0.003  # under a piece sunk into the floor (a pool's), not over it
	target = box.get_center()
	dist = maxf(0.12, box.size.length() * 0.5 / sin(deg_to_rad(cam.fov * 0.5)) * 1.15)
	var hung: bool = lo.y > 1.5 and p["place"] != "wall"  # a ceiling and what hangs from it: seen from below
	pitch = 0.35 if hung else (-0.75 if box.size.y < 0.1 else -0.3)
	rise = 0.8 if hung else 0.2
	yaw = 0.5
	wall.visible = p["place"] == "wall" or held
	if held:  # from the right, where a gun's ejection port is: its side filling the view, before the
		# wall and lit from over the camera's shoulder
		pitch = -0.12
		yaw = -1.35
		cam.fov = 20  # long, so a gun's near and far ends are drawn to one scale
		var t := tan(deg_to_rad(cam.fov * 0.5))
		dist = maxf(box.size.z / cam.get_viewport().get_visible_rect().size.aspect(), box.size.y) * 0.5 / t * 1.2
		var back := Basis.from_euler(Vector3(0, yaw, 0))
		wall.basis = back
		wall.position = Vector3(target.x, 3, target.z) - back.z * maxf(0.3, box.size.z * 0.6)
		sun.rotation = Vector3(-0.6, yaw + 0.6, 0)
	var icon_path := "%s/icons/%s.png" % [dir, p["name"]]
	icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	icon.visible = icon.texture != null
	title.text = p["title"]
	info.text = "%s  |  %d / %d  |  %d triangles  |  %s m\n%s" % [
		p["group"].capitalize(), index + 1, props.size(), p["tris"], _size(p["size"]), p["note"]]
	for b in anim_bar.get_children():
		b.queue_free()
	for a in p["anims"]:
		_button(anim_bar, a["name"], func() -> void: play(a["name"]))
	if p.has("pickup") and inspect:
		_button(anim_bar, "Inspect", inspect_shown)
		info.text += ("  |  " if p["note"] else "") + "I to inspect"


## The shown prop held up in the inspect view.
func inspect_shown() -> void:
	if inspect and not all_view and shown.get_child_count() > 0:
		inspect.lines = 240 if psx_on else 0
		inspect.open(shown.get_child(0))
		_convert(inspect.item)


## The first placed `name` (or, if none is, the prop on its own) held up in the inspect view; with
## `reveal`, its reveal played through: for a capture.
func inspect_prop(name: String, reveal := false) -> void:
	var node: Node3D
	for n in shown.get_children():
		if n.has_meta("prop") and n.get_meta("prop")["name"] == name:
			node = n
			break
	if not node:
		var names: Array = props.map(func(p): return p["name"])
		node = _place(props[names.find(name)], Vector3(0, -100, 0))
	inspect.lines = 240 if psx_on else 0
	inspect.open(node)
	_convert(inspect.item)
	if reveal:
		inspect.reveal_now()


func _inspected() -> void:
	if walker and not still:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Every prop at once: the wall props on the wall, the floor props before it and the small
## items and held ones in front, a cluster per group.
func show_all() -> void:
	all_view = true
	_clear()
	_dark(false)
	for b in anim_bar.get_children():
		b.queue_free()
	var rows := {"wall": [], "floor": [], "item": []}
	for p in props:
		rows["item" if p["place"] == "hand" else p["place"]].append(p)
	var wall_width := _row(rows["wall"], 0.0, 0.18, true).x
	var floor_size := _row(rows["floor"], 0.3, 0.25)
	var groups: Array = []
	var by_group := {}
	for p in rows["item"]:
		if p["group"] not in by_group:
			by_group[p["group"]] = []
			groups.append(p["group"])
		by_group[p["group"]].append(p)
	var clusters: Array = []
	for g in groups:
		clusters.append(_cluster(by_group[g]))
	var per_row := maxi(1, ceili(clusters.size() / 2.0))
	var z := 0.3 + floor_size.y + 0.6
	var width := maxf(wall_width, floor_size.x)
	for r in range(0, clusters.size(), per_row):
		var line := clusters.slice(r, r + per_row)
		var line_width := 0.0
		var depth := 0.0
		for c in line:
			line_width += c.get_meta("size").x + 0.25
			depth = maxf(depth, c.get_meta("size").y)
		width = maxf(width, line_width)
		var x := -line_width * 0.5
		for c in line:
			c.position = Vector3(x, 0, z)
			x += c.get_meta("size").x + 0.25
		z += depth + 0.35
	wall.visible = true
	(ground.mesh as PlaneMesh).size = Vector2(maxf(40, width + 4), maxf(40, 2 * z + 4))
	target = Vector3(0, 0.45, z * 0.45)
	dist = maxf(5.2, maxf(width, z) * 0.75)
	pitch = -0.42
	yaw = 0.0
	icon.hide()
	title.text = "All %d props" % props.size()
	info.text = "%d triangles in all" % props.reduce(func(s, p): return s + p["tris"], 0)


func toggle_all() -> void:
	if all_view:
		show_prop(index)
	else:
		show_all()


## Props laid out as given: [name, [x, y, z] in metres, turn in degrees], for a composed shot.
func show_set(items: Array) -> void:
	all_view = true
	_clear()
	_dark(false)
	var named := {}
	for p in props:
		named[p["name"]] = p
	for it in items:
		var p: Dictionary = named[it[0]]
		var n := _place(p, Vector3(it[1][0], it[1][1], it[1][2]))
		n.rotation_degrees.y = it[2] if it.size() > 2 else 0.0
		if p["place"] == "hand":
			_lay(n, p)
	wall.visible = true


## The level: its pieces where the layout puts them ([name, [x, y, z] in Blender's metres, turn in
## degrees]) and its lights, in the dark; as a plan, lit enough to read from above and without its
## upper storey.
func show_level(plan := true) -> void:
	all_view = true
	_clear()
	_dark(true)
	for b in anim_bar.get_children():
		b.queue_free()
	var named := {}
	for p in props:
		named[p["name"]] = p
	var box := AABB()
	var placed: Array = []
	for it in level["pieces"]:
		var n := _place(named[it[0]], _gd(it[1]))
		n.rotation_degrees.y = it[2]
		n.visible = not plan or it[1][2] < CUT
		box = box.expand(n.position)
		placed.append(n)
		if it[0] in level.get("running", []):  # its loop plays, each from its own point in it
			var a: Dictionary = named[it[0]]["anims"].filter(func(x): return x["loop"])[0]
			var player := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
			player.play(a["name"])
			player.seek(fposmod(n.position.x * 0.37 + n.position.z * 0.61, 1.0) * a["seconds"], true)
	machines = {}
	items = []
	for m in level.get("machines", []):
		machines[m["id"]] = placed[m["piece"]]
	for m in level.get("machines", []):
		machines[m["id"]].wire(m.get("needs", []).map(func(id): return machines[id]))
		machines[m["id"]].refused.connect(_refused)
		machines[m["id"]].picked.connect(_picked)
	for n in placed:
		if n.has_signal("saved"):  # a pickup
			if not n.refused.is_connected(_refused):
				n.refused.connect(_refused)
				n.picked.connect(_picked)
			n.saved.connect(_saved.bind(n))
	for l in level.get("lights", []):
		var o := OmniLight3D.new()
		o.position = _gd(l["at"])
		o.light_color = Color(l["color"][0], l["color"][1], l["color"][2])
		o.light_energy = l["energy"]
		o.omni_range = l["range"]
		o.set_meta("energy", o.light_energy)
		o.set_meta("flicker", l.get("flicker", false))
		shown.add_child(o)
		if l.has("needs"):  # on while its machine is live
			var m: Node = machines[l["needs"]]
			o.visible = m.live
			m.live_changed.connect(o.set_visible)
	if plan:
		env.ambient_light_energy = 0.5
		env.fog_density = 0.01
	target = box.get_center()
	dist = box.size.length() * 0.75
	pitch = -1.0
	yaw = 0.3
	icon.hide()
	title.text = "The demo level"
	info.text = "%d pieces, %d lights. Walk (W) to go in" % [level["pieces"].size(), level.get("lights", []).size()]


## Into the level on foot at the layout's `start` ([x, y, z, turn]), or back out to the view.
func walk(on: bool) -> void:
	if on == (walker != null) or level.is_empty():
		return
	if on:
		show_level(false)
		_on_foot(_gd(level["start"]), deg_to_rad(level["start"][3]) + PI)
		if not machines.is_empty():
			hud.show()
			hud.get_node("Keys").hide()
			ammo_label.text = ""
			_say(level.get("puzzle", {}).get("goal", ""), 8.0)
	else:
		_off_foot()
		show_level()


func _on_foot(at: Vector3, turn: float) -> void:
	walker = CharacterBody3D.new()
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.75
	body.shape = capsule
	body.position.y = capsule.height / 2
	walker.add_child(body)
	walker.floor_snap_length = STEP
	walker.position = at
	yaw = turn
	pitch = 0.0
	world.add_child(walker)
	torch = SpotLight3D.new()
	torch.spot_range = 14.0
	torch.spot_angle = 24.0
	torch.light_energy = 2.0
	torch.shadow_enabled = true
	torch.visible = false
	cam.add_child(torch)
	if not still:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ui.hide()


func _off_foot() -> void:
	hud.hide()
	walker.queue_free()
	walker = null
	torch.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.visible = not still


## The range, on foot with a gun (or a melee weapon) in hand, or back out to the prop. With no guns,
## the booths and their shelf are left out and the targets stand close, to walk up to and strike.
func firing_range(on: bool) -> void:
	if on == ranging or guns.is_empty():
		return
	if walker:
		_off_foot()
	if not on:
		ranging = false
		firing = false
		aiming = false
		hud.hide()
		scope.hide()
		gun_node.queue_free()
		gun_node = null
		flash.hide()
		flash_light.hide()
		show_prop(index)
		return
	all_view = true
	ranging = true
	_clear()
	hud.get_node("Keys").show()
	_dark(false)
	for b in anim_bar.get_children():
		b.queue_free()
	var shooting := guns.any(func(g): return g.has("gun"))
	_range_room(shooting)
	var named := {}
	for p in props:
		named[p["name"]] = p
	var targets := props.filter(func(p): return p["group"] == "targets")
	var spots := [Vector3(-0.3, 0, -5.5), Vector3(1.7, 0, -7.5), Vector3(-1.8, 0, -9), Vector3(0.8, 0, -11.5), Vector3(-3.0, 0, -13)] \
			if shooting else [Vector3(0.0, 0, -0.1), Vector3(1.9, 0, -1.2), Vector3(-1.9, 0, -1.6), Vector3(0.9, 0, -3.4), Vector3(-1.0, 0, -4.4)]
	for k in spots.size() if targets else 0:
		_place(targets[k % targets.size()], spots[k]).rotation.y = 0.0 if shooting else -0.25 * spots[k].x
	if "ammo_crate" in named:
		_place(named["ammo_crate"], Vector3(3.2, 0, 3.2)).rotation_degrees.y = -20
	loaded = {}
	spare = {}
	var ammo: Array = []
	for g in guns.filter(func(x): return x.has("gun")):
		var a: String = g["gun"]["ammo"]
		loaded[g["name"]] = g["gun"]["rounds"]
		spare[a] = maxi(spare.get(a, 0), g["gun"]["rounds"] * 2)
		if a in named and a not in ammo:
			ammo.append(a)
	for k in ammo.size():  # on the floor behind the booths, to walk over; back after a while
		var n := _place(named[ammo[k]], Vector3((k - (ammo.size() - 1) / 2.0) * 0.6, 0, 2.6))
		n.rotation_degrees.y = 25.0 * sin(k * 2.3)
		n.set_meta("ammo", ammo[k])
		n.set_meta("amount", spare[ammo[k]])
	holes.clear()
	_on_foot(Vector3(0, 0, 1.2), 0.0)
	hud.show()
	equip(0)


## The level's puzzle solved, as its "uses" say ([machine id, part] each, an item's id to pick it
## up), everything moved to where it ends: for a capture.
func solve() -> void:
	for u in level["puzzle"]["uses"]:
		var use: Array = u if u is Array else [u, ""]
		machines[use[0]].use(items, use[1])
		for i in 3:  # a slot's item, a lever's clip, the door they open
			for m in machines.values():
				m.settle()


func _refused(why: String) -> void:
	match why:
		"power":
			_say("No power")
		"code":
			_say("Wrong code")
		_:
			_say("It needs the %s" % _title(why).to_lower())


func _picked(item: String) -> void:
	_say("Picked up the %s" % _title(item).to_lower())
	ammo_label.text = _carried()


func _saved(at: Node) -> void:
	_say("The game is saved" + (" (%d %s left)" % [items.count(at.takes), _title(at.takes).to_lower()] if at.takes else ""))
	ammo_label.text = _carried()


## What is carried, a line each, with how many where more than one.
func _carried() -> String:
	var lines: Array = []
	for it in items:
		var line: String = _title(it) + ("  x%d" % items.count(it) if items.count(it) > 1 else "")
		if line not in lines:
			lines.append(line)
	return "\n".join(lines)


func _title(item: String) -> String:
	for p in props:
		if p.get("use", {}).get("item", "") == item:
			return p["title"]
		if p.get("pickup", {}).get("item", "") == item:
			return p["pickup"].get("title", p["title"])
	return item.capitalize()


func _say(text: String, seconds := 2.5) -> void:
	note.text = text
	note_left = seconds


## An indoor range: booths at the firing line (z 0), for `shooting`, and lanes down to a backstop,
## lit by fluorescent tubes between the baffles under its ceiling.
func _range_room(shooting := true) -> void:
	const W := 4.0  # half its width
	const H := 3.0
	ground.visible = false
	wall.visible = false
	sun.visible = false
	rim.visible = false
	env.ambient_light_energy = 0.55
	var stops := StaticBody3D.new()  # walls, floor and ceiling, for the walker and the shots
	for plane in [Plane(Vector3.UP, 0), Plane(Vector3.DOWN, -H), Plane(Vector3.BACK, -BACKSTOP), Plane(Vector3.RIGHT, -W),
			Plane(Vector3.LEFT, -W), Plane(Vector3.FORWARD, -4)]:
		var s := CollisionShape3D.new()
		s.shape = WorldBoundaryShape3D.new()
		s.shape.plane = plane
		stops.add_child(s)
	shown.add_child(stops)
	var mid := (4.0 - BACKSTOP) / 2
	var long := 4.0 + BACKSTOP
	_block(Vector3(2 * W, 0.02, long), Vector3(0, -0.01, mid), Color(0.34, 0.33, 0.31))  # concrete
	_block(Vector3(2 * W, 0.005, 0.1), Vector3(0, 0.002, -0.05), Color(0.85, 0.7, 0.1))  # the firing line
	_block(Vector3(2 * W, 0.02, long), Vector3(0, H + 0.01, mid), Color(0.14, 0.14, 0.15))
	for x in [-W, W]:
		_block(Vector3(0.02, H, long), Vector3(x, H / 2, mid), Color(0.46, 0.45, 0.41))  # block walls
		_block(Vector3(0.03, 1.0, long), Vector3(x, 0.5, mid), Color(0.26, 0.31, 0.29))  # painted below
	_block(Vector3(2 * W, H, 0.02), Vector3(0, H / 2, 4.0), Color(0.46, 0.45, 0.41))
	_block(Vector3(2 * W, H, 0.3), Vector3(0, H / 2, -BACKSTOP), Color(0.1, 0.09, 0.08))  # rubber backstop
	_block(Vector3(2 * W, 0.6, 1.2), Vector3(0, H - 0.3, -BACKSTOP + 0.6), Color(0.16, 0.15, 0.14))  # its hood
	for x in [-2.6, -1.0, 1.0, 2.6] if shooting else []:  # booth partitions and the shelf across them
		_block(Vector3(0.06, 1.7, 1.0), Vector3(x, 0.85, 0.5), Color(0.2, 0.23, 0.23), true)
	if shooting:
		_block(Vector3(2 * W, 0.05, 0.35), Vector3(0, 1.0, 0.18), Color(0.22, 0.19, 0.16), true)
	for z in range(-2, -int(BACKSTOP), -3):  # baffles
		_block(Vector3(2 * W, 0.5, 0.12), Vector3(0, H - 0.25, z), Color(0.24, 0.23, 0.22))
	for z in [2.4, -0.5, -3.5, -6.5, -9.5, -12.5]:  # tubes, and a light for each (the web renderer takes 8 a mesh)
		for x in ([-1.8, 1.8] if z > 0 else [-1.4, 1.4]):
			_block(Vector3(1.2, 0.06, 0.2), Vector3(x, H - 0.4, z), Color(1.0, 0.96, 0.85), false, true)
			_block(Vector3(1.3, 0.04, 0.26), Vector3(x, H - 0.35, z), Color(0.3, 0.3, 0.3))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, H - 0.5, z)
		lamp.light_color = Color(1.0, 0.95, 0.85)
		lamp.light_energy = 0.9 if z > 0 else 1.2
		lamp.omni_range = 6.0
		lamp.omni_attenuation = 0.8
		shown.add_child(lamp)


## A box of flat colour in the shown set: `solid` to stand in the way, `lit` to glow.
func _block(size: Vector3, at: Vector3, c: Color, solid := false, lit := false) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mat := _flat(c)
	if lit:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var m := MeshInstance3D.new()
	m.mesh = box
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at
	shown.add_child(m)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = size
		body.add_child(shape)
		m.add_child(body)


## Takes the gun at `i` (wrapping round) in hand.
func equip(i: int) -> void:
	if gun_node:
		gun_node.queue_free()
	gun = guns[posmod(i, guns.size())]
	gun_node = _place(gun, Vector3.ZERO, view)
	for body in gun_node.find_children("*", "StaticBody3D", true, false):
		body.free()
	for mi in gun_node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).layers = 2
	if "glint" in gun_node:  # a pickup's
		gun_node.glint = false
	kind = gun["group"]
	if gun.has("arms"):
		kind = props.filter(func(p): return p["name"] == gun["arms"]["holds"])[0]["group"]
		(gun_node.find_child("AnimationPlayer", true, false) as AnimationPlayer).play(gun["arms"]["draw"])
	reloading = 0.0
	swinging = 0.0
	using = 0.0
	lit = false
	wait = 0.2
	kick = 0.0
	flash.scale = Vector3.ONE * (1.3 if kind in ["shotguns", "launchers"] else 1.0)
	_hud()


## Fires the gun in hand: a round from it, its "fire" animation and its "cycle" after, a flash and
## a kick; a ray from the middle of the view (a spread of pellets from a shotgun) leaves a hole where
## it lands, and a target plays its animation. Empty, it reloads. A melee weapon swings.
func shoot() -> void:
	if gun.has("melee"):
		swing()
		return
	var g: Dictionary = gun["gun"]
	if loaded[gun["name"]] <= 0:
		reload()
		return
	loaded[gun["name"]] -= 1
	var player := gun_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var length := player.get_animation(g["fire"]).length
	var speed := maxf(1.0, length * g["rate"]) if g.get("auto", false) else 1.0
	player.stop()
	player.play(g["fire"], -1, speed)
	wait = length / speed
	if g.has("cycle") and loaded[gun["name"]] > 0:
		player.queue(g["cycle"])
		wait += player.get_animation(g["cycle"]).length
	flash_left = 0.06
	flash.rotation.z = randf() * TAU
	kick = 1.0
	pitch += 0.03 if kind in ["shotguns", "launchers"] else 0.012
	var pellets := 8 if kind == "shotguns" else 1
	var spread := lerpf(0.025, 0.003, aim) + (0.035 if pellets > 1 else 0.0)
	for k in pellets:
		_bullet(spread)
	_hud()


func _bullet(spread: float) -> void:
	var b := cam.global_basis
	var to := (-b.z + b.x * randfn(0, spread) + b.y * randfn(0, spread)).normalized()
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + to * 60.0)
	q.exclude = [walker.get_rid()]
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_mark(hit, Vector2(0.025, 0.025), Color(0.03, 0.03, 0.03))


## A mark of `size` where `hit` (a ray's) landed, turned `turn` about it, and a target struck
## plays its animation.
func _mark(hit: Dictionary, size: Vector2, c: Color, turn := 0.0) -> void:
	var body: Node3D = hit["collider"]
	var hole := MeshInstance3D.new()
	hole.mesh = QuadMesh.new()
	hole.mesh.size = size
	hole.material_override = _flat(c)
	body.add_child(hole)
	var n: Vector3 = hit["normal"]
	hole.global_transform = Transform3D(Basis(n, turn) * Basis.looking_at(-n, Vector3.RIGHT if absf(n.y) > 0.9 else Vector3.UP),
			hit["position"] + n * 0.003)
	holes.append(hole)
	if holes.size() > HOLES:
		var old: Node = holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var prop: Node = body
	while prop and not prop.has_meta("prop"):
		prop = prop.get_parent()
	if prop and prop.get_meta("prop")["group"] == "targets" and not prop.get_meta("prop")["anims"].is_empty():
		var player := prop.find_child("AnimationPlayer", true, false) as AnimationPlayer
		player.stop()
		player.play(prop.get_meta("prop")["anims"][0]["name"])


## Fills the gun in hand from what is carried, through its "reload" animation, or a dip of the gun.
func reload() -> void:
	var g: Dictionary = gun["gun"]
	if reloading > 0 or loaded[gun["name"]] >= g["rounds"] or spare.get(g["ammo"], 0) <= 0:
		return
	var player := gun_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	reload_time = 1.2
	if g.has("reload"):
		player.stop()
		player.play(g["reload"])
		reload_time = player.get_animation(g["reload"]).length
	reloading = reload_time


func _reloaded() -> void:
	var g: Dictionary = gun["gun"]
	var take := mini(g["rounds"] - loaded[gun["name"]], spare[g["ammo"]])
	loaded[gun["name"]] += take
	spare[g["ammo"]] -= take
	_hud()


func _hud() -> void:
	if gun.has("melee"):
		ammo_label.text = gun["title"] + ("\non" if lit else "")
		return
	var g: Dictionary = gun["gun"]
	ammo_label.text = "%s\n%d  /  %d" % [gun["title"], loaded[gun["name"]], spare.get(g["ammo"], 0)]


## Swings the melee weapon in hand: its swing animation, its blow landing `hit` of the way through.
func swing() -> void:
	var m: Dictionary = gun["melee"]
	if not m.has("swing") or swinging > 0 or using > 0:
		return
	var player := gun_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.stop()
	player.play(m["swing"])
	swing_time = player.get_animation(m["swing"]).length
	swinging = swing_time
	struck = false


## The blow: a ray `reach` long down the middle of the view, a gash from an edge or a dent from the
## rest where it lands, and a shake.
func _blow() -> void:
	var q := PhysicsRayQueryParameters3D.create(cam.global_position,
			cam.global_position - cam.global_basis.z * float(gun["melee"]["reach"]))
	q.exclude = [walker.get_rid()]
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	if kind in ["blades", "tools", "axes", "polearms"]:
		_mark(hit, Vector2(0.11, 0.012), Color(0.09, 0.03, 0.03), randf_range(-0.5, 0.5) + PI / 4)
	else:
		_mark(hit, Vector2(0.045, 0.045), Color(0.1, 0.1, 0.1))
	kick = 0.6


## Uses what is in hand: its use animation; with `toggle`, the half of it that turns it on or off,
## its light, glowing parts and running loop going with it.
func use_held() -> void:
	var m: Dictionary = gun.get("melee", {})
	if not m.has("use") or swinging > 0 or using > 0:
		return
	var player := gun_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var length := player.get_animation(m["use"]).length
	player.stop()
	player.play(m["use"])
	using = length
	if m.get("toggle", false):
		if lit:
			player.seek(length / 2, true)
		using = length / 2


## The use done: a toggle's half held where it ends, and what goes on or off with it.
func _used() -> void:
	var m: Dictionary = gun["melee"]
	if not m.get("toggle", false):
		return
	var player := gun_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	lit = not lit
	if lit:
		player.pause()
		if m.has("run"):
			player.play(m["run"])
	var light := gun_node.find_child("Light", true, false) as Light3D
	if light:
		light.visible = lit
	for part in m.get("glow", []):
		var mi := gun_node.find_child(part, true, false) as MeshInstance3D
		var glow: BaseMaterial3D
		if lit:
			glow = (mi.mesh.surface_get_material(0) as BaseMaterial3D).duplicate()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = glow
	_hud()


func _range_tick(delta: float) -> void:
	wait -= delta
	if using > 0:
		using -= delta
		if using <= 0:
			_used()
	if swinging > 0:
		swinging -= delta
		if not struck and 1.0 - swinging / swing_time >= gun["melee"]["hit"]:
			struck = true
			_blow()
		if swinging <= 0 and lit and gun["melee"].has("run"):
			(gun_node.find_child("AnimationPlayer", true, false) as AnimationPlayer).play(gun["melee"]["run"])
	if reloading > 0:
		reloading -= delta
		if reloading <= 0:
			_reloaded()
	elif firing and wait <= 0 and swinging <= 0:
		shoot()
		firing = firing and gun.get("gun", gun.get("melee", {})).get("auto", false)
	for n in shown.get_children():
		if not n.has_meta("ammo"):
			continue
		if n.has_meta("back"):
			n.set_meta("back", n.get_meta("back") - delta)
			if n.get_meta("back") <= 0:
				n.remove_meta("back")
				n.show()
		elif Vector2(n.position.x - walker.position.x, n.position.z - walker.position.z).length() < 0.6:
			spare[n.get_meta("ammo")] += n.get_meta("amount")
			n.hide()
			n.set_meta("back", 10.0)
			note.text = "+%d  %s" % [n.get_meta("amount"), n.get_meta("prop")["title"]]
			note_left = 2.0
			_hud()


## The gun in hand: from the hip or down its sights, swaying with the mouse, bobbing with the walk
## and kicking with a shot.
func _viewmodel(delta: float) -> void:
	aim = move_toward(aim, 1.0 if aiming else 0.0, delta * 6.0)
	kick = move_toward(kick, 0.0, delta * 7.0)
	sway = sway.lerp(Vector2.ZERO, minf(1.0, delta * 8.0))
	var speed := Vector2(walker.velocity.x, walker.velocity.z).length()
	bob += delta * speed * 3.2
	var step := Vector3(cos(bob) * 0.008, -absf(sin(bob)) * 0.01, 0) * minf(1.0, speed) * (1.0 - aim * 0.8)
	note_left -= delta
	note.visible = note_left > 0
	if gun.has("arms"):
		_arms(step, delta)
		return
	if gun.has("melee"):
		_held(step)
		return
	var s := _gd(gun["gun"]["sight"])
	# turned round, its sight under the middle of the view: at arm's length for a handgun; a long gun
	# held a hand ahead of its butt and low enough to see over its stock
	var handgun: bool = gun["group"] == "handguns"
	var eye := 0.45 if handgun else maxf(0.3, s.z + gun["max"][1] - 0.12)
	var aimed := Vector3(-s.x, -s.y - (0.012 if handgun else 0.04), -eye + s.z)
	var hip := aimed + (Vector3(0.16, -0.13, -0.06) if handgun else Vector3(0.26, -0.2, -0.2))
	var dip := sin(clampf(1.0 - reloading / reload_time, 0, 1) * PI) if reloading > 0 and not gun["gun"].has("reload") else 0.0
	gun_node.position = hip.lerp(aimed, aim) + step + Vector3(sway.x, sway.y - dip * 0.08, kick * 0.04)
	# from the hip turned in a little toward the middle and canted, so its side and top both show
	var turn := (1.0 - aim) * Vector3(0.05, 0.22, 0.12)
	gun_node.rotation = turn + Vector3(-kick * 0.12 + dip * 0.6 + sway.y * 2.0, PI - sway.x * 2.0, dip * 0.4)
	_sights()
	flash_left -= delta
	flash.visible = flash_left > 0
	flash_light.visible = flash.visible
	flash.position = gun_node.transform * (_gd(gun["gun"]["muzzle"]) + Vector3(0, 0, 0.05))
	flash_light.position = flash.position


## First-person arms in the eye, swaying and bobbing, their idle playing between the rest; to aim,
## a gun's bore turned down the view and its sight brought to the middle.
func _arms(step: Vector3, delta: float) -> void:
	var player := gun_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not player.is_playing() and not lit:
		player.play(gun["arms"]["idle"])
	var s := _gd(gun["gun"]["sight"]) if gun.has("gun") else Vector3.ZERO
	var turn := Basis.IDENTITY
	if gun.has("gun") and gun["gun"].has("bore"):
		turn = Basis(Quaternion.IDENTITY.slerp(Quaternion(_gd(gun["gun"]["bore"]).normalized(), Vector3.BACK), aim))
	var sight := Basis(Vector3.UP, PI) * turn * s
	gun_node.position = Vector3(-sight.x, -sight.y - 0.01, -0.06) * aim + step + Vector3(sway.x, sway.y, 0)
	gun_node.basis = Basis.from_euler(Vector3(sway.y * 2.0, PI - sway.x * 2.0, 0)) * turn
	_sights()
	flash_left -= delta
	flash.visible = flash_left > 0 and gun.has("gun")
	flash_light.visible = flash.visible
	if gun.has("gun"):
		flash.position = gun_node.transform * (_gd(gun["gun"]["muzzle"]) + Vector3(0, 0, 0.05))
		flash_light.position = flash.position


## Down a gun's sights, or through its scope (`scope` its power) once raised: the view narrowed by
## the power, the gun out of it and the scope's ring and cross over it.
func _sights() -> void:
	var power: float = gun["gun"].get("scope", 0.0) if gun.has("gun") else 0.0
	var scoped := power > 0.0 and aim > 0.9
	scope.visible = scoped
	gun_node.visible = not scoped
	cam.fov = 50.0 / power if scoped else lerpf(70.0, 50.0, aim)
	hud.get_node("Dot").visible = aim < 0.5


## The arms in hand turn what they hold over to look at it.
func inspect_held() -> void:
	if gun.has("arms") and reloading <= 0 and swinging <= 0 and using <= 0 and not lit:
		var player := gun_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		player.stop()
		player.play(gun["arms"]["inspect"])


## A melee weapon or tool in hand, low at the right: one longer than tall (a knife, a flashlight, a
## chainsaw) held point forward; a small one (a lighter) up, its face to you; the rest head up,
## leaning away and in, its side to you; dipping across the view as it swings.
func _held(step: Vector3) -> void:
	var size: Array = gun["size"]
	var arc := sin(clampf(1.0 - swinging / swing_time, 0, 1) * PI) if swinging > 0 else 0.0
	var at := Vector3(0.3, -0.45, -0.4)
	var lean := Vector3(0.65, 0.35, -0.1)
	var lift := Vector3(-0.2, 0.24, -0.05)  # the hand's, at the height of a swing: up and across
	if size.max() < 0.1:
		at = Vector3(0.12, -0.14, -0.3)
		lean = Vector3(0.1, PI - 0.5, 0)
	elif size[1] > size[2]:
		at = Vector3(0.16, -0.19, -0.32)
		lean = Vector3(0.05, 0.08, 0.1)
		lift = Vector3(-0.08, 0.04, 0)
	gun_node.position = at + step + lift * arc + Vector3(sway.x, sway.y, kick * 0.03)
	gun_node.rotation = lean + Vector3(sway.y * 2.0, PI - sway.x * 2.0, arc * 0.3)
	cam.fov = 70.0
	hud.get_node("Dot").visible = true
	scope.hide()
	flash.visible = false
	flash_light.visible = false


## Uses the machine the dot is on; or opens (or shuts) the nearest thing in front that moves: a door
## plays its animation to the half, where it stands open, and on from there to shut; a loop starts
## or stops.
func use() -> void:
	var ray := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 2.2)
	ray.exclude = [walker.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	var node: Node = hit.get("collider")
	while node and not node.has_meta("prop"):
		node = node.get_parent()
	if node and node.has_method("use"):
		if node.use(items, String(hit["collider"].get_parent().name)) and inspect and node.has_signal("saved") \
				and node.kind == "item":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			inspect.lines = 240 if psx_on else 0
			inspect.open(node)
			_convert(inspect.item)
		ammo_label.text = _carried()
		return
	var fwd := -cam.global_basis.z
	fwd = Vector3(fwd.x, 0, fwd.z).normalized()
	var best: Node3D
	var near := 2.0
	for n in shown.get_children():
		if not n.has_meta("prop") or n.get_meta("prop")["anims"].is_empty() or n.has_method("use"):
			continue
		var to: Vector3 = n.global_position - walker.global_position
		to.y = 0
		if to.length() < near and (to.length() < 0.6 or to.normalized().dot(fwd) > 0.4):
			best = n
			near = to.length()
	if not best:
		return
	var a: Dictionary = best.get_meta("prop")["anims"][0]
	var player := best.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if a["loop"]:
		if player.is_playing():
			player.stop()
		else:
			player.play(a["name"])
	elif player.is_playing():
		return
	elif best.get_meta("open", false):
		player.play(a["name"])
		best.set_meta("open", false)
	else:
		player.play(a["name"])
		player.seek(0.0, true)
		best.set_meta("stop", a["seconds"] / 2.0)
		best.set_meta("open", true)


## What E would do to the pickup the dot is on, if it is on one.
func _prompt() -> String:
	var ray := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 2.2)
	ray.exclude = [walker.get_rid()]
	var node: Node = world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider")
	while node and not node.has_meta("prop"):
		node = node.get_parent()
	if not node or not node.has_signal("saved") or not node.visible:
		return ""
	match node.kind:
		"save":
			return "E  Save" + (" (an %s)" % _title(node.takes).to_lower() if node.takes else "")
		"storage":
			return "E  Shut it" if node.live else "E  Open it"
	return "E  Take the %s" % (node.title if node.title else node.get_meta("prop")["title"]).to_lower()


func _dark(on: bool) -> void:
	sun.visible = not on
	rim.visible = not on
	ground.visible = not on
	wall.visible = not on
	env.ambient_light_energy = 0.12 if on else 0.7
	env.fog_density = 0.07 if on else 0.04
	cam.fov = 62 if on else 40  # wide, in the rooms
	rise = 0.2
	var sky := on and not night.is_empty()
	moon.visible = sky
	if sky:  # out of doors: the moon lights it, and the fog lets the trees be seen further
		env.ambient_light_energy = 0.3
		env.fog_density = level.get("fog", 0.045)
	env.background_mode = Environment.BG_SKY if sky else Environment.BG_COLOR
	env.fog_light_color = Color(night["fog"]) if sky else Color(0.04, 0.04, 0.05)
	env.fog_sky_affect = 0.0 if sky else 1.0


func _physics_process(delta: float) -> void:
	if not walker:
		return
	var move := Vector3(_key(KEY_D, KEY_RIGHT) - _key(KEY_A, KEY_LEFT), 0, _key(KEY_S, KEY_DOWN) - _key(KEY_W, KEY_UP))
	if inspect and inspect.showing:
		move = Vector3.ZERO
	var speed := 4.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 2.2
	move = Basis(Vector3.UP, yaw) * move.limit_length(1.0) * speed
	walker.velocity = Vector3(move.x, walker.velocity.y - 9.8 * delta, move.z)
	if walker.is_on_floor():
		walker.velocity.y = 0.0
		var step := Vector3(move.x, 0, move.z) * delta
		var hit := walker.move_and_collide(step, true)
		# up a stair: an edge in the way, and the way clear a step higher
		if hit and absf(hit.get_normal().y) < 0.6 \
				and not walker.test_move(walker.global_transform.translated(Vector3(0, STEP, 0)), step):
			walker.position.y += STEP
	walker.move_and_slide()
	if ranging:
		_range_tick(delta)
	elif walker.position.y < -20:
		walker.position = _gd(level["start"])


func _key(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0


## Frames the view: target point, distance, yaw and pitch in radians.
func look(at: Vector3, distance: float, turn: float, tilt: float) -> void:
	target = at
	dist = distance
	yaw = turn
	pitch = tilt


func play(anim: String) -> void:
	for p in shown.get_children():
		var player := p.find_child("AnimationPlayer") as AnimationPlayer
		if player and player.has_animation(anim):
			player.stop()
			player.play(anim)


func set_psx(on: bool) -> void:
	if not psx_screen:
		return
	psx_on = on
	psx_button.set_pressed_no_signal(on)
	world.get_parent().remove_child(world)
	if on:
		psx_screen.viewport.add_child(world)
	else:
		add_child(world)
	psx_screen.visible = on
	for n in shown.get_children():
		_convert(n)
	if gun_node:
		_convert(gun_node)


## PSX Look's materials on the node's meshes, as its `convert` puts them, but one per source
## material for the gallery's whole run: a skinned mesh shown again in the frame its last showing
## is freed would draw with that showing's freed material.
func _convert(node: Node) -> void:
	if not psx_screen:
		return
	if psx_on:
		var psx: GDScript = load(PSX_LOOK + "psx.gd")
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if mi.material_override is BaseMaterial3D:
				mi.material_override = _psx_material(psx, mi.material_override)
			for s in mi.mesh.get_surface_count() if mi.mesh else 0:
				var source: Material = mi.get_surface_override_material(s)
				if not source:
					source = mi.mesh.surface_get_material(s)
				if source is BaseMaterial3D:
					mi.set_surface_override_material(s, _psx_material(psx, source))
		return
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		for s in (mi as MeshInstance3D).get_surface_override_material_count():
			(mi as MeshInstance3D).set_surface_override_material(s, null)


func _psx_material(psx: GDScript, source: BaseMaterial3D) -> ShaderMaterial:
	if source not in psx_made:
		psx_made[source] = psx.from_material(source)
	return psx_made[source]


func _place(p: Dictionary, at: Vector3, parent: Node3D = shown) -> Node3D:
	var node: Node3D = load("%s/props/%s.tscn" % [dir, p["name"]]).instantiate()
	node.position = at
	node.set_meta("prop", p)
	parent.add_child(node)
	_convert(node)
	return node


## A held prop laid on its left side, on what `node` stands on.
func _lay(node: Node3D, p: Dictionary) -> void:
	node.rotation.z = -PI / 2
	node.position.y += p["max"][0]


## Props side by side from `back`, in lines no wider than WRAP: the floor's one behind the other,
## the wall's (`on_wall`) in two, one over the other. Returns the lines' width and depth.
func _row(list: Array, back: float, gap: float, on_wall := false) -> Vector2:
	var total := -gap
	var widest := 0.0
	for p in list:
		total += p["size"][0] + gap
		widest = maxf(widest, p["size"][0])
	var wrap := maxf(WRAP, total / 2.0 + widest + gap) if on_wall else WRAP
	var lines: Array = [[]]
	var width := -gap
	for p in list:
		if width + gap + p["size"][0] > wrap and not lines[-1].is_empty():
			lines.append([])
			width = -gap
		lines[-1].append(p)
		width += p["size"][0] + gap
	var size := Vector2.ZERO
	var z := back
	for k in lines.size():
		var line: Array = lines[k]
		width = -gap
		var depth := 0.0
		for p in line:
			width += p["size"][0] + gap
			depth = maxf(depth, p["size"][1])
		var x := -width * 0.5
		for p in line:
			var at := Vector3(x - p["min"][0], k * 3.0, 0.0) if on_wall else Vector3(x - p["min"][0], 0, z + p["max"][1])
			_place(p, at)
			x += p["size"][0] + gap
		size.x = maxf(size.x, width)
		z += depth + 0.3
	size.y = z - back - 0.3
	return size


## A group's items packed in rows under 0.6 m.
func _cluster(list: Array) -> Node3D:
	var c := Node3D.new()
	shown.add_child(c)
	var x := 0.0
	var z := 0.0
	var depth := 0.0
	var width := 0.0
	for p in list:
		var held: bool = p["place"] == "hand"  # laid down, the muzzle to the right
		var foot := Vector2(p["size"][1], p["size"][2]) if held else Vector2(p["size"][0], p["size"][1])
		if x > 0 and x + foot.x > 0.6:
			x = 0.0
			z += depth + GAP
			depth = 0.0
		if held:
			var n := _place(p, Vector3(x + p["max"][1], 0, z + p["max"][2]), c)
			n.rotation.y = PI / 2
			_lay(n, p)
		else:
			_place(p, Vector3(x - p["min"][0], 0, z + p["max"][1]), c)
		x += foot.x + GAP
		width = maxf(width, x - GAP)
		depth = maxf(depth, foot.y)
	c.set_meta("size", Vector2(width, z + depth))
	return c


func _clear() -> void:
	wall.transform = Transform3D(Basis.IDENTITY, Vector3(0, 3, -0.002))
	ground.position.y = -0.003
	sun.rotation_degrees = Vector3(-55, -30, 0)
	for n in shown.get_children():
		shown.remove_child(n)
		n.queue_free()


func _gd(a: Array) -> Vector3:
	return Vector3(a[0], a[2], -a[1])


func _size(s: Array) -> String:
	return "%.2f x %.2f x %.2f" % [s[0], s[2], s[1]]


func _process(delta: float) -> void:
	for n in shown.get_children():
		if n.has_meta("stop"):
			var player := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if player.current_animation_position >= n.get_meta("stop"):
				player.pause()
				n.remove_meta("stop")
		elif n is OmniLight3D and n.get_meta("flicker", false) and not still:
			n.light_energy = n.get_meta("energy") * (0.15 if randf() < 0.06 else 1.0)
	if walker:
		pitch = clampf(pitch, -1.4, 1.4)
		cam.position = walker.position + Vector3(0, EYE, 0)
		cam.rotation = Vector3(pitch, yaw, 0)
		cam.near = 0.02 if ranging else 0.05
		cam.far = 60.0
		if ranging:
			_viewmodel(delta)
		else:
			note_left -= delta
			note.visible = note_left > 0
			prompt.text = _prompt() if inspect and not inspect.showing else ""
		return
	idle += delta
	if not still and idle > 3.0:
		yaw += delta * 0.25
	pitch = clampf(pitch, -1.45, rise)
	var b := Basis.from_euler(Vector3(pitch, yaw, 0))
	cam.position = target + b * Vector3(0, 0, dist)
	cam.look_at(target)
	cam.near = dist * 0.02
	cam.far = dist * 20 + 20


func _unhandled_input(event: InputEvent) -> void:
	if walker:
		if event is InputEventMouseMotion:
			yaw -= event.relative.x * 0.004
			pitch -= event.relative.y * 0.004
			sway = (sway - event.relative * 0.00015).limit_length(0.02)
		elif event is InputEventMouseButton:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # again, after the browser let it go
			if ranging:
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						firing = event.pressed
					MOUSE_BUTTON_RIGHT when gun.has("melee"):
						if event.pressed:
							use_held()
					MOUSE_BUTTON_RIGHT:
						aiming = event.pressed
					MOUSE_BUTTON_WHEEL_UP when event.pressed:
						equip(guns.find(gun) - 1)
					MOUSE_BUTTON_WHEEL_DOWN when event.pressed:
						equip(guns.find(gun) + 1)
		elif event is InputEventKey and event.pressed and not event.echo:
			if ranging and event.keycode >= KEY_1 and event.keycode <= KEY_9 and event.keycode - KEY_1 < guns.size():
				equip(event.keycode - KEY_1)
			match event.keycode:
				KEY_ESCAPE:
					if ranging:
						firing_range(false)
					else:
						walk(false)
				KEY_R:
					if ranging:
						reload()
				KEY_I:
					if ranging:
						inspect_held()
				KEY_E:
					use()
				KEY_F:
					torch.visible = not torch.visible
				KEY_P:
					set_psx(not psx_on)
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw -= event.relative.x * 0.008
		pitch -= event.relative.y * 0.008
		idle = 0.0
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist *= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist *= 1.1
		idle = 0.0
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				show_prop(index - 1)
			KEY_RIGHT:
				show_prop(index + 1)
			KEY_A:
				toggle_all()
			KEY_L:
				if not level.is_empty():
					show_level()
			KEY_W:
				walk(true)
			KEY_G:
				firing_range(true)
			KEY_P:
				set_psx(not psx_on)
			KEY_I:
				inspect_shown()
			KEY_1, KEY_2, KEY_3:
				var anims: Array = props[index]["anims"]
				var k: int = event.keycode - KEY_1
				if not all_view and k < anims.size():
					play(anims[k]["name"])
