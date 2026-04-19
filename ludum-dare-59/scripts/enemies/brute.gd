class_name Brute
extends Enemy


func _ready() -> void:
	super()
	AudioManager.play_sfx(AudioManager.SFX_BRUTE_LASER)


func _get_balance_id() -> String:
	return "brute"
