extends CanvasLayer

@onready var location_label: Label = $Label

var _tween: Tween

func _ready() -> void:
	if location_label:
		location_label.modulate.a = 0.0

func display_location(text_name: String) -> void:
	if not location_label:
		return
		
	location_label.text = text_name
	
	if _tween and _tween.is_running():
		_tween.kill()
		
	_tween = create_tween()
	
	#fade in and out
	_tween.tween_property(location_label, "modulate:a", 1.0, 0.6)
	_tween.tween_interval(2.0)
	_tween.tween_property(location_label, "modulate:a", 0.0, 1.0)
