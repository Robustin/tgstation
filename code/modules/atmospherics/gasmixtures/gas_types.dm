GLOBAL_LIST_INIT(hardcoded_gases, list(/datum/gas/oxygen, /datum/gas/nitrogen, /datum/gas/carbon_dioxide, /datum/gas/plasma)) //the main four gases, which were at one time hardcoded

/proc/meta_gas_list()
	. = subtypesof(/datum/gas)
	for(var/gas_path in .)
		var/list/gas_info = new(6)
		var/datum/gas/gas = gas_path

		gas_info[META_GAS_SPECIFIC_HEAT] = initial(gas.specific_heat)
		gas_info[META_GAS_NAME] = initial(gas.name)
		gas_info[META_GAS_MOLES_VISIBLE] = initial(gas.moles_visible)
		if(initial(gas.moles_visible) != null)
			gas_info[META_GAS_OVERLAY] = new /obj/effect/overlay/gas(initial(gas.gas_overlay))
		gas_info[META_GAS_DANGER] = initial(gas.dangerous)
		gas_info[META_GAS_ID] = initial(gas.id)
		.[gas_path] = gas_info

/proc/gas_id2path(id)
	var/list/meta_gas = GLOB.meta_gas_info
	if(id in meta_gas)
		return id
	for(var/path in meta_gas)
		if(meta_gas[path][META_GAS_ID] == id)
			return path
	return ""

/proc/gas_flag2path(id)
	var/list/meta_gas = GLOB.meta_gas_info
	for(var/path in meta_gas)
		if(meta_gas[path][META_GAS_ID] = (log(id,2)+1)
			return GLOB.meta_gas_info[path][(log(id,2)+1)]


/*||||||||||||||/----------\||||||||||||||*\
||||||||||||||||[GAS DATUMS]||||||||||||||||
||||||||||||||||\__________/||||||||||||||||
||||These should never be instantiated. ||||
||||They exist only to make it easier   ||||
||||to add a new gas. They are accessed ||||
||||only by meta_gas_list().            ||||
\*||||||||||||||||||||||||||||||||||||||||*/

/datum/gas
	var/id = 0
	var/specific_heat = 0
	var/name = ""
	var/gas_overlay = "" //icon_state in icons/effects/tile_effects.dmi
	var/moles_visible = null
	var/dangerous = FALSE //currently used by canisters
	var/flag = 0 //bitflags for faster comparisons, ordered to provide thresholds for reactions and overlays

/datum/gas/oxygen
	id = 1
	specific_heat = 20
	name = "Oxygen"
	flag = 1

/datum/gas/nitrogen
	id = 2
	specific_heat = 20
	name = "Nitrogen"
	flag = 2

/datum/gas/carbon_dioxide //what the fuck is this?
	id = 4
	specific_heat = 30
	name = "Carbon Dioxide"
	flag = 4

/datum/gas/stimulum
	id = 8
	specific_heat = 5
	name = "Stimulum"
	flag = 8

/datum/gas/bz
	id = 16
	specific_heat = 20
	name = "BZ"
	dangerous = TRUE
	flag = 16

/datum/gas/pluoxium
	id = 32
	specific_heat = 80
	name = "Pluoxium"
	flag = 32

/datum/gas/nitryl
	id = 64
	specific_heat = 20
	name = "Nitryl"
	gas_overlay = "nitryl"
	moles_visible = MOLES_GAS_VISIBLE
	dangerous = TRUE
	flag = 64

/datum/gas/nitrous_oxide
	id = 128
	specific_heat = 40
	name = "Nitrous Oxide"
	gas_overlay = "nitrous_oxide"
	moles_visible = 1
	dangerous = TRUE
	flag = 128

/datum/gas/tritium
	id = 256
	specific_heat = 10
	name = "Tritium"
	gas_overlay = "tritium"
	moles_visible = MOLES_GAS_VISIBLE
	dangerous = TRUE
	flag = 256

/datum/gas/water_vapor
	id = 512
	specific_heat = 40
	name = "Water Vapor"
	gas_overlay = "water_vapor"
	moles_visible = MOLES_GAS_VISIBLE
	flag = 512

/datum/gas/plasma
	id = 1024
	specific_heat = 200
	name = "Plasma"
	gas_overlay = "plasma"
	moles_visible = MOLES_GAS_VISIBLE
	dangerous = TRUE
	flag = 1024

/datum/gas/hypernoblium
	id = 2048
	specific_heat = 2000
	name = "Hyper-noblium"
	gas_overlay = "freon"
	moles_visible = MOLES_GAS_VISIBLE
	dangerous = TRUE
	flag = 2048













/obj/effect/overlay/gas
	icon = 'icons/effects/tile_effects.dmi'
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = FLY_LAYER
	appearance_flags = TILE_BOUND

/obj/effect/overlay/gas/New(state)
	. = ..()
	icon_state = state
