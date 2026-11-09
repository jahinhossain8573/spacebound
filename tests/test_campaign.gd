extends SceneTree

var failures := 0
var manager: Node
var data: Node

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1

func run_tests() -> void:
	manager = root.get_node("GameManager")
	data = root.get_node("GlobalData")
	manager.save_path = "user://spa10-test-%d.json" % Time.get_ticks_usec()
	check(manager.new_campaign() == OK, "new campaign save")
	check(manager.is_mission_unlocked(1) and not manager.is_mission_unlocked(2), "mission gates")
	check("pwr_gomspace_p31u" in manager.unlocked_part_ids, "tier zero parts")
	var baseline_connections: int = manager.campaign_changed.get_connections().size()
	for i in 3:
		var select = load("res://scenes/MissionSelect.tscn").instantiate()
		root.add_child(select)
		check(manager.campaign_changed.get_connections().size() == baseline_connections + 1, "mission select has one scene-owned connection")
		manager.science_points += 1
		manager.campaign_changed.emit()
		check(select._balance_label.text.contains("%d SP" % manager.science_points), "visible balance updates")
		manager.debug_unlock_missions = true
		manager.campaign_changed.emit()
		check(not select._mission_buttons[2].disabled, "visible mission gate updates")
		manager.debug_unlock_missions = false
		select.free()
		check(manager.campaign_changed.get_connections().size() == baseline_connections, "mission select disconnects after navigation")
		manager.campaign_changed.emit()
	manager.science_points = 0
	var loss := {"mission_number":1, "launched":false, "objectives":[{"done":false}], "mass_margin_pct":20.0}
	var score: Dictionary = manager.compute_score(loss)
	check(score.outcome == "Mission Loss" and score.science_points == 6 and score.funds_millions == 0, "loss plus earned bonus")
	var partial := {"mission_number":1, "objectives":[{"done":true},{"done":false}], "total_cost_m":12.0}
	score = manager.compute_score(partial)
	check(score.outcome == "Partial Success" and score.science_points == 9 and is_equal_approx(score.funds_millions, 8.0), "partial payout")
	var success := {"mission_number":1, "objectives":[{"done":true}], "total_cost_m":12.0, "mass_margin_pct":0.0}
	score = manager.compute_score(success)
	check(score.stars == 2 and score.score == 71.0 and score.science_points == 13, "star and SP rounding")
	success.is_replay = true
	check(manager.compute_score(success).science_points == 3, "replay SP fixed")
	check(manager.start_mission(1), "start mission")
	success.erase("is_replay")
	var receipt: Dictionary = manager.finalize_mission(success)
	var funds: float = manager.funds_millions
	var sp: int = manager.science_points
	check(receipt.outcome == "Success" and manager.is_mission_unlocked(2) and manager.unlocked_tier == 1, "first success progression")
	manager.finalize_mission(success)
	check(manager.funds_millions == funds and manager.science_points == sp, "duplicate settlement")
	check(manager.save_campaign() == OK, "save settlement")
	manager.funds_millions = 0
	check(manager.load_campaign() == OK and manager.funds_millions == funds and manager.is_mission_unlocked(2), "save round trip")
	check(manager.start_mission(1), "start replay")
	receipt = manager.finalize_mission(success)
	check(receipt.science_points == 3 and receipt.funds_millions == 16.0, "replay funds and SP")
	manager.completed_missions.append(2)
	check(manager.start_mission(3), "mission 3 unlocked")
	var m3 := {"mission_number":3, "objectives":[{"done":true}]}
	manager.finalize_mission(m3)
	check("L11" in manager.owned_tech_nodes and "launcher_falcon_9" in manager.unlocked_part_ids and manager.unlocked_tier == 2, "mission 3 grants")
	var old_funds: float = manager.funds_millions
	var f := FileAccess.open(manager.save_path, FileAccess.WRITE)
	f.store_string("bad save")
	f.close()
	check(manager.load_campaign() != OK and manager.funds_millions == old_funds, "corrupt save rejected without applying")
	var original: String = manager.save_path
	manager.save_path = "user://missing-directory/test.json"
	check(manager.save_campaign() != OK, "save failure reported")
	manager.save_path = original
	DirAccess.remove_absolute(ProjectSettings.globalize_path(original))
	print("Campaign failures: ", failures)
	quit(1 if failures else 0)
