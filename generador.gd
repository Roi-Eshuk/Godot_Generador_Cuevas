extends Node2D

#Modo revisión
@export var modo_revision: bool = true
var corriendo_revision: bool = false

#Cámara
@onready var camara: Camera2D = $Camera2D
@export var velocidad_camara: int = 350

#Configuración del lienzo
@onready var mapa: TileMapLayer = $TileMapLayer
var cueva: = []
var pivote: = []
@export var ancho: int = 35
@export var alto: int = 35
enum {vacio, lleno, vacio_procesar, lleno_procesar}

#Llenado inicial
@export var densidad: int = 50

#Dado aleatorio
var dado: RandomNumberGenerator = RandomNumberGenerator.new()
@export var usar_semilla: bool = true
@export var semilla: String = "Roi Eshuk"

func _process(delta: float) -> void:
	mover_camara(delta)

func _ready() -> void:
	if not modo_revision:
		generar_cueva()
	else:
		print("Corriendo en modo de revisión. Presiona ENTER para iniciar.")

func mover_camara(delta: float) -> void:
	var dir_camara = Vector2.ZERO
	dir_camara.x = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	dir_camara.y = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	if dir_camara != Vector2.ZERO:
		camara.position += dir_camara * velocidad_camara * delta

func _input(event) -> void:
	if OS.is_debug_build() and event.is_action_pressed("ui_accept") and not corriendo_revision:
		corriendo_revision = true
		generar_cueva()

func esperar_teclado(mensaje: String = "Siguiente paso.") -> void:
	if OS.is_debug_build() and modo_revision and corriendo_revision:
		dibujar_cueva(cueva)
		print("SIGUIENTE PASO: " + mensaje)
		while true:
			await get_tree().process_frame
			if Input.is_action_just_pressed("ui_siguiente"):
				break

func generar_cueva() -> void:

	await esperar_teclado("Reestablecer variables.")
	reestablecer_variables()

	await esperar_teclado("Llenar cueva.")
	llenar_cueva(cueva)
	
	await esperar_teclado("¡Cueva terminada! Preseiona ENTER para empezar de nuevo.")
	corriendo_revision = false

func reestablecer_variables() -> void:
	formar_matriz(cueva, ancho, alto, 0)
	formar_matriz(pivote, ancho, alto, 0)
	if OS.is_debug_build() and modo_revision:
		print("Variables reestablecidas.")

func formar_matriz(matriz: Array, filas: int = ancho, columnas: int = alto, valor: int = 0) -> Array:
	matriz.clear()
	for i in range(filas):
		var columna: = []
		for j in range(columnas):
			columna.append(valor)
		matriz.append(columna)
	return matriz

func dibujar_cueva(matriz: = cueva, esquina_x: int = 0, esquina_y: int = 0) -> void:
	if matriz.size() > 0:
		for x in range(ancho):
			for y in range(alto):
				mapa.set_cell(Vector2i(esquina_x + x, esquina_y + y), 0, Vector2i(matriz[x][y], 0))

func llenar_cueva(matriz: Array = cueva) -> void:
	
	tirar_dado()
	
	var vaciar: int = 0
	for x in range(ancho):
		for y in range(alto):
			matriz[x][y] = 0
			if x == 0 or y == 0 or x == ancho - 1 or y == alto - 1:
				matriz[x][y] = lleno
			else:
				vaciar = dado.randi_range(0, 100)
				matriz[x][y] = vacio if vaciar > densidad else lleno

func tirar_dado() -> void:
	if usar_semilla:
		if semilla.is_valid_int():
			dado.seed = semilla.to_int()
		else:
			dado.seed = hash(semilla)
	else:
		dado.randomize()
