extends RefCounted
class_name MotionBlurUtil
## Efek "motion blur" ringan berbasis afterimage trail (bukan post-process
## shader) -- cocok untuk objek ColorRect flat-color seperti bola & paddle
## di ponGame ini. Dipanggil tiap physics tick dari BallScript/PaddleScript.
##
## Dipakai statis, tidak perlu autoload:
##   var state := MotionBlurUtil.apply_to(some_colorrect_or_body)
##   MotionBlurUtil.update_from_velocity(state, velocity, max_speed)

const MIN_SPEED_RATIO := 0.32     # di bawah ini, tidak perlu ada blur/trail
const SPAWN_INTERVAL_MS := 40     # jarak minimum antar ghost (biar tidak spam node)
const GHOST_LIFETIME := 0.22
const MAX_ALPHA := 0.45

class BlurState:
	var visual: CanvasItem     # node yang mau ditiru bentuk & warnanya (ColorRect Sprite)
	var last_spawn_ms: int = 0
	var enabled: bool = true

## Dipanggil sekali di _ready() node yang mau punya efek blur.
static func apply_to(visual: CanvasItem) -> BlurState:
	var state := BlurState.new()
	state.visual = visual
	return state

## Dipanggil tiap physics tick dengan velocity dunia nyata objek tsb.
static func update_from_velocity(state: BlurState, velocity: Vector2, max_speed: float, devil_boost: bool = false) -> void:
	if state == null or state.visual == null or not state.enabled or not is_instance_valid(state.visual):
		return
	var speed_ratio: float = clamp(velocity.length() / max(max_speed, 1.0), 0.0, 1.0)
	var threshold := MIN_SPEED_RATIO * (0.6 if devil_boost else 1.0)
	if speed_ratio < threshold:
		return
	var now := Time.get_ticks_msec()
	if now - state.last_spawn_ms < SPAWN_INTERVAL_MS:
		return
	state.last_spawn_ms = now
	_spawn_ghost(state.visual, speed_ratio, devil_boost)

static func _spawn_ghost(visual: CanvasItem, intensity: float, devil_boost: bool) -> void:
	if not is_instance_valid(visual):
		return
	var host_node: Node = visual.get_parent()
	if host_node == null:
		return
	var root := host_node.get_tree().current_scene
	if root == null:
		return

	var size := Vector2(10, 10)
	var color := Color(1, 1, 1)
	if visual is ColorRect:
		size = (visual as ColorRect).size
		color = (visual as ColorRect).color

	var origin := host_node as Node2D
	if origin == null:
		return

	var ghost := MotionGhost.new()
	ghost.rect_size = size
	ghost.base_color = color.lerp(Color(0.85, 0.05, 0.1), 0.5) if devil_boost else color
	ghost.global_position = origin.global_position
	ghost.z_index = -1
	ghost.modulate.a = MAX_ALPHA * intensity * (1.4 if devil_boost else 1.0)
	root.add_child(ghost)
	ghost.queue_redraw()

	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, GHOST_LIFETIME)
	tw.tween_callback(ghost.queue_free)
