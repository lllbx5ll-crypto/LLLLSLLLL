extends CharacterBody3D
## Third-person playable character. Capsule collision with a primitive human-shaped visual.

const WALK_SPEED: float = 6.2
const GRAVITY: float = 18.0
var touch_move: Vector2 = Vector2.ZERO
var footstep_clock: float = 0.0
var animated_legs: Array[Node3D] = []

func _ready() -> void:
	name = "Player"
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.78
	capsule.radius = 0.32
	collider.shape = capsule
	collider.position.y = 0.91
	add_child(collider)
	var clothes := StandardMaterial3D.new()
	clothes.albedo_color = Color(0.12, 0.32, 0.52)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.64, 0.39, 0.26)
	var pants := StandardMaterial3D.new()
	pants.albedo_color = Color(0.12, 0.13, 0.19)
	var hair := StandardMaterial3D.new()
	hair.albedo_color = Color(0.09, 0.07, 0.06)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.96, 0.92)
	_mesh_box("Torso", Vector3(0, 1.16, 0), Vector3(0.66, 0.70, 0.32), clothes)
	_mesh_sphere("Face", Vector3(0, 1.77, 0), 0.27, skin)
	_mesh_box("Hair", Vector3(0, 2.01, 0.02), Vector3(0.48, 0.13, 0.44), hair)
	_mesh_box("LeftArm", Vector3(-0.43, 1.1, 0), Vector3(0.19, 0.65, 0.22), clothes)
	_mesh_box("RightArm", Vector3(0.43, 1.1, 0), Vector3(0.19, 0.65, 0.22), clothes)
	_mesh_sphere("LeftEye", Vector3(-0.105, 1.79, -0.245), 0.035, white)
	_mesh_sphere("RightEye", Vector3(0.105, 1.79, -0.245), 0.035, white)
	var left: Node3D = _mesh_box("LeftLeg", Vector3(-0.18, 0.42, 0), Vector3(0.23, 0.79, 0.25), pants)
	var right: Node3D = _mesh_box("RightLeg", Vector3(0.18, 0.42, 0), Vector3(0.23, 0.79, 0.25), pants)
	animated_legs = [left, right]

func _mesh_box(label: String, offset: Vector3, size: Vector3, material: Material) -> Node3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh_node.mesh = box
	mesh_node.material_override = material
	mesh_node.position = offset
	add_child(mesh_node)
	return mesh_node

func _mesh_sphere(label: String, offset: Vector3, radius: float, material: Material) -> Node3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = label
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_node.mesh = sphere
	mesh_node.material_override = material
	mesh_node.position = offset
	add_child(mesh_node)
	return mesh_node

func _physics_process(delta: float) -> void:
	var horizontal: float = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var vertical: float = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	var input_direction := Vector2(horizontal, vertical)
	if touch_move.length() > 0.05:
		input_direction = touch_move
	input_direction = input_direction.limit_length()
	var direction := Vector3(input_direction.x, 0.0, input_direction.y)
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	if direction.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 12.0)
		footstep_clock += delta * 11.0
		if animated_legs.size() == 2:
			animated_legs[0].rotation.x = sin(footstep_clock) * 0.45
			animated_legs[1].rotation.x = -sin(footstep_clock) * 0.45
	else:
		if animated_legs.size() == 2:
			animated_legs[0].rotation.x = lerpf(animated_legs[0].rotation.x, 0.0, delta * 8)
			animated_legs[1].rotation.x = lerpf(animated_legs[1].rotation.x, 0.0, delta * 8)
