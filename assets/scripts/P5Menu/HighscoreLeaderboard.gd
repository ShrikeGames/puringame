extends Node2D
class_name Leaderboard
@export var scores_node:Node2D
@export var rank_image_en:Sprite2D
@export var rank_image_jp:Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	self.visible = false
	update()
	self.visible = true


func update():
	rank_image_jp.visible = Global.language == "jp"
	rank_image_en.visible = Global.language != "jp"
	
	# load player config
	# load default config
	# get history of scores from both and append
	# sort list
	# update names for the top 9
	var player_json = Global.read_json("user://player.json")
	var default_json = Global.read_json("res://default.json")
	var ai_json = Global.read_json("user://ai_v2.json")
	var ai_default_json = Global.read_json("res://ai_v2.json")
	var player_scores:Array = [{
			"score":0,
			"board_state": [],
		}]
	var default_scores:Array = default_json.get("leaderboard", [])
	var ai_scores:Array = []
	if player_json:
		player_scores = player_json.get("history", [])
	if ai_json:
		ai_scores = ai_json.get("history", [])
	else:
		ai_scores = ai_default_json.get("history", [{}])
	
	if not ai_scores[0].has("username"):
		ai_scores[0]["username"] = "AI"
		ai_scores[0]["username_jp"] = "AI"
		
	
	var ranked_history = player_scores+default_scores+[ai_scores[0]]
	ranked_history.sort_custom(rank_history)
	var num_ranks = min(9, len(ranked_history))
	ranked_history = ranked_history.slice(0, num_ranks)
	
	for rank in range(0, num_ranks):
		var highscore_record:Dictionary = ranked_history[rank]
		var rank_name_level:RichTextLabel = scores_node.get_child(rank)
		var username = "player"
		if highscore_record.has("username") and highscore_record.has("username_jp"):
			if Global.language == "jp":
				username = highscore_record.get("username_jp")
			else:
				username = highscore_record.get("username")
		else:
			if Global.language == "jp":
				username = "[color=ebff8b]あなた[/color]"
			else:
				username = "[color=ebff8b]You[/color]"
		var score = highscore_record.get("score")
		rank_name_level.text = "%s - %s"%[username, score]

func rank_history(run1:Dictionary, run2:Dictionary):
	if run1.get("score", 0) > run2.get("score", 0):
		return true
	return false
