extends BaseAction
class_name WeaponAction

export var source: String = "GMS"
export var licence: String = "GMS"
export var license_id: String = ""
export var license_level: int = 0

export(CONSTANTS.WEAPON_SIZE) var mount = CONSTANTS.WEAPON_SIZE.MAIN
export(CONSTANTS.WEAPON_TYPES) var weapon_type = CONSTANTS.WEAPON_TYPES.RIFLE

export var barrage: bool
export var skirmish: bool
export var no_attack: bool
export var no_mods: bool
export var no_core_bonus: bool

export(Array, Resource) var damage  # Damage resource
export(Array, Resource) var ranges  # Range resource
export(Array, Resource) var tag     # Tag resource

export var sp: int = 0
export var description: String

export var actions: Array  # Action resource
export var bonuses: Array  # Bonus resource
export var no_bonus: bool

# Resource that contains the effects of the action, use the bool to mark that the effect is active
export var is_effect: bool
export(Resource) var effects
export var is_on_attack: bool
export(Resource) var on_attack
export var is_on_hit: bool
export(Resource) var on_hit
export var is_on_crit: bool
export(Resource) var on_crit

export var deployable: Array  # Deployable resource
export var counters: Array    # Counter resource

export var integrated: Array
export var special_equipment: Array


const range_type_dict = {
	CONSTANTS.WEAPON_RANGE_TYPES.RANGE: "res://Media/icons/range/range.svg",
	CONSTANTS.WEAPON_RANGE_TYPES.LINE: "res://Media/icons/range/aoe_line.svg",
	CONSTANTS.WEAPON_RANGE_TYPES.CONE: "res://Media/icons/range/aoe_cone.svg",
	CONSTANTS.WEAPON_RANGE_TYPES.BLAST: "res://Media/icons/range/aoe_blast.svg",
	CONSTANTS.WEAPON_RANGE_TYPES.BURST: "res://Media/icons/range/aoe_burst.svg",
	CONSTANTS.WEAPON_RANGE_TYPES.THREAT: "res://Media/icons/range/threat.svg",
}

func get_display_name(mode: int = 0) -> Array:
	var text = "%s - %d" % [name, ranges[mode].range_value]
	var icon = load(range_type_dict[ranges[mode].type])
	return [text, icon]
