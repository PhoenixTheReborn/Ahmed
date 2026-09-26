extends CharacterBody3D

# AYHEM MOUSH RAJEL

#------Camera------#
@onready var head: Node3D = $Head
@onready var eyes: Node3D = $Head/LeanArm/Eyes
@onready var camera_3d: Camera3D = %Camera3D
@onready var lean_arm: Node3D = $Head/LeanArm

#------CollisionShapes------#
@onready var standing_collision_shape: CollisionShape3D = $StandingCollisionShape
@onready var crouching_collision_shape: CollisionShape3D = $CrouchingCollisionShape
@onready var interactable_area: Area3D = $"Interactable Area"
var current_focused_object = null
@onready var backpack: Node3D = $Head/LeanArm/Eyes/Camera3D/backpack

#------Raycasts------#
@onready var standup_check: RayCast3D = $StandupCheck
@onready var lean_check: ShapeCast3D = $LeanChecks/LeanCheck
@onready var lean_check_2: ShapeCast3D = $LeanChecks/LeanCheck2
@onready var interaction_ray: RayCast3D = $Head/LeanArm/Eyes/Camera3D/InteractionRay

#------Blood Vial System------#
@export var blood_vial_path: NodePath = "Head/LeanArm/Eyes/Camera3D/Blood Vial"
@export var mouse_slosh_sensitivity: float = 0.003
@export var movement_slosh_intensity: float = 14.0  # Controls physical footstep slosh strength
@export var max_slosh_angle: float = 0.5
@export var slosh_recovery_speed: float = 6.0
@export var slosh_lerp_speed: float = 12.0

var blood_vial_node: Node3D = null
var liquid_mesh: MeshInstance3D = null
var liquid_material: ShaderMaterial = null
var target_slosh: Vector2 = Vector2.ZERO
var current_slosh: Vector2 = Vector2.ZERO

#------Movement variables------#
const walking_speed: float = 3.5
const sprinting_speed: float = 6.0
const crouching_speed: float = 1.5
const sprint_accel_rate: float = 5.0
var current_speed: float = 0.0
var moving: bool = false
var input_dir: Vector2 = Vector2.ZERO
var direction: Vector3 = Vector3.ZERO
const crouching_depth: float = -0.9
const jump_height: float = 0.501
var jump_velocity: float = 1.0

#------Player Settings------#
var lerp_speed: float = 10.0
var mouse_sens: float = 0.2
var Base_FOV: float = 90.0
var max_hp: int = 100
var hp: int = 100
var health_drop_speed: float = 10.0
var lives: int = 5 # just Test

#------Head bobbing variables------#
const head_bobbing_sprinting_speed: float = 14.0
const head_bobbing_walking_speed: float = 10.0
const head_bobbing_crouching_speed: float = 6.0

const head_bobbing_sprinting_intensity: float = 0.08
const head_bobbing_walking_intensity: float = 0.05
const head_bobbing_crouching_intensity: float = 0.02

var head_bobbing_current_intensity: float = 0.0
var head_bobbing_index: float = 0.0

#------Landing shake variables------#
var was_on_floor: bool = true
var landing_shake_intensity: float = 0.0
var landing_shake_decay: float = 8.0
var landing_shake_frequency: float = 35.0
var landing_shake_index: float = 0.0
var landing_shake_time: float = 0.0
const landing_shake_min_fall_speed: float = 3.0   # ignore tiny hops
const landing_shake_max_intensity: float = 0.15

#------Lean variables-----#
var target_arm_x: float = 0.0
var target_rot_z: float = 0.0
var lean_distance: float = 0.4
var lean_tilt: float = 12.0
var in_pause: bool = false

#------State machine------#
enum PlayerState {
	IDLE_STAND,
	IDLE_CROUCH,
	CROUCHING,
	WALKING,
	SPRINTING,
	JUMPING,
	SPRINTING_JUMPING
}

var player_state: PlayerState = PlayerState.IDLE_STAND


func _ready() -> void:
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var gravity_val: float = abs(get_gravity().y)
	if gravity_val == 0.0:
		gravity_val = 9.8
	jump_velocity = sqrt(2.0 * gravity_val * jump_height)
	interaction_ray.add_exception(self)
	
	_setup_blood_vial()


func _setup_blood_vial() -> void:
	# Correct path matching the scene tree: "Blood Vial"
	var vial_node = get_node_or_null("Head/LeanArm/Eyes/Camera3D/Blood Vial")
	
	if vial_node == null:
		push_warning("Blood Vial node not found at path!")
		return
		
	if vial_node.has_node("LiquidCylinder"):
		liquid_mesh = vial_node.get_node("LiquidCylinder") as MeshInstance3D
		if liquid_mesh:
			var mat = liquid_mesh.get_active_material(0)
			if mat and mat is ShaderMaterial:
				# Duplicate material to make it unique to this player instance
				liquid_material = mat.duplicate() as ShaderMaterial
				liquid_mesh.set_surface_override_material(0, liquid_material)
				print("Blood vial material successfully connected!")
			else:
				push_warning("LiquidCylinder does not have a ShaderMaterial assigned in slot 0!")


func is_dead() -> bool:
	return hp <= 0 or position.y <= -50
	
func is_game_over() -> bool:
	return lives == 0

func _input(event: InputEvent) -> void:
	
	if Input.is_action_just_pressed("Esc"):
		# get_tree().quit()
		in_pause = !in_pause
		
	if not in_pause:
		if event is InputEventMouseMotion:
			rotate_y(deg_to_rad(-event.relative.x) * mouse_sens)
			head.rotate_x(deg_to_rad(-event.relative.y) * mouse_sens)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
			
			# Hook mouse motion directly to sloshing physics
			target_slosh.x -= event.relative.x * mouse_slosh_sensitivity
			target_slosh.y += event.relative.y * mouse_slosh_sensitivity
			target_slosh.x = clamp(target_slosh.x, -max_slosh_angle, max_slosh_angle)
			target_slosh.y = clamp(target_slosh.y, -max_slosh_angle, max_slosh_angle)
		
		if Input.is_action_pressed("Interact"):
			if interaction_ray.is_colliding():
				var target = interaction_ray.get_collider()
				
				if target.is_in_group("Interactable"):
					if target.has_method("interact"):
						target.interact()

# This is also for testing
func reset_player() -> void:
	position.x = -0.47
	position.y = 0
	position.z = 0.505
	hp = 100

func _physics_process(delta: float) -> void:
	if is_dead():
		reset_player()
		if lives > 0: lives -= 1
	
	if in_pause:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		backpack.show()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		backpack.hide()
		
		var dx: int = 0
		var dy: int = 0
		if Input.is_action_pressed("Backward"):
			dy = 1
		elif Input.is_action_pressed("Forward"):
			dy = -1
		elif Input.is_action_pressed("Strafe R"):
			dx = 1
		elif Input.is_action_pressed("Strafe L"):
			dx = -1
		
		input_dir = Vector2(
			lerp(0, int(current_speed)*dx, (delta*current_speed)**2),
			lerp(0, int(current_speed)*dy, (delta*current_speed)**2)
		)
		#print(input_dir)
		
		_update_focused_object()
		updatePlayerState(delta)
		updateCamera(delta)
		updateBloodVial(delta) 

		target_arm_x = 0.0
		target_rot_z = 0.0

		if not moving:
			if Input.is_action_pressed("Lean R"):
				target_arm_x = lean_distance
				target_rot_z = -lean_tilt
			elif Input.is_action_pressed("Lean L"):
				target_arm_x = -lean_distance
				target_rot_z = lean_tilt

		lean_arm.position.x = lerp(lean_arm.position.x, target_arm_x, 10.0 * delta)
		camera_3d.rotation.z = lerp(camera_3d.rotation.z, deg_to_rad(target_rot_z), 10.0 * delta)
		
		if not is_on_floor():
			if velocity.y >= 0:
				velocity += get_gravity() * delta * 2.0
			else:
				velocity += get_gravity() * delta * 3.0
		else:
			if Input.is_action_just_pressed("Jump"):
				velocity.y = jump_velocity*1.5

		var target_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if target_dir != Vector3.ZERO:
			velocity.x = target_dir.x * current_speed
			velocity.z = target_dir.z * current_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0

		# Capture fall speed before move_and_slide() zeroes it out on collision
		var pre_move_y_velocity := velocity.y
		move_and_slide()
		
		# Landing detection
		var on_floor_now := is_on_floor()
		if on_floor_now and not was_on_floor:
			var fall_speed : int = abs(pre_move_y_velocity)
			if fall_speed >= landing_shake_min_fall_speed:
				var t: float = clamp(fall_speed / 15.0, 0.0, 1.0)
				landing_shake_intensity = landing_shake_max_intensity * t
				landing_shake_index = 0.0
				landing_shake_time = 0.0
		was_on_floor = on_floor_now
		
		#print(player_state)
		
func move_liquide(amplitude: float, delta: float) -> void:
	var passive_wave := Vector2.ZERO
	passive_wave.x = cos(head_bobbing_index) * amplitude
	passive_wave.y = sin(head_bobbing_index * 2.0) * (amplitude * 0.6)

	target_slosh = target_slosh.move_toward(Vector2.ZERO, sqrt(slosh_recovery_speed * delta*0.5))

	var combined_target := target_slosh + passive_wave
	combined_target.x = clamp(combined_target.x, -max_slosh_angle, max_slosh_angle)
	combined_target.y = clamp(combined_target.y, -max_slosh_angle, max_slosh_angle)

	current_slosh = current_slosh.lerp(combined_target, sqrt(slosh_lerp_speed * delta))
	liquid_material.set_shader_parameter("slosh_angle", current_slosh)

func updateBloodVial(delta: float) -> void:
	if not liquid_material:
		return

	var health_ratio: float = clamp(float(hp) / float(max_hp), 0.0, 1.0)
	liquid_material.set_shader_parameter("health_ratio", health_ratio)

	var slosh_amplitude: float = 0.20
	
	if Input.is_action_pressed("Crouch"):
		move_liquide(slosh_amplitude, delta)

	if moving and is_on_floor():
		match player_state:
			PlayerState.CROUCHING:
				slosh_amplitude = 0.06
			PlayerState.WALKING:
				slosh_amplitude = 0.22
			PlayerState.SPRINTING:
				slosh_amplitude = 0.48
				
	move_liquide(slosh_amplitude, delta)

func updatePlayerState(delta: float) -> void:
	if hp > max_hp: hp = max_hp
	moving = (input_dir != Vector2.ZERO)
	
	if not is_on_floor():
		if current_speed > walking_speed:
			player_state = PlayerState.SPRINTING_JUMPING
		else:
			player_state = PlayerState.JUMPING
		
	else:
		if Input.is_action_pressed("Crouch"):
			player_state = PlayerState.IDLE_CROUCH if not moving else PlayerState.CROUCHING
		elif not standup_check.is_colliding():
			if not moving:
				player_state = PlayerState.IDLE_STAND
			elif Input.is_action_pressed("Sprint"):
				player_state = PlayerState.SPRINTING
			else:
				player_state = PlayerState.WALKING

	updatePlayerColShape(player_state)
	updatePlayerSpeed(player_state, delta)

func updatePlayerColShape(_player_state: PlayerState) -> void:
	var is_crouching = (_player_state == PlayerState.CROUCHING or _player_state == PlayerState.IDLE_CROUCH)
	standing_collision_shape.disabled = is_crouching
	crouching_collision_shape.disabled = not is_crouching

func updatePlayerSpeed(_player_state: PlayerState, delta: float) -> void:
	match _player_state:
		PlayerState.CROUCHING, PlayerState.IDLE_CROUCH:
			current_speed = crouching_speed
		PlayerState.WALKING, PlayerState.IDLE_STAND:
			current_speed = walking_speed
		PlayerState.SPRINTING:
			if current_speed < walking_speed:current_speed = walking_speed
			current_speed = move_toward(current_speed, sprinting_speed, sprint_accel_rate * delta)

func updateCamera(delta: float) -> void:
	var target_fov = Base_FOV
	var target_intensity: float = 0.0
	var bob_frequency: float = 0.0
	var speed := sqrt(delta * lerp_speed)
	
	match player_state:
		PlayerState.CROUCHING:
			head.position.y = lerp(head.position.y, 1.8 + crouching_depth, speed)
			target_fov = Base_FOV * 0.95
			target_intensity = head_bobbing_crouching_intensity
			bob_frequency = head_bobbing_crouching_speed
		
		PlayerState.IDLE_CROUCH:
			head.position.y = lerp(head.position.y, 1.8 + crouching_depth, speed)
			target_fov = Base_FOV * 0.95
			target_intensity = 0.0
			
		PlayerState.IDLE_STAND, PlayerState.JUMPING:
			head.position.y = lerp(head.position.y, 1.8, speed)
			target_fov = Base_FOV
			target_intensity = 0.0
			
		PlayerState.WALKING:
			head.position.y = lerp(head.position.y, 1.8, speed)
			target_fov = Base_FOV
			target_intensity = head_bobbing_walking_intensity
			bob_frequency = head_bobbing_walking_speed
			
		PlayerState.SPRINTING, PlayerState.SPRINTING_JUMPING:
			head.position.y = lerp(head.position.y, 1.8, speed)
			target_fov = Base_FOV * 1.15
			target_intensity = head_bobbing_sprinting_intensity
			bob_frequency = head_bobbing_sprinting_speed

	camera_3d.fov = lerp(camera_3d.fov, target_fov, speed)
	head_bobbing_current_intensity = lerp(head_bobbing_current_intensity, target_intensity, speed)

	if moving and is_on_floor():
		head_bobbing_index += bob_frequency * delta
		
		var bob_y = sin(head_bobbing_index) * head_bobbing_current_intensity
		var bob_x = cos(head_bobbing_index * 0.5) * (head_bobbing_current_intensity * 0.5)
		
		camera_3d.position.y = bob_y
		camera_3d.position.x = bob_x
	else:
		camera_3d.position.y = lerp(camera_3d.position.y, 0.0, speed)
		camera_3d.position.x = lerp(camera_3d.position.x, 0.0, speed)
	
	# Landing shake (applied on top of head bob)
	var shake := updateLandingShake(delta)
	camera_3d.position += shake

func updateLandingShake(delta: float) -> Vector3:
	if landing_shake_intensity <= 0.001:
		landing_shake_intensity = 0.0
		return Vector3.ZERO
	
	landing_shake_time += delta
	landing_shake_index += landing_shake_frequency * delta
	
	# Two slightly different frequencies so it doesn't look like a pure sine
	var shake_x := sin(landing_shake_index) * landing_shake_intensity*2
	var shake_y := cos(landing_shake_index * 1.3) * landing_shake_intensity*2 * 0.8
	
	# Decay
	landing_shake_intensity = move_toward(landing_shake_intensity, 0.0, landing_shake_decay * delta)
	
	return Vector3(shake_x, shake_y, 0.0)

func interact():
	pass

func _on_interactable_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Interactable") and body.has_method("set_in_range"):
		body.set_in_range(true)

func _on_interactable_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("Interactable") and body.has_method("set_in_range"):
		body.set_in_range(false)

func _update_focused_object() -> void:
	var new_target = null
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider and collider.is_in_group("Interactable"):
			new_target = collider

	if new_target != current_focused_object:
		if current_focused_object and is_instance_valid(current_focused_object):
			if current_focused_object.has_method("set_focused"):
				current_focused_object.set_focused(false)

		current_focused_object = new_target

		if current_focused_object and current_focused_object.has_method("set_focused"):
			current_focused_object.set_focused(true)

func take_damage(damage_amount: int) -> void:
	var dt := get_process_delta_time()
	var f := (dt*health_drop_speed)**2
	var target_hp: int = clamp(hp - damage_amount, 0, max_hp)
	
	while hp > target_hp: hp = lerp(hp, target_hp, f)
	print("Player took", damage_amount, " damage! Current HP: ", hp)
	
func heal_hp(heal_amont: int) -> void:
	var dt := get_process_delta_time()
	var f := (dt*health_drop_speed)**2
	if hp < max_hp:
		hp = lerp(hp + heal_amont, hp, f)
	else:
		print("Reached max health")
