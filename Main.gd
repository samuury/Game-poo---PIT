extends Node3D
@warning_ignore_start("integer_division")
# BREAKOUT GENIUS 3D — Godot 4.x  (port completo do código Pygame)
# Uso: nó raiz Node3D + este script. Tudo é criado por código. Rode com F5.
# Menus, modos (Padrão/Random), 3 dificuldades, blocos obstáculo e bomba,
# 8 boosts, 3 downgrades, 10 questionários de matemática, 4 matérias gerais,
# estatísticas por matéria, recorde salvo, sons gerados por código.

const HALF_W := 14.0
const TOP_Y := 10.0
const BOTTOM_Y := -11.5
const PADDLE_Y := -9.0
const PADDLE_H := 0.5
const PADDLE_BASE_W := 5.0
const BALL_R := 0.35
const COLS := 14
const ROWS := 8
const BR_W := 1.8
const BR_H := 0.7
const BR_GAP := 0.1
const DROP_CHANCE := 0.12
const DROP_COOLDOWN := 3.5
const MAX_BALLS := 6
const STALL_LIMIT := 8.0
const MAX_DROPS := 3
const SPEED_K := 1.875  # +25% sobre o valor anterior (1.5), vale para todas as dificuldades
const SAVE_PATH := "user://recorde_breakout_matematico.txt"
const QUESTIONS_PATH := "res://data/perguntas.json"
const CONFIG_PATH := "user://config_breakout.cfg"
const QuizBankScript := preload("res://quiz_bank.gd")
const LevelGenScript := preload("res://level_gen.gd")
const GfxScript := preload("res://graphics.gd")
const MusicScript := preload("res://music.gd")
const MUSIC_LEVELS := [0.0, 0.35, 0.7, 1.0]
const MUSIC_NAMES := ["DESLIGADA", "BAIXA", "MÉDIA", "ALTA"]
const ROW_PTS := [7, 7, 5, 5, 3, 3, 1, 1]
const MATERIAS := ["Matemática", "Geografia", "Ciências", "História", "Cultura", "Tecnologia", "Português"]
var ROW_COLORS: Array[Color] = [
	Color8(200, 72, 72), Color8(200, 72, 72), Color8(198, 108, 58), Color8(198, 108, 58),
	Color8(72, 160, 72), Color8(72, 160, 72), Color8(200, 190, 60), Color8(200, 190, 60)]

var BOOSTS := {
	"LARGA": {"nome": "Raquete Larga", "cor": Color8(80, 200, 255), "icone": "W", "dur": 15.0, "desc": "Raquete 50% maior"},
	"MULTI": {"nome": "Multibola", "cor": Color8(255, 210, 60), "icone": "M", "dur": 0.0, "desc": "+2 bolas em jogo"},
	"LENTA": {"nome": "Câmera Lenta", "cor": Color8(140, 240, 140), "icone": "S", "dur": 12.0, "desc": "Bola 35% mais lenta"},
	"VIDA": {"nome": "Vida Extra", "cor": Color8(255, 100, 140), "icone": "+", "dur": 0.0, "desc": "+1 vida"},
	"FOGO": {"nome": "Bola de Fogo", "cor": Color8(255, 130, 40), "icone": "F", "dur": 10.0, "desc": "Atravessa e destrói blocos"},
	"IMA": {"nome": "Ímã", "cor": Color8(190, 120, 255), "icone": "I", "dur": 15.0, "desc": "Bola gruda na raquete"},
	"LASER": {"nome": "Laser", "cor": Color8(255, 70, 70), "icone": "L", "dur": 12.0, "desc": "Segure ESPAÇO para atirar"},
	"X2": {"nome": "Pontos x2", "cor": Color8(235, 235, 235), "icone": "x2", "dur": 15.0, "desc": "Pontuação em dobro"},
}
var BOOST_WEIGHTS := {"LARGA": 3, "MULTI": 3, "LENTA": 2, "VIDA": 1, "FOGO": 2, "IMA": 2, "LASER": 2, "X2": 2}
var DOWNGRADES := {
	"ENCOLHE": {"nome": "Raquete Encolhida", "cor": Color8(150, 150, 150), "dur": 8.0},
	"RAQUETE_LENTA": {"nome": "Raquete Lenta", "cor": Color8(220, 150, 90), "dur": 8.0},
	"BOLA_RAPIDA": {"nome": "Bola Acelerada", "cor": Color8(240, 90, 90), "dur": 8.0},
}
var DIFS := {
	"facil": {"nome": "Fácil", "fator": 0.88, "cresc": 0.28, "limite": 8.0, "densidade": 0.62,
		"vida_extra": 0, "haz_obs": 3, "haz_bomba": 2, "tempo": 25, "desc": "Bola mais lenta, mais tempo"},
	"normal": {"nome": "Normal", "fator": 1.0, "cresc": 0.4, "limite": 9.0, "densidade": 0.74,
		"vida_extra": 0, "haz_obs": 4, "haz_bomba": 3, "tempo": 20, "desc": "Ritmo equilibrado"},
	"dificil": {"nome": "Difícil", "fator": 1.16, "cresc": 0.58, "limite": 10.0, "densidade": 0.86,
		"vida_extra": 1, "haz_obs": 5, "haz_bomba": 4, "tempo": 16, "desc": "Bola rápida, menos tempo"},
}

# ---------------------------------------------------------------- estado
var world: Node3D
var scenery: Node3D
var cam: Camera3D
var paddle: MeshInstance3D
var paddle_mat: ShaderMaterial
var ball_light: OmniLight3D
var emit_nodes: Array = []

var bricks: Array = []
var balls: Array = []
var drops: Array = []
var lasers: Array = []
var fx: Array = []
var texts: Array = []
var active: Dictionary = {}
var sfx_players: Dictionary = {}

var score := 0
var lives := 3
var level := 1
var hi := 0
var state := "MENU"
var accel := 1.0
var freeze := 0.0
var cooldown_laser := 0.0
var level_timer := 0.0
var level_bonus := 0
var paddle_w := PADDLE_BASE_W
var use_mouse := false
var mouse_ratio := 0.5
var t_anim := 0.0
var novo_recorde := false
var save_path := SAVE_PATH
var config_path := CONFIG_PATH
var sound_on := true
var bump_tw: Tween
var gfx
var wall_nodes: Array = []
var brick_mesh_cache: Dictionary = {}
var ui_theme: Theme
var hud_root: Control
var score_label: Label
var hi_label: Label
var level_label: Label
var quizstat_label: Label
var hearts: Array = []
var pill_row: HBoxContainer
var pills: Dictionary = {}
var shown_score := 0.0
var cam_smooth := Vector3.ZERO
var look_smooth := Vector3(0, -1.2, 0)
var menu_buttons: Array = []
var menu_refocus := -1
var menu_panel: PanelContainer
var msg_box: CenterContainer
var msg_panel: PanelContainer
var quiz_btn_labels: Array = []
var UI_CYAN := Color8(96, 200, 255)
var UI_GOLD := Color8(255, 212, 110)
var UI_TEXT := Color8(232, 238, 255)
var UI_MUTED := Color8(140, 152, 190)
var UI_RED := Color8(240, 110, 110)
var music
var music_idx := 2
var brick_total := 1
var music_t := 0.0
var bank
var drop_cd := 0.0
var stall_t := 0.0
var shake := 0.0
var cam_base := Vector3.ZERO
var dim_rect: ColorRect

var modo_jogo := "padrao"
var dificuldade := "normal"
var materias_sel: Array = ["Matemática"]
var used: Dictionary = {}
var ultima_cat := ""
var stats: Dictionary = {}

var quiz: Dictionary = {}
var quiz_tipo := "LARGA"
var quiz_left := 0.0
var quiz_total := 15.0
var quiz_answered := false
var quiz_fb := 0.0

var msg_label: Label
var hint_label: Label
var quiz_box: CenterContainer
var quiz_cat: Label
var quiz_sub: Label
var quiz_text: Label
var quiz_bar: ProgressBar
var quiz_buttons: Array[Button] = []
var quiz_fb_label: Label
var menu_box: CenterContainer
var menu_vb: VBoxContainer
var quiz_checks: Dictionary = {}


func _ready() -> void:
	randomize()
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = Vector2i(1280, 720)
	hi = load_hi()
	bank = QuizBankScript.new()
	bank.load_json(QUESTIONS_PATH)
	setup_input()
	gfx = GfxScript.new()
	load_config()
	setup_sfx()
	music = MusicScript.new()
	add_child(music)
	music.volume = MUSIC_LEVELS[music_idx]
	setup_env()
	setup_world()
	build_ui()
	apply_gfx()
	stats = {"total": 0, "acertos": 0, "por_cat": {}, "tempo": 0.0}
	set_state("MENU")


# ---------------------------------------------------------------- sons
func make_seq(notes: Array, vol := 0.22) -> AudioStreamWAV:
	var rate := 22050
	var total := 0
	for n in notes:
		total += int(rate * float(n[1]))
	var buf := PackedByteArray()
	buf.resize(total * 2)
	var idx := 0
	for n in notes:
		var f: float = n[0]
		var cnt := int(rate * float(n[1]))
		for i in cnt:
			var env := 1.0 - 0.85 * float(i) / cnt
			var v := vol if sin(TAU * f * i / rate) >= 0.0 else -vol
			buf.encode_s16(idx * 2, int(v * env * 32767.0))
			idx += 1
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = buf
	return w


func sfx_add(nome: String, notes: Array, vol := 0.22) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = make_seq(notes, vol)
	p.max_polyphony = 4
	add_child(p)
	sfx_players[nome] = p


func setup_sfx() -> void:
	sfx_add("raquete", [[440, 0.05]])
	sfx_add("parede", [[330, 0.03]], 0.12)
	sfx_add("bloco", [[660, 0.05]])
	sfx_add("duro", [[250, 0.05]], 0.2)
	sfx_add("drop", [[520, 0.06], [780, 0.08]])
	sfx_add("certo", [[523, 0.08], [659, 0.08], [784, 0.08], [1047, 0.16]])
	sfx_add("errado", [[300, 0.12], [200, 0.22]])
	sfx_add("vida", [[220, 0.15], [180, 0.15], [140, 0.3]])
	sfx_add("laser", [[900, 0.04]], 0.1)
	sfx_add("nivel", [[392, 0.1], [523, 0.1], [659, 0.1], [784, 0.25]])


func sfx_play(nome: String) -> void:
	if sfx_players.has(nome):
		var p: AudioStreamPlayer = sfx_players[nome]
		p.play()


# ---------------------------------------------------------------- cena
func mat(c: Color, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.2
	m.roughness = 0.45
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	return m


func box(size: Vector3, c: Color, pos: Vector3, emis := 0.0, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c, emis)
	mi.position = pos
	if parent == null:
		parent = world
	parent.add_child(mi)
	return mi


func setup_env() -> void:
	gfx.build_environment(self)
	cam = Camera3D.new()
	cam.fov = 48.0
	cam.position = Vector3(0, -11.5, 27)
	add_child(cam)
	cam.look_at(Vector3(0, -1.2, 0), Vector3.UP)
	cam_base = cam.position
	cam_smooth = cam_base

	ball_light = OmniLight3D.new()
	ball_light.omni_range = 6.5
	ball_light.light_energy = 0.55
	ball_light.light_color = Color(1.0, 0.85, 0.6)
	ball_light.light_specular = 0.0
	ball_light.position = Vector3(0, PADDLE_Y, 3)
	add_child(ball_light)


func setup_world() -> void:
	scenery = Node3D.new()
	add_child(scenery)
	world = Node3D.new()
	add_child(world)

	var floor_mesh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(HALF_W * 2.0 + 1.4, 23.2)
	floor_mesh.mesh = q
	floor_mesh.material_override = gfx.floor_mat
	floor_mesh.position = Vector3(0, -0.45, -0.6)
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scenery.add_child(floor_mesh)

	wall_nodes.clear()
	var specs := [
		[Vector3(0.6, 22.6, 1.2), Vector3(-HALF_W - 0.3, -0.5, 0)],
		[Vector3(0.6, 22.6, 1.2), Vector3(HALF_W + 0.3, -0.5, 0)],
		[Vector3(HALF_W * 2.0 + 1.2, 0.6, 1.2), Vector3(0, TOP_Y + 0.3, 0)]]
	for sp in specs:
		var w := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sp[0]
		w.mesh = bm
		w.material_override = gfx.neon_mat
		w.position = sp[1]
		scenery.add_child(w)
		wall_nodes.append(w)

	paddle = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(PADDLE_BASE_W, PADDLE_H, 0.8)
	paddle.mesh = pm
	paddle_mat = gfx.new_paddle_mat()
	paddle.material_override = paddle_mat
	paddle.position = Vector3(0, PADDLE_Y, 0)
	world.add_child(paddle)
	var pl := OmniLight3D.new()
	pl.light_color = Color(0.4, 0.8, 1.0)
	pl.light_energy = 0.5
	pl.light_specular = 0.0
	pl.omni_range = 7.0
	pl.position = Vector3(0, 0.4, 1.6)
	paddle.add_child(pl)
	for i in 2:
		emit_nodes.append(box(Vector3(0.18, 0.3, 0.3), Color8(255, 70, 70), Vector3(0, PADDLE_Y + 0.35, 0), 2.5))
		(emit_nodes[i] as MeshInstance3D).visible = false


# ---------------------------------------------------------------- bolas
func new_ball(pos: Vector2, vel: Vector2, stuck: bool) -> Dictionary:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	mi.mesh = sm
	var bmat := mat(Color8(255, 240, 200), 2.2)
	mi.material_override = bmat
	world.add_child(mi)
	var hmat: StandardMaterial3D = gfx.halo_material(Color(1.0, 0.85, 0.55, 0.28))
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(1.5, 1.5)
	halo.mesh = hq
	halo.material_override = hmat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(halo)
	var tmat := mat(Color8(90, 130, 220), 1.4)
	var trail: Array = []
	for i in 8:
		var tn := MeshInstance3D.new()
		tn.mesh = sm
		tn.material_override = tmat
		tn.visible = false
		tn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(tn)
		trail.append(tn)
	return {"node": mi, "mat": bmat, "tmat": tmat, "hmat": hmat, "trail": trail, "hist": [],
		"pos": pos, "vel": vel, "stuck": stuck, "off": 0.0}


func free_ball(b: Dictionary) -> void:
	b.node.queue_free()
	for tn in b.trail:
		tn.queue_free()


func reset_ball() -> void:
	for b in balls:
		free_ball(b)
	balls.clear()
	balls.append(new_ball(Vector2(paddle.position.x, PADDLE_Y + 1.0), Vector2.ZERO, true))
	accel = 1.0


func any_stuck() -> bool:
	for b in balls:
		if b.stuck:
			return true
	return false


func ball_speed() -> float:
	var dif: Dictionary = DIFS[dificuldade]
	var v: float = minf((4.8 + float(dif.cresc) * (level - 1)) * float(dif.fator), float(dif.limite)) * accel * SPEED_K
	if active.has("LENTA"):
		v *= 0.65
	if active.has("BOLA_RAPIDA"):
		v *= 1.35
	return v


func launch() -> void:
	var sp := ball_speed()
	for b in balls:
		if b.stuck:
			var half := maxf(1.0, paddle_w * 0.5)
			var off := float(b.off) / half
			var ang := deg_to_rad(off * 55.0 if float(b.off) != 0.0 else randf_range(-25.0, 25.0))
			b.vel = Vector2(sin(ang), cos(ang)) * sp
			b.stuck = false
			b.off = 0.0


func fix_speed(v: Vector2, sp: float) -> Vector2:
	if v == Vector2.ZERO:
		return Vector2(0, sp)
	v = v.normalized() * sp
	var mn := sp * 0.3
	if absf(v.y) < mn:
		var sy := 1.0 if v.y >= 0.0 else -1.0
		var sx := 1.0 if v.x >= 0.0 else -1.0
		v = Vector2(sx * sqrt(sp * sp - mn * mn), sy * mn)
	return v


# ---------------------------------------------------------------- blocos
func brick_mesh(size: Vector3) -> BoxMesh:
	if not brick_mesh_cache.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		brick_mesh_cache[size] = bm
	return brick_mesh_cache[size]


func add_brick(tipo: String, pos: Vector2, r: int, hp: int) -> void:
	var col := ROW_COLORS[r]
	var depth := 0.8
	var kind := 0.0
	if tipo == "obstaculo":
		col = Color8(105, 112, 128)
		depth = 1.0
		kind = 1.0
	elif tipo == "bomba":
		col = Color8(155, 45, 42)
		kind = 2.0
	var node := MeshInstance3D.new()
	node.mesh = brick_mesh(Vector3(BR_W, BR_H, depth))
	node.material_override = gfx.brick_mat
	node.position = Vector3(pos.x, pos.y, 0)
	world.add_child(node)
	node.set_instance_shader_parameter("base_color", col)
	node.set_instance_shader_parameter("kind", kind)
	node.set_instance_shader_parameter("half_size", Vector3(BR_W, BR_H, depth) * 0.5)
	if tipo == "bomba":
		var sm := SphereMesh.new()
		sm.radius = 0.25
		sm.height = 0.5
		var core := MeshInstance3D.new()
		core.mesh = sm
		core.material_override = mat(Color8(255, 205, 85), 3.0)
		core.position = Vector3(0, 0, 0.5)
		node.add_child(core)
	# animação de entrada em onda
	node.scale = Vector3.ZERO
	var tw := node.create_tween()
	tw.tween_interval(r * 0.05 + (pos.x + HALF_W) * 0.012)
	tw.tween_property(node, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var br := {"node": node, "pos": pos, "hp": hp, "max": hp, "pts": ROW_PTS[r] if tipo == "normal" else (10 if tipo == "obstaculo" else 0),
		"color": col, "tipo": tipo}
	bricks.append(br)
	tint(br)


func tint(br: Dictionary) -> void:
	var n: MeshInstance3D = br.node
	if br.tipo == "normal":
		n.set_instance_shader_parameter("hp_glow", clampf((int(br.hp) - 1) / 3.0, 0.0, 1.0))
	elif br.tipo == "obstaculo":
		n.set_instance_shader_parameter("dmg", 1.0 - float(br.hp) / float(maxi(1, int(br.max))))


func build_bricks() -> void:
	for br in bricks:
		br.node.queue_free()
	bricks.clear()
	var total_w := COLS * BR_W + (COLS - 1) * BR_GAP
	var x0 := -total_w / 2.0 + BR_W / 2.0
	for cell in LevelGenScript.generate(level, modo_jogo, DIFS[dificuldade]):
		var pos := Vector2(x0 + int(cell.c) * (BR_W + BR_GAP), 8.0 - int(cell.r) * 0.9)
		add_brick(cell.tipo, pos, cell.r, cell.hp)


func clear_dynamic() -> void:
	for d in drops:
		d.node.queue_free()
	drops.clear()
	for l in lasers:
		l.node.queue_free()
	lasers.clear()


func load_level() -> void:
	build_bricks()
	clear_dynamic()
	active.clear()
	quiz = {}
	freeze = 0.0
	cooldown_laser = 0.0
	stall_t = 0.0
	brick_total = 0
	for br in bricks:
		if br.tipo == "normal":
			brick_total += 1
	reset_ball()


func start_game() -> void:
	save_config()
	shown_score = 0.0
	score = 0
	lives = 3
	level = 1
	stats = {"total": 0, "acertos": 0, "por_cat": {}, "tempo": 0.0}
	ultima_cat = ""
	used.clear()
	bank.revisit.clear()
	drop_cd = 0.0
	paddle_w = PADDLE_BASE_W
	paddle.position.x = 0.0
	load_level()
	set_state("JOGANDO")


func lose_life() -> void:
	lives -= 1
	shake = 0.6
	shockwave(Vector3(paddle.position.x, PADDLE_Y, 0.5), Color(1.0, 0.3, 0.3), 11.0)
	floor_ripple(Vector2(paddle.position.x, PADDLE_Y), 1.6)
	sfx_play("vida")
	active.clear()
	clear_dynamic()
	if lives <= 0:
		finish_game()
	else:
		reset_ball()
		freeze = 0.5


func finish_game() -> void:
	novo_recorde = score > load_hi()
	hi = maxi(hi, score)
	save_hi()
	set_state("FIM")


func load_hi() -> int:
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		return int(f.get_as_text().strip_edges())
	return 0


func save_hi() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(str(hi))


# ---------------------------------------------------------------- acertos / bombas
func hit_brick(br: Dictionary, destroy := false) -> void:
	if not bricks.has(br):
		return
	stall_t = 0.0
	if br.tipo == "bomba":
		explode_bomb(br)
		return
	br.hp = 0 if destroy else int(br.hp) - 1
	var node: MeshInstance3D = br.node
	if int(br.hp) > 0:
		sfx_play("duro")
		tint(br)
		flash_brick(node)
		burst(node.position, Color(0.9, 0.9, 0.95), 4)
		return
	bricks.erase(br)
	var p: Vector2 = br.pos
	var col: Color = br.color
	score += int(br.pts) * level * (2 if active.has("X2") else 1)
	sfx_play("bloco")
	burst(node.position, col, 12)
	pop_brick(node)
	shake = maxf(shake, 0.08)
	floor_ripple(p, 0.6)
	if drop_cd <= 0.0 and randf() < DROP_CHANCE and drops.size() < MAX_DROPS:
		drop_cd = DROP_COOLDOWN
		spawn_drop(p)


func explode_bomb(b0: Dictionary) -> void:
	var queue: Array = [b0]
	var palette: Array[Color] = [Color8(255, 90, 40), Color8(255, 190, 50), Color8(230, 230, 210)]
	while not queue.is_empty():
		var cur: Dictionary = queue.pop_back()
		if not bricks.has(cur) or cur.tipo != "bomba":
			continue
		bricks.erase(cur)
		var cp: Vector2 = cur.pos
		cur.node.queue_free()
		sfx_play("bloco")
		for i in 3:
			burst(Vector3(cp.x, cp.y, 0), palette[i], 9)
		float_text("BOOM!", Vector3(cp.x, cp.y, 1.0), Color8(255, 150, 60))
		shake = maxf(shake, 0.5)
		shockwave(Vector3(cp.x, cp.y, 0.3), Color(1.0, 0.6, 0.2), 9.0)
		floor_ripple(cp, 1.5)
		for nb in bricks.duplicate():
			var np: Vector2 = nb.pos
			if cp.distance_to(np) > 2.3:
				continue
			if nb.tipo == "bomba":
				queue.append(nb)
			elif nb.tipo == "normal":
				hit_brick(nb, true)
			elif nb.tipo == "obstaculo":
				hit_brick(nb)
				hit_brick(nb)


func spawn_drop(p: Vector2) -> void:
	var total := 0
	for k in BOOST_WEIGHTS:
		total += int(BOOST_WEIGHTS[k])
	var roll := randi() % total
	var tipo := "LARGA"
	for k in BOOST_WEIGHTS:
		roll -= int(BOOST_WEIGHTS[k])
		if roll < 0:
			tipo = k
			break
	var info: Dictionary = BOOSTS[tipo]
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	mi.mesh = cm
	mi.material_override = mat(info.cor, 1.0)
	mi.rotation_degrees.z = 90.0
	mi.position = Vector3(p.x, p.y, 0)
	world.add_child(mi)
	var lb := Label3D.new()
	lb.text = str(info.icone) + "?"
	lb.font_size = 64
	lb.pixel_size = 0.012
	lb.outline_size = 12
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.position = Vector3(0, 0, 0.6)
	mi.add_child(lb)
	drops.append({"node": mi, "pos": p, "tipo": tipo, "t": 0.0})


func burst(pos: Vector3, col: Color, n: int) -> void:
	var m := mat(col, 0.8)
	for i in n:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * randf_range(0.12, 0.25)
		mi.mesh = bm
		mi.material_override = m
		mi.position = pos
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		fx.append({"node": mi, "life": 0.7,
			"vel": Vector3(randf_range(-4, 4), randf_range(-3, 5), randf_range(1, 6))})


func float_text(txt: String, pos: Vector3, col: Color) -> void:
	var lb := Label3D.new()
	lb.text = txt
	lb.font_size = 56
	lb.pixel_size = 0.012
	lb.outline_size = 14
	lb.modulate = col
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.position = pos
	world.add_child(lb)
	texts.append({"node": lb, "life": 1.4})


func update_fx(delta: float) -> void:
	for f in fx.duplicate():
		var v: Vector3 = f.vel
		v.y -= 9.0 * delta
		f.vel = v
		f.life = float(f.life) - delta
		var n: MeshInstance3D = f.node
		n.position += v * delta
		n.scale = Vector3.ONE * clampf(float(f.life) / 0.7, 0.0, 1.0)
		if float(f.life) <= 0.0:
			n.queue_free()
			fx.erase(f)
	for t in texts.duplicate():
		var lb: Label3D = t.node
		lb.position.y += 0.9 * delta
		t.life = float(t.life) - delta
		lb.modulate.a = clampf(float(t.life), 0.0, 1.0)
		if float(t.life) <= 0.0:
			lb.queue_free()
			texts.erase(t)


# ---------------------------------------------------------------- física
func step_ball(b: Dictionary, dt: float) -> bool:
	var pos: Vector2 = b.pos
	var vel: Vector2 = b.vel
	var fire := active.has("FOGO")
	var steps := maxi(1, int(ceil(vel.length() * dt / 0.2)))
	var h := dt / steps
	for _i in steps:
		pos += vel * h
		if pos.x < -HALF_W + BALL_R:
			pos.x = -HALF_W + BALL_R
			vel.x = absf(vel.x)
			sfx_play("parede")
			wall_pulse(0)
		elif pos.x > HALF_W - BALL_R:
			pos.x = HALF_W - BALL_R
			vel.x = -absf(vel.x)
			sfx_play("parede")
			wall_pulse(1)
		if pos.y > TOP_Y - BALL_R:
			pos.y = TOP_Y - BALL_R
			vel.y = -absf(vel.y)
			sfx_play("parede")
			wall_pulse(2)

		var hits: Array = []
		for br in bricks:
			var c: Vector2 = br.pos
			var cl := Vector2(
				clampf(pos.x, c.x - BR_W * 0.5, c.x + BR_W * 0.5),
				clampf(pos.y, c.y - BR_H * 0.5, c.y + BR_H * 0.5))
			var d := pos - cl
			if d.length_squared() < BALL_R * BALL_R:
				hits.append({"br": br, "d": d, "cl": cl})
		if not hits.is_empty():
			var chosen: Dictionary = hits[0]
			if fire:
				for hh in hits:
					hit_brick(hh.br, true)
			else:
				var dd: Vector2 = chosen.d
				var cc: Vector2 = chosen.cl
				if dd == Vector2.ZERO:
					vel.y = -vel.y
				elif absf(dd.x) > absf(dd.y):
					vel.x = signf(dd.x) * absf(vel.x)
					pos.x = cc.x + signf(dd.x) * BALL_R
				else:
					vel.y = signf(dd.y) * absf(vel.y)
					pos.y = cc.y + signf(dd.y) * BALL_R
				if chosen.br.tipo == "obstaculo":
					vel = vel.rotated(deg_to_rad(randf_range(-3.0, 3.0)))
				hit_brick(chosen.br)

		# raquete
		if vel.y < 0.0 and pos.y - BALL_R <= PADDLE_Y + PADDLE_H * 0.5 and pos.y >= PADDLE_Y \
				and absf(pos.x - paddle.position.x) <= paddle_w * 0.5 + BALL_R:
			var off := clampf((pos.x - paddle.position.x) / (paddle_w * 0.5) + randf_range(-0.05, 0.05), -1.0, 1.0)
			var ang := deg_to_rad(off * 60.0)
			var sp := vel.length()
			vel = Vector2(sin(ang), cos(ang)) * sp
			pos.y = PADDLE_Y + PADDLE_H * 0.5 + BALL_R
			accel = minf(1.3, accel + 0.01)
			sfx_play("raquete")
			paddle_bump()
			floor_ripple(Vector2(pos.x, pos.y), 0.5)
			if active.has("IMA"):
				b.stuck = true
				b.off = pos.x - paddle.position.x
				b.pos = pos
				b.vel = Vector2.ZERO
				return true

		if pos.y < BOTTOM_Y:
			b.pos = pos
			b.vel = vel
			return false
	b.pos = pos
	b.vel = vel
	return true


func fire_laser() -> void:
	var half := paddle_w * 0.5 - 0.18
	for dx in [-half, half]:
		var px: float = paddle.position.x + dx
		var node := box(Vector3(0.09, 0.3, 0.09), Color8(255, 90, 90), Vector3(px, PADDLE_Y + 0.3, 0), 2.0)
		lasers.append({"node": node, "pos": Vector2(px, PADDLE_Y + 0.3)})
	cooldown_laser = 0.22
	sfx_play("laser")


func update_lasers(delta: float) -> void:
	for l in lasers.duplicate():
		var p: Vector2 = l.pos
		p.y += 15.0 * delta
		l.pos = p
		var n: MeshInstance3D = l.node
		n.position = Vector3(p.x, p.y, 0)
		var target = null
		for br in bricks:
			var bp: Vector2 = br.pos
			if absf(p.x - bp.x) < BR_W * 0.5 + 0.045 and absf(p.y - bp.y) < BR_H * 0.5 + 0.15:
				target = br
				break
		if target != null:
			hit_brick(target)
			n.queue_free()
			lasers.erase(l)
		elif p.y > TOP_Y:
			n.queue_free()
			lasers.erase(l)


func update_paddle(delta: float) -> void:
	var dir := 0.0
	dir = Input.get_axis("esq", "dir")
	var spd := 22.0 * (0.55 if active.has("RAQUETE_LENTA") else 1.0)
	var x := paddle.position.x
	if dir != 0.0:
		use_mouse = false
		x += dir * spd * delta
	elif use_mouse:
		x = (mouse_ratio - 0.5) * 2.0 * HALF_W * 1.05
	var target := PADDLE_BASE_W * (1.5 if active.has("LARGA") else 1.0) * (0.65 if active.has("ENCOLHE") else 1.0)
	paddle_w = lerpf(paddle_w, target, minf(1.0, delta * 10.0))
	paddle.scale.x = paddle_w / PADDLE_BASE_W
	paddle.position.x = clampf(x, -HALF_W + paddle_w * 0.5, HALF_W - paddle_w * 0.5)

	var cor := Color8(90, 200, 255)
	if active.has("ENCOLHE") or active.has("RAQUETE_LENTA"):
		cor = Color8(150, 150, 160)
	if active.has("IMA"):
		var ic: Color = BOOSTS["IMA"].cor
		cor = ic
	paddle_mat.set_shader_parameter("color", cor)
	var half := paddle_w * 0.5 - 0.18
	for i in 2:
		var en: MeshInstance3D = emit_nodes[i]
		en.visible = active.has("LASER")
		en.position = Vector3(paddle.position.x + (-half if i == 0 else half), PADDLE_Y + 0.35, 0)


func update_drops(delta: float) -> void:
	for d in drops.duplicate():
		var p: Vector2 = d.pos
		p.y -= 5.5 * delta
		d.pos = p
		d.t = float(d.t) + delta
		var n: MeshInstance3D = d.node
		n.position = Vector3(p.x, p.y, 0)
		var m: StandardMaterial3D = n.material_override
		m.emission_energy_multiplier = 1.0 + 0.8 * sin(float(d.t) * 8.0)
		if absf(p.x - paddle.position.x) <= paddle_w * 0.5 + 0.8 and absf(p.y - PADDLE_Y) <= 0.8:
			var tipo: String = d.tipo
			drops.erase(d)
			n.queue_free()
			var binfo: Dictionary = BOOSTS[tipo]
			shockwave(Vector3(p.x, p.y, 0.3), binfo.cor, 5.5)
			floor_ripple(p, 1.0)
			open_quiz(tipo)
			return
		elif p.y < BOTTOM_Y - 1.0:
			drops.erase(d)
			n.queue_free()


# ---------------------------------------------------------------- perguntas
func adapt_offsets() -> Dictionary:
	# Dificuldade adaptativa: acerto alto sobe o nível daquela matéria, acerto baixo desce.
	var out := {}
	var pc: Dictionary = stats.por_cat
	for cat in pc:
		var ok: int = pc[cat][0]
		var tot: int = pc[cat][1]
		if tot >= 3:
			out[cat] = clampi(int(round((float(ok) / tot - 0.6) * 5.0)), -2, 2)
	return out


func pick_question() -> Dictionary:
	bank.adapt = adapt_offsets()
	return bank.pick(materias_sel, ultima_cat, used, level)


# ---------------------------------------------------------------- quiz
func open_quiz(tipo: String) -> void:
	quiz = pick_question()
	ultima_cat = quiz.cat
	used["%s|%s|%s" % [quiz.cat, quiz.text, "/".join(quiz.opts)]] = true
	quiz_tipo = tipo
	var dif: Dictionary = DIFS[dificuldade]
	quiz_total = float(maxi(8, int(dif.tempo) - int((level - 1) * 0.8)))
	quiz_left = quiz_total
	quiz_answered = false
	quiz_fb = 0.0
	var info: Dictionary = BOOSTS[tipo]
	var tag := "REVISÃO" if quiz.get("revisao", false) else "QUESTIONÁRIO"
	quiz_cat.text = "%s  •  %s" % [tag, String(quiz.cat).to_upper()]
	quiz_sub.text = "Acerte e ganhe: %s — %s" % [info.nome, info.desc]
	quiz_sub.modulate = info.cor
	quiz_text.text = quiz.text
	for i in 4:
		quiz_btn_labels[i].text = str(quiz.opts[i])
		quiz_buttons[i].modulate = Color.WHITE
	quiz_fb_label.text = "Teclas 1-4 ou clique  •  Resposta rápida = mais pontos"
	quiz_fb_label.modulate = Color(0.7, 0.7, 0.8)
	set_state("QUIZ")
	sfx_play("drop")


func answer(i: int) -> void:
	if state != "QUIZ" or quiz_answered:
		return
	quiz_answered = true
	quiz_fb = 2.4
	var cat: String = quiz.cat
	var pc: Dictionary = stats.por_cat
	if not pc.has(cat):
		pc[cat] = [0, 0]
	pc[cat][1] += 1
	stats.total = int(stats.total) + 1
	stats.tempo = float(stats.tempo) + (quiz_total - quiz_left)
	quiz_buttons[int(quiz.correct)].modulate = Color8(90, 230, 130)
	if i == int(quiz.correct):
		pc[cat][0] += 1
		stats.acertos = int(stats.acertos) + 1
		var bonus := (50 + int(quiz_left * 10.0)) * level
		score += bonus
		active.erase("ENCOLHE")
		apply_boost(quiz_tipo)
		var info: Dictionary = BOOSTS[quiz_tipo]
		quiz_fb_label.text = "CORRETO!  +%d pts  •  %s ativado" % [bonus, info.nome]
		quiz_fb_label.modulate = Color8(90, 230, 130)
		sfx_play("certo")
	else:
		bank.note_wrong(quiz)
		if i >= 0:
			quiz_buttons[i].modulate = Color8(240, 90, 90)
		var keys := DOWNGRADES.keys()
		var key: String = keys.pick_random()
		var dg: Dictionary = DOWNGRADES[key]
		active[key] = float(dg.dur)
		float_text(str(dg.nome) + "!", Vector3(paddle.position.x, PADDLE_Y + 2.0, 1.0), dg.cor)
		if i < 0:
			quiz_fb_label.text = "TEMPO ESGOTADO!  Resposta: %s  •  %s" % [quiz.ans, dg.nome]
		else:
			quiz_fb_label.text = "ERROU!  Resposta: %s  •  %s por %ds" % [quiz.ans, dg.nome, int(dg.dur)]
		quiz_fb_label.modulate = Color8(240, 90, 90)
		sfx_play("errado")


func close_quiz() -> void:
	quiz = {}
	set_state("JOGANDO")
	freeze = 0.7


func apply_boost(tipo: String) -> void:
	var info: Dictionary = BOOSTS[tipo]
	match tipo:
		"MULTI":
			var src := Vector2(paddle.position.x, PADDLE_Y + 1.0)
			var loose: Array = []
			for b in balls:
				if not b.stuck:
					loose.append(b)
			if not loose.is_empty():
				src = loose[0].pos
			var sp := ball_speed()
			for deg in [-30.0, 30.0]:
				var a := deg_to_rad(deg)
				if balls.size() < MAX_BALLS:
					balls.append(new_ball(src, Vector2(sin(a), cos(a)) * sp, false))
		"VIDA":
			lives = mini(9, lives + 1)
		_:
			active[tipo] = minf(30.0, float(active.get(tipo, 0.0)) + float(info.dur))
	float_text(str(info.nome) + "!", Vector3(paddle.position.x, PADDLE_Y + 2.0, 1.0), info.cor)


# ---------------------------------------------------------------- loop
func set_state(s: String) -> void:
	var prev := state
	state = s
	world.visible = s in ["JOGANDO", "QUIZ", "PAUSA", "NIVEL"]
	menu_box.visible = s in ["MENU", "AJUDA", "GRAFICOS", "SELECAO_MODO", "SELECAO_DIFICULDADE", "SELECAO_QUIZ"]
	var a := 0.0
	match s:
		"QUIZ":
			a = 0.7
		"PAUSA", "NIVEL":
			a = 0.55
		"FIM":
			a = 0.7
		"MENU", "AJUDA", "GRAFICOS", "SELECAO_MODO", "SELECAO_DIFICULDADE", "SELECAO_QUIZ":
			a = 0.45
	dim_rect.color.a = a
	quiz_box.visible = s == "QUIZ"
	if menu_box.visible:
		call_deferred("rebuild_menu")
	if music != null:
		music_on_state(prev, s)


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	t_anim += delta
	update_shake(delta)
	update_fx(delta)
	update_floor_fx()
	update_hud(delta)
	match state:
		"QUIZ":
			if not quiz_answered:
				quiz_left -= delta
				quiz_bar.value = maxf(0.0, quiz_left) / quiz_total * 100.0
				quiz_bar.modulate = Color8(220, 70, 70).lerp(Color8(70, 200, 110), maxf(0.0, quiz_left) / quiz_total)
				if quiz_left <= 0.0:
					quiz_left = 0.0
					answer(-1)
			else:
				quiz_fb -= delta
				if quiz_fb <= 0.0:
					close_quiz()
		"NIVEL":
			level_timer -= delta
			if level_timer <= 0.0:
				level += 1
				load_level()
				set_state("JOGANDO")
		"JOGANDO":
			update_game(delta)


func update_game(delta: float) -> void:
	drop_cd -= delta
	music_t -= delta
	if music_t <= 0.0:
		music_t = 0.35
		var left := 0
		for br in bricks:
			if br.tipo == "normal":
				left += 1
		var progress := 1.0 - float(left) / float(maxi(1, brick_total))
		music.set_layers(not any_stuck(), progress >= 0.35 or level >= 4 or lives == 1)
	if freeze <= 0.0 and not any_stuck():
		stall_t += delta
		if stall_t > STALL_LIMIT:
			stall_t = STALL_LIMIT - 3.0
			for sb in balls:
				if not sb.stuck:
					var sv: Vector2 = sb.vel
					sb.vel = sv.rotated(deg_to_rad(randf_range(-30.0, 30.0)))
	for k in active.keys():
		active[k] = float(active[k]) - delta
		if float(active[k]) <= 0.0:
			active.erase(k)
			if k == "IMA":
				launch()

	update_paddle(delta)

	cooldown_laser -= delta
	if active.has("LASER") and Input.is_action_pressed("lancar") and cooldown_laser <= 0.0 and not any_stuck():
		fire_laser()
	update_lasers(delta)

	if freeze > 0.0:
		freeze -= delta
	var sp := ball_speed()
	var fire := active.has("FOGO")
	for b in balls.duplicate():
		if b.stuck:
			b.pos = Vector2(paddle.position.x + float(b.off), PADDLE_Y + PADDLE_H * 0.5 + BALL_R + 0.02)
			b.hist.clear()
		elif freeze <= 0.0:
			b.vel = fix_speed(b.vel, sp)
			var alive := step_ball(b, delta)
			b.hist.append(b.pos)
			while b.hist.size() > 8:
				b.hist.pop_front()
			if not alive:
				free_ball(b)
				balls.erase(b)
				continue
		var p: Vector2 = b.pos
		var bn: MeshInstance3D = b.node
		bn.position = Vector3(p.x, p.y, 0)
		var bm: StandardMaterial3D = b.mat
		bm.albedo_color = Color8(255, 150, 40) if fire else Color8(255, 240, 200)
		bm.emission = bm.albedo_color
		var tm: StandardMaterial3D = b.tmat
		tm.albedo_color = Color8(255, 130, 40) if fire else Color8(90, 130, 220)
		tm.emission = tm.albedo_color
		var hm: StandardMaterial3D = b.hmat
		hm.albedo_color = Color(1.0, 0.5, 0.15, 0.4) if fire else Color(1.0, 0.85, 0.55, 0.28)
		var n: int = b.hist.size()
		for i in 8:
			var tn: MeshInstance3D = b.trail[i]
			if i < n:
				var hp: Vector2 = b.hist[i]
				tn.visible = true
				tn.position = Vector3(hp.x, hp.y, 0)
				tn.scale = Vector3.ONE * (float(i + 1) / n * 0.8)
			else:
				tn.visible = false

	if balls.is_empty():
		lose_life()
		return
	var first: Vector2 = balls[0].pos
	ball_light.position = Vector3(first.x, first.y, 3)

	update_drops(delta)
	if state != "JOGANDO":
		return

	if score > hi:
		hi = score

	var remaining := false
	for br in bricks:
		if br.tipo == "normal":
			remaining = true
			break
	if not remaining:
		for br in bricks:
			br.node.queue_free()
		bricks.clear()
		level_bonus = lives * 100 * level
		score += level_bonus
		hi = maxi(hi, score)
		save_hi()
		level_timer = 4.0
		sfx_play("nivel")
		shockwave(Vector3(0, 0, 0.5), Color(1.0, 0.9, 0.4), 30.0)
		floor_ripple(Vector2(0, 0), 2.0)
		set_state("NIVEL")


# ---------------------------------------------------------------- HUD
func update_hud(delta: float) -> void:
	var show_hud := state in ["JOGANDO", "QUIZ", "PAUSA", "NIVEL"]
	hud_root.visible = show_hud
	shown_score = lerpf(shown_score, float(score), minf(1.0, delta * 8.0))
	if absf(shown_score - score) < 0.6:
		shown_score = float(score)
	score_label.text = "%06d" % int(round(shown_score))
	hi_label.text = "RECORDE  %06d" % maxi(hi, score)
	level_label.text = "NÍVEL %d" % level
	quizstat_label.text = "QUIZ  %d/%d" % [int(stats.get("acertos", 0)), int(stats.get("total", 0))]
	for i in hearts.size():
		var h: Node2D = hearts[i]
		h.visible = i < lives
		var sc := 1.0 + 0.07 * sin(t_anim * 6.0 + i)
		h.scale = Vector2(sc, sc)
	update_pills()

	var hint := ""
	if state == "JOGANDO":
		if any_stuck():
			if int(t_anim * 2.0) % 2 == 0:
				hint = "ESPAÇO ou clique para lançar"
		elif freeze > 0.0:
			hint = "Prepare-se!"
	hint_label.text = hint

	var msg := ""
	match state:
		"PAUSA":
			msg = "PAUSADO\nP / ESC: continuar   •   Q: encerrar partida"
		"NIVEL":
			msg = "NÍVEL %d CONCLUÍDO!\nBônus de vidas: +%d" % [level, level_bonus]
		"FIM":
			msg = fim_text()
	msg_label.text = msg
	msg_box.visible = msg != ""


func fim_text() -> String:
	var total := int(stats.total)
	var ok := int(stats.acertos)
	var pct := (100.0 * ok / total) if total > 0 else 0.0
	var medio := (float(stats.tempo) / total) if total > 0 else 0.0
	var s := "FIM DE JOGO\n"
	s += "Pontuação: %d   •   Nível: %d\n" % [score, level]
	if novo_recorde:
		s += "NOVO RECORDE!\n"
	else:
		s += "Recorde: %d\n" % hi
	s += "\nDESEMPENHO NOS QUESTIONÁRIOS\n"
	s += "Respondidas: %d   •   Acertos: %d (%.0f%%)   •   Tempo médio: %.1fs\n\n" % [total, ok, pct, medio]
	var pc: Dictionary = stats.por_cat
	if pc.is_empty():
		s += "Nenhuma cápsula coletada nesta partida.\n"
	var ad := adapt_offsets()
	var names := pc.keys()
	names.sort_custom(func(a, b): return int(pc[a][1]) > int(pc[b][1]))
	for nm in names:
		var ac: int = pc[nm][0]
		var tt: int = pc[nm][1]
		var filled := int(round(10.0 * ac / tt)) if tt > 0 else 0
		var adj := int(ad.get(nm, 0))
		var adj_txt := ("   (nível %+d)" % adj) if adj != 0 else ""
		s += "%s  [%s%s]  %d/%d%s\n" % [nm, "#".repeat(filled), "-".repeat(10 - filled), ac, tt, adj_txt]
	s += "\nENTER: jogar de novo   •   M: menu   •   ESC: sair"
	return s


# ---------------------------------------------------------------- UI
func make_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	return l


func build_ui() -> void:
	var fxl := CanvasLayer.new()
	fxl.layer = 1
	add_child(fxl)
	gfx.build_post(fxl)

	var cl := CanvasLayer.new()
	cl.layer = 2
	add_child(cl)

	dim_rect = ColorRect.new()
	dim_rect.color = Color(0, 0, 0, 0.0)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(dim_rect)
	dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	build_hud(cl)

	# mensagem central (pausa, fim de fase, fim de jogo) dentro de um cartão
	msg_box = CenterContainer.new()
	msg_box.visible = false
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(msg_box)
	msg_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	msg_panel = PanelContainer.new()
	msg_panel.add_theme_stylebox_override("panel", panel_style())
	msg_box.add_child(msg_panel)
	var msg_mg := MarginContainer.new()
	for sd in ["left", "top", "right", "bottom"]:
		msg_mg.add_theme_constant_override("margin_" + sd, 30)
	msg_panel.add_child(msg_mg)
	msg_label = make_label(28)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size = Vector2(640, 0)
	msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_mg.add_child(msg_label)

	hint_label = make_label(24)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(hint_label)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -120
	hint_label.offset_bottom = -80

	# quiz
	quiz_box = CenterContainer.new()
	quiz_box.visible = false
	cl.add_child(quiz_box)
	quiz_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	panel.add_theme_stylebox_override("panel", panel_style())
	quiz_box.add_child(panel)
	var mg := MarginContainer.new()
	for sd in ["left", "top", "right", "bottom"]:
		mg.add_theme_constant_override("margin_" + sd, 28)
	panel.add_child(mg)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	mg.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)
	var cat_chip := make_chip(UI_CYAN)
	quiz_cat = Label.new()
	quiz_cat.add_theme_font_size_override("font_size", 16)
	cat_chip.add_child(quiz_cat)
	head.add_child(cat_chip)
	var sub_chip := make_chip(UI_GOLD)
	quiz_sub = Label.new()
	quiz_sub.add_theme_font_size_override("font_size", 16)
	sub_chip.add_child(quiz_sub)
	head.add_child(sub_chip)

	quiz_text = Label.new()
	quiz_text.add_theme_font_size_override("font_size", 32)
	quiz_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_text.custom_minimum_size = Vector2(800, 90)
	vb.add_child(quiz_text)
	quiz_bar = ProgressBar.new()
	quiz_bar.max_value = 100.0
	quiz_bar.value = 100.0
	quiz_bar.show_percentage = false
	quiz_bar.custom_minimum_size = Vector2(0, 10)
	vb.add_child(quiz_bar)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vb.add_child(grid)
	quiz_buttons.clear()
	quiz_btn_labels.clear()
	for i in 4:
		var ab := make_answer_button(i)
		grid.add_child(ab)
		quiz_buttons.append(ab)
	quiz_fb_label = Label.new()
	quiz_fb_label.add_theme_font_size_override("font_size", 21)
	quiz_fb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_fb_label.custom_minimum_size = Vector2(800, 34)
	vb.add_child(quiz_fb_label)

	# menus
	menu_box = CenterContainer.new()
	cl.add_child(menu_box)
	menu_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", panel_style())
	menu_box.add_child(menu_panel)
	var mmg := MarginContainer.new()
	for sd in ["left", "right"]:
		mmg.add_theme_constant_override("margin_" + sd, 34)
	for sd in ["top", "bottom"]:
		mmg.add_theme_constant_override("margin_" + sd, 26)
	menu_panel.add_child(mmg)
	menu_vb = VBoxContainer.new()
	menu_vb.add_theme_constant_override("separation", 8)
	mmg.add_child(menu_vb)
	ui_theme = build_theme()
	menu_box.theme = ui_theme
	quiz_box.theme = ui_theme


func pick_parent(parent: Node) -> Node:
	return parent if parent != null else menu_vb


func mlabel(text: String, size := 18, color := Color.WHITE, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.modulate = color
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick_parent(parent).add_child(l)
	return l


func mwrap(text: String, size := 16, color := Color.WHITE, parent: Node = null, width := 640.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.modulate = color
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	pick_parent(parent).add_child(l)
	return l


func mspace(h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	menu_vb.add_child(c)


func maccent() -> void:
	var line := ColorRect.new()
	line.color = UI_CYAN
	line.custom_minimum_size = Vector2(110, 4)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_vb.add_child(line)


func mtitle(a: String, b: String, sub: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	menu_vb.add_child(row)
	var la := make_label(54 if b != "" else 44)
	la.text = a
	la.add_theme_color_override("font_color", UI_GOLD)
	row.add_child(la)
	if b != "":
		var lb := make_label(54)
		lb.text = b
		lb.add_theme_color_override("font_color", UI_CYAN)
		row.add_child(lb)
	if sub != "":
		mlabel(sub, 19, UI_MUTED)
	maccent()


func make_chip(col: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.14)
	sb.border_color = Color(col.r, col.g, col.b, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc


func mchip(text: String, col: Color, parent: Node = null) -> PanelContainer:
	var pc := make_chip(col)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UI_TEXT)
	pc.add_child(l)
	pick_parent(parent).add_child(pc)
	return pc


func mchips(items: Array) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	menu_vb.add_child(row)
	for it in items:
		mchip(it[0], it[1], row)


func msection(text: String, parent: Node) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", UI_GOLD)
	parent.add_child(l)
	var line := ColorRect.new()
	line.color = Color(UI_GOLD.r, UI_GOLD.g, UI_GOLD.b, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	parent.add_child(line)


func mhint(text: String) -> void:
	mspace(2)
	mlabel(text, 14, UI_MUTED)


func mbutton(text: String, cb: Callable, w := 380.0, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 58 if primary else 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 25 if primary else 21)
	if primary:
		b.theme_type_variation = "PrimaryButton"
	b.pressed.connect(cb)
	menu_vb.add_child(b)
	menu_buttons.append(b)
	return b


func card_content(b: Button, title: String, desc: String, selected: bool, left: float) -> void:
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	b.add_child(vb)
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = left
	vb.offset_right = -16
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	var t := Label.new()
	t.text = title
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_font_size_override("font_size", 23)
	t.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(t)
	if selected:
		var chip := mchip("ATUAL", UI_GOLD, row)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var d := Label.new()
	d.text = desc
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_theme_font_size_override("font_size", 15)
	d.add_theme_color_override("font_color", UI_MUTED)
	vb.add_child(d)


func mcard(title: String, desc: String, cb: Callable, selected := false, w := 560.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, 74)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	var bar := ColorRect.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = UI_GOLD if selected else UI_CYAN
	b.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	bar.offset_left = 12
	bar.offset_right = 16
	bar.offset_top = 14
	bar.offset_bottom = -14
	card_content(b, title, desc, selected, 32.0)
	var refresh := func():
		bar.color = UI_GOLD if (selected or b.has_focus() or b.is_hovered()) else UI_CYAN
	b.mouse_entered.connect(refresh)
	b.mouse_exited.connect(refresh)
	b.focus_entered.connect(refresh)
	b.focus_exited.connect(refresh)
	menu_vb.add_child(b)
	menu_buttons.append(b)
	return b


func mtoggle(title: String, desc: String, pressed: bool, cb: Callable, parent: Node, w := 330.0) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(w, 70)
	b.button_pressed = pressed
	var ind := Panel.new()
	ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ind)
	ind.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	ind.offset_left = 16
	ind.offset_right = 40
	ind.offset_top = -12
	ind.offset_bottom = 12
	b.set_meta("ind", ind)
	card_content(b, title, desc, false, 54.0)
	refresh_toggle(b)
	b.toggled.connect(func(_p): refresh_toggle(b))
	b.toggled.connect(cb)
	parent.add_child(b)
	menu_buttons.append(b)
	return b


func refresh_toggle(b: Button) -> void:
	var ind: Panel = b.get_meta("ind")
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(2)
	if b.button_pressed:
		sb.bg_color = UI_CYAN
		sb.border_color = UI_CYAN
	else:
		sb.bg_color = Color(0, 0, 0, 0.25)
		sb.border_color = UI_MUTED
	ind.add_theme_stylebox_override("panel", sb)


func mrow(title: String, value: String, cb: Callable, w := 560.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 22
	hb.offset_right = -22
	var t := Label.new()
	t.text = title
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", UI_TEXT)
	hb.add_child(t)
	var v := Label.new()
	v.text = value
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_theme_font_size_override("font_size", 19)
	v.add_theme_color_override("font_color", UI_CYAN)
	hb.add_child(v)
	menu_vb.add_child(b)
	menu_buttons.append(b)
	return b


func make_answer_button(i: int) -> Button:
	var palette: Array[Color] = [Color8(96, 200, 255), Color8(255, 212, 110), Color8(120, 230, 160), Color8(255, 130, 170)]
	var b := Button.new()
	b.custom_minimum_size = Vector2(393, 70)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(answer.bind(i))
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 14)
	b.add_child(hb)
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 16
	hb.offset_right = -14
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(38, 38)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = palette[i]
	sb.set_corner_radius_all(19)
	badge.add_theme_stylebox_override("panel", sb)
	var num := Label.new()
	num.text = str(i + 1)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 20)
	num.add_theme_color_override("font_color", Color8(14, 18, 36))
	badge.add_child(num)
	hb.add_child(badge)
	var lb := Label.new()
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.custom_minimum_size = Vector2(280, 0)
	lb.add_theme_font_size_override("font_size", 22)
	hb.add_child(lb)
	quiz_btn_labels.append(lb)
	return b


func materias_chip() -> String:
	if materias_sel.size() == 1:
		return "QUIZ  " + str(materias_sel[0])
	return "QUIZ  %d matérias" % materias_sel.size()


func rebuild_menu() -> void:
	for ch in menu_vb.get_children():
		menu_vb.remove_child(ch)
		ch.queue_free()
	quiz_checks.clear()
	menu_buttons.clear()
	menu_panel.custom_minimum_size = Vector2(640, 0)
	match state:
		"MENU":
			build_menu_main()
		"AJUDA":
			build_menu_help()
		"GRAFICOS":
			build_menu_gfx()
		"SELECAO_MODO":
			build_menu_modo()
		"SELECAO_DIFICULDADE":
			build_menu_dif()
		"SELECAO_QUIZ":
			build_menu_quiz()


func build_menu_main() -> void:
	mtitle("BREAKOUT", "GENIUS", "Matemática + conhecimentos gerais")
	mspace(4)
	mchips([["MODO  " + ("Padrão" if modo_jogo == "padrao" else "Random"), UI_CYAN],
		["DIFICULDADE  " + str(DIFS[dificuldade].nome), UI_CYAN], [materias_chip(), UI_GOLD]])
	mlabel("RECORDE  %06d" % hi, 20, UI_GOLD)
	mspace(4)
	var jb := mbutton("JOGAR", func(): set_state("SELECAO_MODO"), 380.0, true)
	mbutton("COMO JOGAR", func(): set_state("AJUDA"), 380.0)
	mbutton("GRÁFICOS", func(): set_state("GRAFICOS"), 380.0)
	mbutton_pair("SOM: " + ("LIGADO" if sound_on else "DESLIGADO"), toggle_sound,
		"MÚSICA: " + MUSIC_NAMES[music_idx], cycle_music)
	mhint("← → / A D / mouse: mover  •  ESPAÇO: lançar / laser  •  P: pausa  •  F11: tela cheia")
	jb.grab_focus()


func build_menu_help() -> void:
	menu_panel.custom_minimum_size = Vector2(780, 0)
	mtitle("COMO JOGAR", "", "")
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(740, 400)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_vb.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	sc.add_child(inner)
	mwrap("Quebre os blocos com a bola. Alguns blocos soltam cápsulas: pegue com a raquete e responda ao quiz para ganhar um boost.", 16, UI_TEXT, inner, 710.0)
	msection("BOOSTS", inner)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 3)
	inner.add_child(grid)
	for k in BOOSTS:
		var info: Dictionary = BOOSTS[k]
		var l := Label.new()
		l.text = "%s — %s" % [info.nome, info.desc]
		l.add_theme_font_size_override("font_size", 15)
		l.modulate = info.cor
		grid.add_child(l)
	msection("BLOCOS", inner)
	mwrap("Coloridos: quebram com 1 a 4 batidas.", 15, UI_TEXT, inner, 710.0)
	mwrap("Cinza (reforçados): quebram só depois de muitas batidas, o dobro de um bloco normal do modo Difícil. Rachaduras mostram o estrago.", 15, UI_TEXT, inner, 710.0)
	mwrap("Vermelhos (bombas): explodem em cadeia e machucam os blocos em volta.", 15, UI_TEXT, inner, 710.0)
	msection("QUIZ", inner)
	mwrap("Matemática (12 tipos), Geografia, Ciências, História, Cultura, Tecnologia e Português. Acerto rápido vale mais pontos. Errou ou o tempo acabou? Downgrade por 8 s, e a matéria volta depois como REVISÃO.", 15, UI_TEXT, inner, 710.0)
	mwrap("A dificuldade se ajusta ao seu desempenho em cada matéria.", 15, UI_TEXT, inner, 710.0)
	msection("CONTROLES", inner)
	mwrap("Mover: ← → / A D / mouse / direcional  •  Lançar e atirar: ESPAÇO / botão A", 15, UI_TEXT, inner, 710.0)
	mwrap("Responder: 1-4 ou A/B/X/Y  •  Pausa: P ou Start  •  Tela cheia: F11", 15, UI_TEXT, inner, 710.0)
	mspace(2)
	mbutton("VOLTAR", func(): set_state("MENU"), 240.0, true).grab_focus()


func build_menu_gfx() -> void:
	menu_panel.custom_minimum_size = Vector2(680, 0)
	mtitle("GRÁFICOS", "", str(GfxScript.QUALITY_DESC[gfx.quality]))
	mspace(4)
	var r: Vector2i = GfxScript.RESOLUTIONS[gfx.res_idx]
	mrow("Qualidade", GfxScript.QUALITY_NAMES[gfx.quality], func(): gfx_change("quality"))
	mrow("Resolução da janela", "%dx%d" % [r.x, r.y], func(): gfx_change("res"))
	mrow("Tela cheia", "SIM" if gfx.fullscreen else "NÃO", func(): gfx_change("full"))
	mrow("Escala 3D", "%d%%" % int(float(GfxScript.SCALES[gfx.scale_idx]) * 100.0), func(): gfx_change("scale"))
	mrow("Efeitos de tela", "LIGADOS" if gfx.post else "DESLIGADOS", func(): gfx_change("post"))
	mspace(2)
	mlabel(gfx.render_info(get_window()), 16, UI_CYAN)
	mwrap("Escala acima de 100% renderiza em resolução maior e reduz (supersampling): bordas mais nítidas, mas exige mais da placa de vídeo.", 14, UI_MUTED, null, 600.0)
	mspace(2)
	mbutton("VOLTAR", func(): set_state("MENU"), 240.0, true)
	var fi := menu_refocus if menu_refocus >= 0 and menu_refocus < menu_buttons.size() else 0
	(menu_buttons[fi] as Button).grab_focus()
	menu_refocus = -1


func build_menu_modo() -> void:
	mtitle("MODO DE JOGO", "", "Passo 1 de 3")
	mspace(6)
	var c1 := mcard("Padrão", "Fases clássicas em sequência", func(): choose_modo("padrao"), modo_jogo == "padrao")
	var c2 := mcard("Random", "Fases procedurais aleatórias, com blocos reforçados e bombas", func(): choose_modo("random"), modo_jogo == "random")
	mhint("Clique ou pressione 1/2  •  setas + ENTER  •  ESC volta")
	(c1 if modo_jogo == "padrao" else c2).grab_focus()


func build_menu_dif() -> void:
	mtitle("DIFICULDADE", "", "Passo 2 de 3")
	mspace(6)
	var cards := {}
	for k in DIFS:
		var dif: Dictionary = DIFS[k]
		cards[k] = mcard(str(dif.nome), str(dif.desc), choose_dificuldade.bind(k), k == dificuldade)
	mhint("Clique ou pressione 1/2/3  •  setas + ENTER  •  ESC volta")
	(cards[dificuldade] as Button).grab_focus()


func build_menu_quiz() -> void:
	menu_panel.custom_minimum_size = Vector2(760, 0)
	mtitle("MATÉRIAS DO QUIZ", "", "Passo 3 de 3  •  escolha uma ou mais")
	mspace(4)
	var descs := {"Matemática": "12 tipos de contas e problemas", "Geografia": "Países, capitais e biomas",
		"Ciências": "Corpo humano, física e química", "História": "Brasil e mundo",
		"Cultura": "Arte, música, literatura e esporte", "Tecnologia": "Computação e programação",
		"Português": "Gramática e ortografia"}
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_vb.add_child(grid)
	var idx := 1
	for m in MATERIAS:
		quiz_checks[m] = mtoggle("%d  %s" % [idx, m], str(descs.get(m, "")), materias_sel.has(m), on_materia_toggled.bind(m), grid, 340.0)
		idx += 1
	mspace(4)
	mbutton("COMEÇAR", start_game, 300.0, true)
	mhint("1-7 marcam e desmarcam  •  setas navegam  •  ENTER/ESPAÇO marca  •  ESC volta")
	(quiz_checks[MATERIAS[0]] as Button).grab_focus()


func choose_modo(m: String) -> void:
	modo_jogo = m
	set_state("SELECAO_DIFICULDADE")


func choose_dificuldade(d: String) -> void:
	dificuldade = d
	set_state("SELECAO_QUIZ")


func on_materia_toggled(pressed: bool, m: String) -> void:
	if pressed:
		if not materias_sel.has(m):
			materias_sel.append(m)
	else:
		if materias_sel.size() > 1:
			materias_sel.erase(m)
		else:
			var b: Button = quiz_checks[m]
			b.set_pressed_no_signal(true)
			refresh_toggle(b)


# ---------------------------------------------------------------- entrada
func digit_of(k: int) -> int:
	if k >= KEY_1 and k <= KEY_9:
		return k - KEY_1 + 1
	if k >= KEY_KP_1 and k <= KEY_KP_9:
		return k - KEY_KP_1 + 1
	return 0


func on_primary() -> void:
	match state:
		"JOGANDO":
			if any_stuck():
				launch()
			elif active.has("LASER") and cooldown_laser <= 0.0:
				fire_laser()
		"QUIZ":
			if quiz_answered and quiz_fb < 2.0:
				close_quiz()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).keycode == KEY_F11:
		toggle_fullscreen()
		return
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		handle_pad((event as InputEventJoypadButton).button_index)
		return
	if state == "JOGANDO" and event.is_action_pressed("lancar"):
		on_primary()
		return
	if event is InputEventMouseMotion:
		mouse_ratio = (event as InputEventMouseMotion).position.x / get_viewport().get_visible_rect().size.x
		use_mouse = true
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			on_primary()
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	var k: int = ke.keycode
	var dg := digit_of(k)
	match state:
		"MENU":
			if k == KEY_ESCAPE:
				get_tree().quit()
		"AJUDA", "GRAFICOS":
			if k == KEY_ESCAPE:
				set_state("MENU")
		"SELECAO_MODO":
			if dg == 1:
				choose_modo("padrao")
			elif dg == 2:
				choose_modo("random")
			elif k == KEY_ESCAPE:
				set_state("MENU")
		"SELECAO_DIFICULDADE":
			var keys := DIFS.keys()
			if dg >= 1 and dg <= keys.size():
				choose_dificuldade(keys[dg - 1])
			elif k == KEY_ESCAPE:
				set_state("SELECAO_MODO")
		"SELECAO_QUIZ":
			if dg >= 1 and dg <= MATERIAS.size():
				var cb: Button = quiz_checks[MATERIAS[dg - 1]]
				cb.button_pressed = not cb.button_pressed
			elif k == KEY_ESCAPE:
				set_state("SELECAO_DIFICULDADE")
		"JOGANDO":
			if k == KEY_P or k == KEY_ESCAPE:
				set_state("PAUSA")
		"QUIZ":
			if not quiz_answered:
				if dg >= 1 and dg <= 4:
					answer(dg - 1)
			elif quiz_fb < 2.0 and (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE):
				close_quiz()
		"PAUSA":
			if k == KEY_P or k == KEY_ESCAPE:
				set_state("JOGANDO")
			elif k == KEY_Q:
				finish_game()
				set_state("MENU")
		"FIM":
			if k == KEY_ENTER or k == KEY_KP_ENTER:
				start_game()
			elif k == KEY_M:
				set_state("MENU")
			elif k == KEY_ESCAPE:
				get_tree().quit()



# ---------------------------------------------------------------- extras
func setup_input() -> void:
	add_input("esq", [KEY_LEFT, KEY_A], JOY_AXIS_LEFT_X, -1.0)
	add_input("dir", [KEY_RIGHT, KEY_D], JOY_AXIS_LEFT_X, 1.0)
	add_input("lancar", [KEY_SPACE], -1, 0.0, JOY_BUTTON_A)


func add_input(nome: String, keys: Array, axis := -1, axis_val := 0.0, btn := -1) -> void:
	if not InputMap.has_action(nome):
		InputMap.add_action(nome, 0.3)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = int(k) as Key
		InputMap.action_add_event(nome, e)
	if axis >= 0:
		var j := InputEventJoypadMotion.new()
		j.axis = axis as JoyAxis
		j.axis_value = axis_val
		InputMap.action_add_event(nome, j)
	if btn >= 0:
		var jb := InputEventJoypadButton.new()
		jb.button_index = btn as JoyButton
		InputMap.action_add_event(nome, jb)


func update_shake(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	var sway := Vector3.ZERO
	var look := Vector3(0, -1.2, 0)
	if state in ["JOGANDO", "QUIZ", "PAUSA", "NIVEL"]:
		sway.x = paddle.position.x * 0.12
		look.x = paddle.position.x * 0.06
	else:
		sway = Vector3(sin(t_anim * 0.25) * 3.5, cos(t_anim * 0.2) * 1.2, sin(t_anim * 0.18) * 2.0)
	var k := 1.0 - exp(-delta * 4.0)
	cam_smooth = cam_smooth.lerp(cam_base + sway, k)
	look_smooth = look_smooth.lerp(look, k)
	cam.position = cam_smooth + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake * 0.35
	cam.look_at(look_smooth, Vector3.UP)
	cam.fov = 48.0 + shake * 3.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "JOGANDO":
		set_state("PAUSA")
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		hi = maxi(hi, score)
		save_hi()


func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(15, 18, 36, 248)
	sb.border_color = Color8(62, 84, 150)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 28
	sb.shadow_offset = Vector2(0, 8)
	return sb


func toggle_fullscreen() -> void:
	gfx.fullscreen = not gfx.fullscreen
	apply_gfx()
	save_config()


# ---------------------------------------------------------------- polimento / config
func flash_brick(node: MeshInstance3D) -> void:
	node.create_tween().tween_method(func(v: float): node.set_instance_shader_parameter("flash", v), 1.2, 0.0, 0.25)


func pop_brick(node: MeshInstance3D) -> void:
	node.set_instance_shader_parameter("flash", 1.5)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * 1.25, 0.05)
	tw.tween_property(node, "scale", Vector3.ZERO, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


func paddle_bump() -> void:
	if bump_tw != null and bump_tw.is_valid():
		bump_tw.kill()
	paddle.scale.y = 1.7
	bump_tw = paddle.create_tween()
	bump_tw.tween_property(paddle, "scale:y", 1.0, 0.12)


func handle_pad(btn: int) -> void:
	match state:
		"QUIZ":
			if not quiz_answered:
				if btn >= 0 and btn <= 3:
					answer(btn)
			elif quiz_fb < 2.0 and btn == 0:
				close_quiz()
		"JOGANDO":
			if btn == JOY_BUTTON_START:
				set_state("PAUSA")
		"PAUSA":
			if btn == JOY_BUTTON_START:
				set_state("JOGANDO")
		"FIM":
			if btn == 0:
				start_game()
			elif btn == 1:
				set_state("MENU")


func apply_sound() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_on)


func toggle_sound() -> void:
	sound_on = not sound_on
	apply_sound()
	save_config()
	call_deferred("rebuild_menu")


func load_config() -> void:
	var cf := ConfigFile.new()
	if cf.load(config_path) != OK:
		return
	var md: String = str(cf.get_value("jogo", "modo", modo_jogo))
	if md in ["padrao", "random"]:
		modo_jogo = md
	var df: String = str(cf.get_value("jogo", "dificuldade", dificuldade))
	if DIFS.has(df):
		dificuldade = df
	var ms = cf.get_value("jogo", "materias", materias_sel)
	if ms is Array:
		var ok: Array = []
		for m in MATERIAS:
			if ms.has(m):
				ok.append(m)
		if not ok.is_empty():
			materias_sel = ok
	sound_on = bool(cf.get_value("jogo", "som", true))
	music_idx = clampi(int(cf.get_value("jogo", "musica", music_idx)), 0, MUSIC_LEVELS.size() - 1)
	apply_sound()
	gfx.quality = clampi(int(cf.get_value("gfx", "qualidade", gfx.quality)), 0, GfxScript.QUALITY_NAMES.size() - 1)
	gfx.res_idx = clampi(int(cf.get_value("gfx", "resolucao", gfx.res_idx)), 0, GfxScript.RESOLUTIONS.size() - 1)
	gfx.scale_idx = clampi(int(cf.get_value("gfx", "escala", gfx.scale_idx)), 0, GfxScript.SCALES.size() - 1)
	gfx.fullscreen = bool(cf.get_value("gfx", "tela_cheia", gfx.fullscreen))
	gfx.post = bool(cf.get_value("gfx", "efeitos", gfx.post))


func save_config() -> void:
	var cf := ConfigFile.new()
	cf.set_value("jogo", "modo", modo_jogo)
	cf.set_value("jogo", "dificuldade", dificuldade)
	cf.set_value("jogo", "materias", materias_sel)
	cf.set_value("jogo", "som", sound_on)
	cf.set_value("jogo", "musica", music_idx)
	cf.set_value("gfx", "qualidade", gfx.quality)
	cf.set_value("gfx", "resolucao", gfx.res_idx)
	cf.set_value("gfx", "escala", gfx.scale_idx)
	cf.set_value("gfx", "tela_cheia", gfx.fullscreen)
	cf.set_value("gfx", "efeitos", gfx.post)
	cf.save(config_path)



# ---------------------------------------------------------------- gráficos / HUD novo
func apply_gfx() -> void:
	gfx.apply(get_viewport(), get_window())


func gfx_change(what: String) -> void:
	match what:
		"quality":
			gfx.quality = (gfx.quality + 1) % GfxScript.QUALITY_NAMES.size()
		"res":
			gfx.res_idx = (gfx.res_idx + 1) % GfxScript.RESOLUTIONS.size()
		"full":
			gfx.fullscreen = not gfx.fullscreen
		"scale":
			gfx.scale_idx = (gfx.scale_idx + 1) % GfxScript.SCALES.size()
		"post":
			gfx.post = not gfx.post
	menu_refocus = menu_buttons.find(get_viewport().gui_get_focus_owner())
	apply_gfx()
	save_config()
	call_deferred("rebuild_menu")


func update_floor_fx() -> void:
	var arr := PackedVector4Array()
	for i in 6:
		if i < balls.size():
			var p: Vector2 = balls[i].pos
			arr.append(Vector4(p.x, p.y, 1.0 if i == 0 else 0.6, 0.0))
		else:
			arr.append(Vector4(0, 0, 0, 0))
	gfx.floor_mat.set_shader_parameter("balls", arr)
	gfx.floor_mat.set_shader_parameter("game_time", t_anim)


func floor_ripple(p: Vector2, strength: float) -> void:
	gfx.floor_mat.set_shader_parameter("ripple", Vector4(p.x, p.y, t_anim, strength))


func wall_pulse(i: int) -> void:
	if i >= wall_nodes.size():
		return
	var w: MeshInstance3D = wall_nodes[i]
	w.set_instance_shader_parameter("pulse", 1.0)
	w.create_tween().tween_method(func(v: float): w.set_instance_shader_parameter("pulse", v), 1.0, 0.0, 0.4)


func shockwave(pos: Vector3, col: Color, size: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	var m: StandardMaterial3D = gfx.halo_material(Color(col.r, col.g, col.b, 0.9), true)
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3(0.3, 0.3, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(size, size, 1.0), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)


func heart_polygon(sz: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(Vector2(x, y) * sz / 17.0)
	return pts


func build_hud(cl: CanvasLayer) -> void:
	hud_root = Control.new()
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(hud_root)
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var cap := make_label(15)
	cap.text = "PONTOS"
	cap.position = Vector2(26, 8)
	cap.modulate = Color8(150, 175, 240)
	hud_root.add_child(cap)
	score_label = make_label(44)
	score_label.position = Vector2(24, 20)
	hud_root.add_child(score_label)
	hi_label = make_label(16)
	hi_label.position = Vector2(26, 78)
	hi_label.modulate = Color8(255, 220, 120)
	hud_root.add_child(hi_label)

	level_label = make_label(34)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_root.add_child(level_label)
	level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 8
	level_label.offset_bottom = 52
	quizstat_label = make_label(16)
	quizstat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quizstat_label.modulate = Color8(150, 210, 255)
	hud_root.add_child(quizstat_label)
	quizstat_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	quizstat_label.offset_top = 52
	quizstat_label.offset_bottom = 76

	var hbox := Control.new()
	hbox.position = Vector2(1280 - 36, 38)
	hud_root.add_child(hbox)
	for i in 9:
		var h := Node2D.new()
		h.position = Vector2(-i * 34.0, 0)
		var back := Polygon2D.new()
		back.polygon = heart_polygon(14.0 * 1.22)
		back.color = Color(0.1, 0.0, 0.05, 0.85)
		h.add_child(back)
		var front := Polygon2D.new()
		front.polygon = heart_polygon(14.0)
		front.color = Color8(255, 85, 125)
		h.add_child(front)
		var shine := Polygon2D.new()
		shine.polygon = heart_polygon(5.0)
		shine.position = Vector2(-4, -4)
		shine.color = Color(1, 1, 1, 0.35)
		h.add_child(shine)
		hbox.add_child(h)
		hearts.append(h)

	pill_row = HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 8)
	pill_row.position = Vector2(26, 106)
	hud_root.add_child(pill_row)


func make_pill(k: String) -> Dictionary:
	var info: Dictionary = BOOSTS[k] if BOOSTS.has(k) else DOWNGRADES[k]
	var col: Color = info.cor
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.85)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	pc.add_child(vb)
	var lb := Label.new()
	lb.add_theme_font_size_override("font_size", 15)
	lb.add_theme_color_override("font_color", col)
	vb.add_child(lb)
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(110, 6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(bar)
	pill_row.add_child(pc)
	return {"root": pc, "label": lb, "bar": bar}


func update_pills() -> void:
	for k in active:
		if not pills.has(k):
			pills[k] = make_pill(k)
		var info: Dictionary = BOOSTS[k] if BOOSTS.has(k) else DOWNGRADES[k]
		var total := maxf(1.0, float(info.dur))
		var pl: Dictionary = pills[k]
		(pl.bar as ProgressBar).value = clampf(float(active[k]) / total, 0.0, 1.0) * 100.0
		(pl.label as Label).text = "%s  %ds" % [info.nome, int(ceil(float(active[k])))]
	for k in pills.keys():
		if not active.has(k):
			(pills[k].root as Node).queue_free()
			pills.erase(k)


func btn_style(bg: Color, border: Color, bw: int, radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	return sb


func focus_style(radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = UI_GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	return sb


func build_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20
	th.set_stylebox("normal", "Button", btn_style(Color8(22, 27, 52), Color8(54, 72, 130), 1))
	th.set_stylebox("hover", "Button", btn_style(Color8(32, 42, 82), Color8(110, 160, 245), 2))
	th.set_stylebox("pressed", "Button", btn_style(Color8(34, 60, 118), UI_CYAN, 2))
	th.set_stylebox("hover_pressed", "Button", btn_style(Color8(40, 70, 134), UI_CYAN, 2))
	th.set_stylebox("focus", "Button", focus_style())
	th.set_stylebox("disabled", "Button", btn_style(Color8(24, 26, 40), Color8(60, 64, 90), 1))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, "Button", UI_TEXT)
	th.add_type("PrimaryButton")
	th.set_type_variation("PrimaryButton", "Button")
	th.set_stylebox("normal", "PrimaryButton", btn_style(Color8(34, 96, 190), Color8(130, 205, 255), 2, 14))
	th.set_stylebox("hover", "PrimaryButton", btn_style(Color8(48, 120, 222), Color8(190, 232, 255), 2, 14))
	th.set_stylebox("pressed", "PrimaryButton", btn_style(Color8(28, 80, 160), Color8(130, 205, 255), 2, 14))
	th.set_stylebox("focus", "PrimaryButton", focus_style(14))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(c, "PrimaryButton", Color.WHITE)
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(1, 1, 1, 0.1)
	pbg.set_corner_radius_all(5)
	var pfill := StyleBoxFlat.new()
	pfill.bg_color = UI_CYAN
	pfill.set_corner_radius_all(5)
	th.set_stylebox("background", "ProgressBar", pbg)
	th.set_stylebox("fill", "ProgressBar", pfill)
	return th


# ---------------------------------------------------------------- trilha sonora
func track_for_level() -> String:
	return "jogo_%d" % ((level - 1) % 3 + 1)


func music_on_state(prev: String, s: String) -> void:
	match s:
		"MENU", "AJUDA", "GRAFICOS", "SELECAO_MODO", "SELECAO_DIFICULDADE", "SELECAO_QUIZ":
			music.duck(false)
			if prev == "FIM":
				music.stop_sting()
			music.play_track("menu")
		"JOGANDO":
			if prev == "QUIZ":
				music.resume_game()
			elif prev == "PAUSA":
				music.duck(false)
			else:
				if prev != "NIVEL":
					music.stop_sting()
				music.duck(false)
				music.set_layers(false, false)
				music.play_track(track_for_level())
		"QUIZ":
			music.pause_for_quiz()
			music.play_track("quiz")
		"PAUSA":
			music.duck(true)
		"NIVEL":
			music.stop_all()
			music.sting("vitoria")
		"FIM":
			music.stop_all()
			music.sting("derrota")
			music.play_after_sting("menu")


func cycle_music() -> void:
	music_idx = (music_idx + 1) % MUSIC_LEVELS.size()
	music.set_volume(MUSIC_LEVELS[music_idx])
	save_config()
	call_deferred("rebuild_menu")


func mbutton_pair(ta: String, ca: Callable, tb: String, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	menu_vb.add_child(row)
	for spec in [[ta, ca], [tb, cb]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(185, 46)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(spec[1])
		row.add_child(b)
		menu_buttons.append(b)
