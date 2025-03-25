extends Node2D

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

func _process(delta: float) -> void:
	mover_camara(delta)

func _ready() -> void:
	formar_matriz(cueva, ancho, alto, 0)
	formar_matriz(pivote, ancho, alto, 0)
	dibujar_cueva()

func mover_camara(delta: float) -> void:
	var dir_camara = Vector2.ZERO
	dir_camara.x = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	dir_camara.y = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	if dir_camara != Vector2.ZERO:
		camara.position += dir_camara * velocidad_camara * delta

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
