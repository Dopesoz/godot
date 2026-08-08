class_name UiLayer
extends CanvasLayer

## Общая основа для всех слоёв интерфейса: HUD, всплывающие листы, панель
## подтверждения постройки.
##
## Единственная её задача — держать корневой Control ровно по видимой области
## экрана. Это звучит как мелочь, но именно здесь интерфейс дважды разъезжался
## на телефоне, поэтому страховка тройная:
##
##   1. якоря на всю площадь — движок сам тянет корень за родительской областью;
##   2. подписка на size_changed — окно на Android получает настоящий размер
##      уже после старта;
##   3. сверка размера каждый кадр — сигнал приходит раньше, чем вьюпорт
##      пересчитывает видимую область при растяжении, и одного сигнала мало.
##
## Третий пункт стоит два сравнения float в кадр и снимает целый класс
## расхождений между эмулятором и настоящим устройством.

var _root: Control = null

## Размер, под который раскладка уже подогнана.
var _fitted_size: Vector2 = Vector2.ZERO


## Наследник обязан вызвать это, как только создал корневой Control.
func attach_root(root: Control) -> void:
	_root = root
	set_process(true)
	_apply_layout()
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_apply_layout):
		viewport.size_changed.connect(_apply_layout)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PROCESS:
		var current: Vector2 = viewport_size()
		if current != _fitted_size and current.x > 0.0:
			_apply_layout()


func viewport_size() -> Vector2:
	var viewport: Viewport = get_viewport()
	return Vector2.ZERO if viewport == null else viewport.get_visible_rect().size


func _apply_layout() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	_fitted_size = viewport_size()
	UiWidgets.fit_to_viewport(_root)
	_fit_layout()


## Точка расширения: пересчёт отступов под безопасную зону и ширину экрана.
func _fit_layout() -> void:
	pass
