## Генератор иконки игры: рисует её кодом и сохраняет в res://icon.png.
## Запуск: godot --headless --path . --script res://tools/make_icon.gd
extends SceneTree

const SIZE := 256
const BG := Color(0.07, 0.09, 0.13)
const BORDER := Color(0.95, 0.65, 0.25)
const INK := Color(1.0, 0.8, 0.32)
const INK_SOFT := Color(0.62, 0.72, 0.9)


func _initialize() -> void:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(BG)

	# Рамка.
	_frame(img, 8, BORDER)
	_frame(img, 14, Color(0.95, 0.65, 0.25, 0.25))

	var center := SIZE / 2
	# Перекрестие прицела: четыре луча с зазором и точка в центре.
	_bar(img, center - 3, center - 36, 7, 28, INK)
	_bar(img, center - 3, center + 17, 7, 28, INK)
	_bar(img, center - 36, center - 3, 28, 7, INK)
	_bar(img, center + 17, center - 3, 28, 7, INK)
	_disc(img, center, center, 5, Color.WHITE)

	# Диагональные штрихи по углам — «арена».
	_bar(img, 40, 40, 5, 26, INK_SOFT)
	_bar(img, 40, 40, 26, 5, INK_SOFT)
	_bar(img, SIZE - 66, SIZE - 45, 26, 5, INK_SOFT)
	_bar(img, SIZE - 45, SIZE - 66, 5, 26, INK_SOFT)

	img.save_png("res://icon.png")
	print("[icon] сохранено: res://icon.png")
	quit()


func _frame(img: Image, margin: int, color: Color) -> void:
	var end := SIZE - margin
	for x in range(margin, end):
		for y in [margin, margin + 1, end - 2, end - 1]:
			img.set_pixel(x, y, color)
	for y in range(margin, end):
		for x in [margin, margin + 1, end - 2, end - 1]:
			img.set_pixel(x, y, color)


func _bar(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for px in range(x, x + w):
		for py in range(y, y + h):
			if px >= 0 and py >= 0 and px < SIZE and py < SIZE:
				img.set_pixel(px, py, color)


func _disc(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for x in range(cx - radius, cx + radius + 1):
		for y in range(cy - radius, cy + radius + 1):
			var dx := float(x - cx)
			var dy := float(y - cy)
			if dx * dx + dy * dy <= float(radius * radius):
				img.set_pixel(x, y, color)
