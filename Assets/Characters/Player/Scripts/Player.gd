extends KinematicBody2D

var Shot : PackedScene = load("res://Assets/Characters/Player/Shot.tscn")

const SPEED = 128
const FLOOR = Vector2(0, -1)
const GRAVITY = 16
const JUMP_HEIGHT = 368 # Esta constante define la fuerza del salto.
const BOUNCING_JUMP = 128 # Esta constante es para definir la fuerza de rebote en la pared.

# Al añadir Coyote Time, ya no es necesario la variable can_move, que solo estábamos usando en este caso para la función de rebote.
var motion : Vector2 = Vector2.ZERO
var jump : int # Para el doble salto vamos a crear una variable llamada can_jump del tipo int.
var max_jump : int = 2 # Y definimos una cantidad de veces que podemos saltar.

var immunity : bool = false # Esto es para crear el estado de inmunidad en el player.
var health : int = 5 # Con esta variable contabilizamos la salud del player.

""" STATE MACHINE """
var playback : AnimationNodeStateMachinePlayback

func _ready():
	playback = $AnimationTree.get("parameters/playback") # Obtenemos la referencia al parámetro playback del nodo AnimationTree.
	playback.start("Idle") # Iniciamos en el estado Idle.


func _process(_delta):
	motion_ctrl()
	jump_ctrl()
	attack_ctrl()


func motion_ctrl() -> void: # Al separar los comportamientos en distintas funciones, la función de movimiento ha quedado mucho más limpia y comprensible a simple vista.
	motion.y += GRAVITY
	motion.x =  GLOBAL.get_axis().x * SPEED
	
	if GLOBAL.get_axis().x == 0:
		playback.travel("Idle")
	elif GLOBAL.get_axis().x == 1:
		playback.travel("Run")
		$Sprite.flip_h = false
	elif GLOBAL.get_axis().x == -1:
		playback.travel("Run")
		$Sprite.flip_h = true
		
	match playback.get_current_node():
		"Idle":
			motion.x =  0
			$Particles.emitting = false
		"Run":
			$Particles.emitting = true
				
	match $Sprite.flip_h: # Usando como referencia la propiedad flip_h del nodo Sprite vamos a saber en qué posición debe estar viendo el jugador.
		true:
			$View.scale.x = -1
		false:
			$View.scale.x = 1
			
	var slide_count = get_slide_count() # Retorna el número de veces que el cuerpo está colisionando.
	
	if slide_count: # Si slide_count es superior a 0 significa que es true, por lo tanto se cumple la condición.
		var collision = get_slide_collision(slide_count - 1) # Así que guardamos en una variable el objeto colisionado.
		
		if collision != null: # Si la variable collision devuelve un valor distinto de null significa que ha colisionado.
			# Si el objeto colisionado pertenece al grupo Platform y presionamos la tecla de dirección inferior.
			if collision.collider.is_in_group("Platform") and Input.is_action_just_pressed("ui_down"): 
				$Collision.disabled = true # Desactivamos el collider del player
				$Timers/Collision.start() # Y activamos el timer.
			
	motion = move_and_slide(motion, FLOOR)


func jump_ctrl() -> void: # Separo la función de salto para mantener el orden y facilitar la lectura del código.
	match is_on_floor(): # Comprobamos si el personaje se encuentra tocando el suelo.
		true:
			jump = max_jump # En caso afirmativo, restablece jump para poder saltar nuevamente.
		false:
			$Particles.emitting = false # En caso negativo, se desactiva la emisión de partículas.
			
			if motion.y < 0:
				playback.travel("Jump")
			else:
				playback.travel("Fall")
				
	# Si la variable Jump es superior a cero y no se encuentra cayendo, podemos saltar.
	if jump > 0 and not playback.get_current_node() == "Fall":
		if Input.is_action_just_pressed("jump"):
			jump_event()
			
	else: # En caso contrario.
		if $View/Wall.is_colliding(): # Comprobamos si ha colisionado, de lo contrario arrojaría un error.
			var body = $View/Wall.get_collider() # Creo esta variable para guardar las colisiones.
			
			if body.is_in_group("Terrain"): # Comprobamos si el personaje se encuentra tocando la pared.
				$Timers/CoyoteTime.start()
		
		# Si el tiempo restante es superior a cero y presionamos la tecla de salto, podemos rebotar en la pared.
		if jump > 0 and $Timers/CoyoteTime.time_left > 0:
			if Input.is_action_just_pressed("jump"):
				jump_event()


func jump_event(): # Creamos esta función para reciclar código y facilitar la lectura del script.
	jump -= 1 # Cuando realice un salto restamos 1 a la variable jump.
	$Sounds/Jump.play()
	
	match playback.get_current_node():
		"Idle", "Run":
			motion.y -= JUMP_HEIGHT
		"Jump":
			motion.y -= JUMP_HEIGHT / 1.4


func attack_ctrl() -> void: # Creamos una función para controlar el ataque del personaje.
	var body = $View/Hit.get_collider() # Utilizamos el mismo procedimiento que para detectar la colisión con la pared.
	
	if is_on_floor():
		# Separo la condición donde se comprueba el movimiento para añadir la función de disparo.
		if GLOBAL.get_axis().x == 0:
			
			# Añado la condición not Input.is_action_just_pressed("shot") para que no ataque con espada mientras dispara.
			if Input.is_action_just_pressed("attack") and not Input.is_action_just_pressed("shot"):
				match playback.get_current_node():
					"Idle":
						playback.travel("Attack-1")
						$Sounds/Sword.play()
					"Attack-1":
						playback.travel("Attack-2")
						$Sounds/Sword.play()
					"Attack-2":
						playback.travel("Attack-3")
						$Sounds/Sword.play()
						
				if $View/Hit.is_colliding(): 
					if body.is_in_group("Enemy"):
						body.damage_ctrl(3)
						
			# Si powerful_shot es igual a false y pulsamos la tecla de disparo:
			elif not GLOBAL.powerful_shot and Input.is_action_just_pressed("shot"):
				match playback.get_current_node():
					"Idle":
						playback.travel("Shot")
						shot_ctrl()


func shot_ctrl():
	var shot = Shot.instance()
	shot.global_position = $View/ShotSpawn.global_position
	
	if $Sprite.flip_h:
		shot.scale.x = -1
		shot.direction = -224
	else:
		shot.scale.x = 1
		shot.direction = 224
	
	get_tree().call_group("Level", "add_child", shot)


func damage_ctrl(damage : int) -> void: # Creamos la función para controlar el daño recibido.
	match immunity:
		false: # Si el personaje no se encuentra en estado de inmunidad debe recibir daño.
			health -= damage # Se resta 1 a la salud.
			$AnimationPlayer.play("Hit") # Se reproduce la animación de daño.
			$Sounds/Hit.play() # Se reproduce el sonido de daño.
			immunity = true # Y por un momento se hace inmune.


func _on_AnimationPlayer_animation_finished(anim_name):
	match anim_name:
		"Hit":
			immunity = false # Y cuando termina deja de ser inmune.


func _on_Collision_timeout():
	# Cuando el tiempo termina, se activa nuevamente el collider, es una forma de hacer esto.
	$Collision.disabled = false
