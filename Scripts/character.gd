extends CharacterBody2D

var speed_atual = 450.0
const CHAIN_MAX_LENGTH = 750.0
const JUMP_VELOCITY = -450.0
const MAX_JUMPS = 2

const DASH_SPEED = 200.0
const DASH_DURATION = 0.8
const DASH_COOLDOWN_MAX = 2.0  # Tempo de espera em segundos entre um dash e outro
var dash_cooldown_timer = 0.0  # Cronômetro que vai diminuindo até chegar a 0

const HOOK_COOLDOWN_MAX = 0.7
var hook_cooldown_timer = 0.0

const SLIDE_DURATION = 0.5
const SLIDE_COOLDOWN_MAX = 0.5
var slide_cooldown_timer = 0.0

@export var aceleracao_por_segundo: float = 10.0

# Distância ideal que o centro/pé do player deve ficar do chão
# Ajuste este valor baseado no tamanho do seu sprite (ex: 32 ou 64 pixels)
var distancia_alvo_chao: float = 0.0

var jump_count = 0
var is_dashing = false
var dashTimer = 0.0
var is_sliding = false
var slideTimer = 0.0
var no_chao = false # Substitui o is_on_floor() nativo

var is_hooking = false
var chain_velocity := Vector2(0,0)
@export var CHAIN_PULL = 30

var altura_normal : float
var posicao_y_normal : float
const ALTURA_SLIDE = 30.0    # Nova altura/tamanho vertical durante o slide
const OFFSET_Y_SLIDE = 40.0  # Deslocamento para baixo (deve ser metade da diferença de altura)


var pontuacao: float = 0.0
@onready var label_pontuacao = $"../CanvasLayer/LabelPontuacao" # Ajuste o caminho para a sua UI

@onready var sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var raycast = $RayCast2D # Adicione o seu nó RayCast2D aqui
@onready var chain = $Chain
@onready var raycastTeto = $RayCastTeto

func _ready():
	# Garante que o RayCast está ativo
	raycast.enabled = true
	
	# Pega a textura do frame atual da animação do sprite
	var textura_atual = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if textura_atual:
		# A altura total dividida por 2 dá a distância exata do centro até o pé
		distancia_alvo_chao = (textura_atual.get_size().y / 4.0) / 2.0
	else:
		# Um valor de segurança caso o sprite falhe ao carregar no primeiro frame
		distancia_alvo_chao = 32.0 
		
	# Ajusta o RayCast automaticamente para apontar um pouco além do pé (ex: 20 pixels a mais)
	raycast.target_position = Vector2(0, distancia_alvo_chao + 20.0)
	
	# Deteta automaticamente se o formato é retângulo ou cápsula e guarda o tamanho inicial
	if collision_shape.shape is CapsuleShape2D:
		altura_normal = collision_shape.shape.height
	elif collision_shape.shape is RectangleShape2D:
		altura_normal = collision_shape.shape.size.y
		
	posicao_y_normal = collision_shape.position.y

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if !is_dashing and !is_sliding:
			if event.pressed and hook_cooldown_timer <= 0:
				# GODOT 4 FIX: Usar a posição global do rato garante precisão com câmaras
				atirar_corrente()
			else:
				# We released the mouse -> release()
				soltar_corrente()

func _physics_process(delta: float) -> void:
	if global_position.y > 1580:
		morrer()
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if slide_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if hook_cooldown_timer > 0:
		hook_cooldown_timer -= delta
	
	# Atualiza o estado do chão usando o RayCast antes de qualquer lógica
	verificar_chao_com_raycast()
	
	# Verifica colisão com paredes (Morte)
	verificar_colisao_parede()
	
	if chain.hooked:         
		# `to_local($Chain.tip).normalized()` is the direction that the chain is pulling
		chain_velocity = to_local(chain.tip).normalized() * CHAIN_PULL
		if chain_velocity.y > 0:
			# Pulling down isn't as strong
			chain_velocity.y *= 0.55
		else:
			# Pulling up is stronger
			chain_velocity.y *= 1.65
	else:
		# Not hooked -> no chain velocity
		chain_velocity = Vector2(0,0)
		if is_hooking and chain.current_length > CHAIN_MAX_LENGTH:
			soltar_corrente()
	velocity += chain_velocity
	
	if is_dashing:
		dashTimer -= delta
		#velocity.x = DASH_SPEED
		velocity.x = speed_atual + DASH_SPEED
		velocity.y = 0 # Garante que não cai durante o dash
		if dashTimer <= 0:
			is_dashing = false
		
		move_and_slide()
		return
	
	if is_sliding:
		slideTimer -= delta
		velocity.x = speed_atual
		if slideTimer <= 0 or !no_chao:
			end_slide()
		
		move_and_slide()
		return
	
	if not no_chao:
		velocity += get_gravity() * delta
		if velocity.y > -1.0 and !is_hooking:    #mudando pra caindo um pouco antes de inverter, talvez?
			sprite.play("Falling")
	else:
		#if dash_cooldown_timer > 0:
			#dash_cooldown_timer = 0.0
		if !is_sliding and !is_hooking:
			jump_count = 0
			sprite.play("Running")
		else:
			pass
	
	# Handle jump.
	if Input.is_action_just_pressed("Jump"):
		if no_chao or jump_count < MAX_JUMPS:
			#if sprite.animation != "Jumping":
			sprite.play("Jumping")
			velocity.y = JUMP_VELOCITY
			jump_count += 1
			no_chao = false # Desgruda do chão imediatamente ao pular
		
	if Input.is_action_just_pressed("Dash") and dash_cooldown_timer <= 0 and !is_hooking and !is_sliding:
		start_dash()
	
	if Input.is_action_just_pressed("Slide") and !is_hooking and !is_dashing and no_chao and slide_cooldown_timer <= 0:
		start_slide()
	
	speed_atual += aceleracao_por_segundo * delta
	
	if !is_dashing:
		velocity.x = speed_atual
	else:
		velocity.x = speed_atual + DASH_SPEED

	move_and_slide()
	
	# --- SISTEMA DE PONTUAÇÃO ESTILO ROBOT UNICORN ATTACK ---
	# velocity.x * delta dá exatamente quantos pixels o player andou neste frame.
	# Multiplicamos por 0.1 para equilibrar o valor e não deixar os números grandes demais rápido demais.
	var pontos_deste_frame = velocity.x * delta * 0.1
	pontuacao += pontos_deste_frame

	# Atualiza o texto na tela (arredondando para número inteiro para não mostrar os decimais)
	if is_instance_valid(label_pontuacao):
		label_pontuacao.text = "  SCORE\n    " + str(floor(pontuacao))

func verificar_chao_com_raycast() -> void:
	# Só checa o chão se o jogador estiver caindo ou parado verticalmente (ajuda no pulo)
	if velocity.y >= 0 and raycast.is_colliding():
		var ponto_colisao_y = raycast.get_collision_point().y
		
		# Calcula a distância atual entre o Player e o ponto de colisão
		var distancia_atual = ponto_colisao_y - global_position.y
		
		# Se estiver perto o suficiente do chão, ativa o estado de "no_chao"
		if distancia_atual <= distancia_alvo_chao + 5.0: # Margem de erro de 5px
			no_chao = true
			velocity.y = 0
			# Ajusta a posição Y do jogador perfeitamente para ele não afundar nem flutuar
			global_position.y = ponto_colisao_y - distancia_alvo_chao
			return
			
	no_chao = false

func verificar_colisao_parede() -> void:
	# Como usamos o move_and_slide(), se o player bater de frente numa parede, 
	# a Godot vai gerar colisões cinemáticas.
	for i in range(get_slide_collision_count()):
		var colisao = get_slide_collision(i)
		var normal = colisao.get_normal()
		
		# Se a normal apontar para a esquerda (Vector2.LEFT), significa que batemos de frente numa parede vindo da esquerda
		# Se a normal tiver um X negativo significativo, é uma parede vertical à nossa frente.
		if normal.x < -0.7:
			morrer()

func soltar_corrente() -> void:
	sprite.play("Hooked_Arm")
	if chain.hooked:
		dash_cooldown_timer = 0.0
		hook_cooldown_timer = HOOK_COOLDOWN_MAX
		#start_dash()     #testar se dar dash ou resetar o dash apos soltar o hook
	chain.release()
	if is_hooking:
		is_hooking = false

func atirar_corrente() -> void:
	var mouse_pos = get_global_mouse_position()
	
	if mouse_pos.x <= global_position.x:
		return 
	
	if no_chao:
		sprite.play("Shooting")
	else:
		sprite.play("Hooked")
	
	var target_dir = mouse_pos - global_position
	chain.shoot(target_dir)
	if !is_hooking:
		is_hooking = true

func morrer() -> void:
	print("O Player morreu!")
	
	# 1. Envia a pontuação para o script global
	GameManager.atualizar_pontuacao(pontuacao)
	
	# 2. Desativa o processamento do Player para ele não se mover nem receber inputs
	set_physics_process(false)
	set_process(false)
	
	# Opcional: Se quiseres esconder o boneco ou tocar uma animação de morte:
	# sprite.play("Death") 
	# $CollisionShape2D.queue_free() # Desativa colisões para ele não bater em nada enquanto cai
	
	GameManager.trocar_pra_gameover()


func start_dash():
	sprite.play("Dashing")
	is_dashing = true
	dashTimer = DASH_DURATION
	velocity.y = 0.0
	no_chao = false
	dash_cooldown_timer = DASH_COOLDOWN_MAX
	#if jump_count > 0:
		#jump_count -= 1

func start_slide():
	sprite.play("Sliding")
	is_sliding = true
	slideTimer = SLIDE_DURATION
	
	if collision_shape.shape is CapsuleShape2D:
		collision_shape.shape.height = ALTURA_SLIDE
	elif collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size.y = ALTURA_SLIDE
		
	# Move a caixa de colisão para baixo para manter os "pés" no chão
	collision_shape.position.y = posicao_y_normal + OFFSET_Y_SLIDE

func end_slide():
	if !raycastTeto.is_colliding():
		is_sliding = false
		if collision_shape.shape is CapsuleShape2D:
			collision_shape.shape.height = altura_normal
		elif collision_shape.shape is RectangleShape2D:
			collision_shape.shape.size.y = altura_normal
		
	# Restaura a posição original da colisão
		collision_shape.position.y = posicao_y_normal
	

func getIsDashing() -> bool:
	if is_dashing:
		return true
	else:
		return false

func addPontos(pontos: float) -> void:
	pontuacao += pontos
	dash_cooldown_timer = 0.0     #reseta dash
