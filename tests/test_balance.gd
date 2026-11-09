extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func run_tests() -> void:
	var manager := root.get_node("GameManager")
	var data := root.get_node("GlobalData")
	for p in data.components: manager.unlocked_part_ids.append(p.id)
	var builds := {
		1:["com_endurosat_uhf","pwr_gomspace_p31u","av_gomspace_a3200","pwr_gomspace_bp4","prop_vacco_mips"],
		2:["inst_nanocam_c1u","com_syrlinks_ewc27","adcs_rw003","pwr_mma_ehawk_s","pwr_gomspace_bp4","av_gomspace_a3200"],
		3:["inst_hyperscout2","com_syrlinks_ewc30","pwr_spectrolab_m","pwr_abs_slc_m","av_gomspace_a3200"],
		4:["inst_kuka_transponder_suite","prop_aerojet_r4d15","av_bae_rad750","pwr_airbus_l","pwr_eaglepicher_l"],
		5:["com_gd_sdst","inst_lroc_wac","av_bae_rad750","prop_mr103g","pwr_mma_ehawk_s","pwr_mma_ehawk_s","pwr_mma_ehawk_s","pwr_gomspace_bp4"],
		7:["prop_lpsc_throttleable","inst_kara_landing_radar","land_hex_gear","inst_chaste_probe","av_bae_rad750","pwr_spectrolab_m","pwr_abs_slc_m"]}
	for number in builds:
		manager.unlocked_part_ids.clear()
		var tier: int = {1:0,2:1,3:1,4:2,5:3,7:4}[number]
		for p in data.components:
			if p.tier <= tier: manager.unlocked_part_ids.append(p.id)
		manager.current_mission = data.get_mission(number)
		var workshop = load("res://scenes/Workshop.tscn").instantiate()
		root.add_child(workshop)
		for id in builds[number]:
			if not workshop.add_part(id): failures += 1
		if number == 1: workshop.set_propellant_mass(0.5)
		else: workshop.fill_to_required_delta_v()
		var limits: Dictionary = workshop._stats_helper.propellant_limits(workshop._build_data(),workshop.mission)
		if workshop.propellant_mass_kg > limits.maximum_kg: failures += 1
		if number == 1:
			if workshop._slider.max_value > 2.0 or limits.limiting_factor != "space inside the bus": failures += 1
			# Any fuel within the allowance must pass mass, volume and budget checks.
			workshop.set_propellant_mass(workshop._slider.max_value)
			for row in workshop.review:
				if row.status == "FAIL": failures += 1
			workshop.set_propellant_mass(0.5)
		var s: Dictionary = workshop.stats
		print("Mission %d: fuel %.3f kg, mass %.1f / %.1f kg, volume %.1f / %.1f L, cost %.2f / %.2f M" % [number,workshop.propellant_mass_kg,s.wet_mass_kg,s.launcher_capacity_kg,s.internal_volume_liters,s.volume_capacity_liters,s.cost_millions,s.budget_millions])
		for row in workshop.review:
			if row.status == "FAIL":
				failures += 1
				print("FAIL: ",row.message)
		workshop.queue_free()
		await process_frame
	print("Balance failures: ",failures)
	quit(1 if failures else 0)
