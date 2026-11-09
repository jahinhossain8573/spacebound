extends Node

var launchers: Array[Dictionary] = []
var buses: Array[Dictionary] = []
var components: Array[Dictionary] = []
var missions: Array[Dictionary] = []

var _launcher_index: Dictionary = {}
var _bus_index: Dictionary = {}
var _part_index: Dictionary = {}
var _mission_index: Dictionary = {}


func _ready() -> void:
	launchers = _load_catalog("res://data/launchers.json", "launchers")
	buses = _load_catalog("res://data/buses.json", "buses")
	components = _load_catalog("res://data/components.json", "components")
	missions = _load_catalog("res://data/missions.json", "missions")
	for item in launchers:
		_launcher_index[item.id] = item
	for item in buses:
		_bus_index[item.id] = item
	for item in components:
		_part_index[item.id] = item
	for item in missions:
		_mission_index[int(item.missionNumber)] = item


func _load_catalog(path: String, kind: String) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_error("Cannot read catalog: " + path)
		return records
	var contents := FileAccess.get_file_as_string(path)
	if FileAccess.get_open_error() != OK:
		push_error("Cannot read catalog: " + path)
		return records
	var parsed: Variant = JSON.parse_string(contents)
	if not parsed is Array:
		push_error("Invalid JSON catalog: " + path)
		return records
	var ids: Dictionary = {}
	var numbers: Dictionary = {}
	for item: Variant in parsed:
		if not item is Dictionary or not _valid_record(item, kind):
			push_error("Invalid record in catalog: " + path)
			return []
		if ids.has(item.id):
			push_error("Duplicate id in catalog: " + path)
			return []
		ids[item.id] = true
		if kind == "missions":
			var number := int(item.missionNumber)
			if numbers.has(number):
				push_error("Duplicate mission number in catalog: " + path)
				return []
			numbers[number] = true
		records.append(item)
	return records


func _valid_record(item: Dictionary, kind: String) -> bool:
	var string_fields := ["id"]
	var number_fields: Array[String] = []
	match kind:
		"launchers":
			string_fields += ["name", "heritage"]
			number_fields = ["tier", "costMillions", "baseReliability", "fairingDiameterMeters", "fairingHeightMeters", "capacityLeoKg", "capacityGtoKg", "capacityTliKg"]
		"buses":
			string_fields += ["name", "heritage"]
			number_fields = ["tier", "dryMassKg", "internalVolumeLiters", "costMillions"]
			if not item.get("dimensionsMeters") is Array or item.dimensionsMeters.size() != 3:
				return false
			for dimension: Variant in item.dimensionsMeters:
				if not _is_number(dimension) or dimension <= 0:
					return false
		"components":
			string_fields += ["name", "subsystem", "heritage"]
			number_fields = ["tier", "massKg", "volumeLiters", "powerGenWatts", "powerDrawWatts", "costMillions"]
			if not item.get("isExternal") is bool:
				return false
			for field in ["batteryWh", "thrustNewtons", "ispSeconds", "minThrottle", "dataRateKbps"]:
				if item.has(field) and (not _is_number(item[field]) or item[field] < 0):
					return false
			for field in ["throttleable", "radiationHardened", "optical", "deployable", "deepSpace"]:
				if item.has(field) and not item[field] is bool:
					return false
			if item.has("propellantType") and item.propellantType not in ["cold_gas", "hydrazine", "bipropellant"]:
				return false
			if item.has("minThrottle") and item.minThrottle > 1:
				return false
		"missions":
			string_fields += ["title", "briefing", "targetOrbit", "requiredLauncher", "requiredBus"]
			number_fields = ["missionNumber", "targetAltitudeKm", "durationDays", "requiredDeltaVMps", "budgetCapMillions", "rewardFundsMillions", "rewardSciencePoints"]
			for field in ["requiredPartIds", "requiredCapabilities"]:
				if not item.get(field) is Array:
					return false
				for value: Variant in item[field]:
					if not value is String or value.is_empty():
						return false
			if item.has("objectives"):
				if not item.objectives is Array or item.objectives.is_empty(): return false
				var objective_ids := {}
				for objective in item.objectives:
					if not objective is Dictionary: return false
					for key in ["id", "name", "trigger"]:
						if not objective.get(key) is String or objective[key].is_empty(): return false
					if objective.id in objective_ids or objective.trigger not in ["launch", "sunlit_pass", "duration"]: return false
					objective_ids[objective.id] = true
					if objective.trigger == "sunlit_pass":
						for key in ["requiredPartId", "message"]:
							if not objective.get(key) is String or objective[key].is_empty(): return false
			if item.has("unlocksTier") and (not _is_number(item.unlocksTier) or item.unlocksTier < 0 or item.unlocksTier > 4 or item.unlocksTier != floor(item.unlocksTier)):
				return false
		_:
			return false
	for field in string_fields:
		if not item.get(field) is String or item[field].is_empty():
			return false
	for field in number_fields:
		if not _is_number(item.get(field)) or item[field] < 0:
			return false
	if kind != "missions" and (item.tier < 0 or item.tier > 4 or item.tier != floor(item.tier)):
		return false
	if kind == "components" and item.isExternal and item.volumeLiters != 0:
		return false
	if kind == "missions" and (item.missionNumber < 1 or item.missionNumber != floor(item.missionNumber)):
		return false
	return true


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func get_launcher(id: String) -> Dictionary:
	return _launcher_index.get(id, {})


func get_bus(id: String) -> Dictionary:
	return _bus_index.get(id, {})


func get_part(id: String) -> Dictionary:
	return _part_index.get(id, {})


func get_mission(number: int) -> Dictionary:
	return _mission_index.get(number, {})


func parts_by_subsystem(unlocked_only: bool = true) -> Dictionary:
	var groups: Dictionary = {}
	for part in components:
		if unlocked_only and part.tier != 0 and not part.id in GameManager.unlocked_part_ids:
			continue
		if not groups.has(part.subsystem):
			groups[part.subsystem] = []
		groups[part.subsystem].append(part)
	return groups
