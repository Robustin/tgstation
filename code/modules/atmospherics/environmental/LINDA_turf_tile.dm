/turf
	//used for temperature calculations
	var/thermal_conductivity = 0.05
	var/heat_capacity = 1
	var/temperature_archived

	//list of open turfs adjacent to us
	var/list/atmos_adjacent_turfs
	//bitfield of dirs in which we are superconducitng
	var/atmos_supeconductivity = NONE

	//used to determine whether we should archive
	var/archived_cycle = 0
	var/current_cycle = 0

	//used for mapping and for breathing while in walls (because that's a thing that needs to be accounted for...)
	//string parsed by /datum/gas/proc/copy_from_turf
	var/initial_gas_mix = "o2=22;n2=82;TEMP=293.15"
	//approximation of MOLES_O2STANDARD and MOLES_N2STANDARD pending byond allowing constant expressions to be embedded in constant strings
	// If someone will place 0 of some gas there, SHIT WILL BREAK. Do not do that.
	var/last_react = 0

/turf/open
	//used for spacewind
	var/pressure_difference = 0
	var/pressure_direction = 0

	var/excited = FALSE
	var/datum/gas_mixture/turf/air

	var/obj/effect/hotspot/active_hotspot
	var/planetary_atmos = FALSE //air will revert to initial_gas_mix over time

	var/list/atmos_overlay_types //gas IDs of current active gas overlays
	var/static/aa1
	var/static/aa2
	var/static/aa3
	var/static/aa4
/turf/open/Initialize()
	if(!blocks_air)
		air = new
		air.copy_from_turf(src)
	. = ..()

/turf/open/Destroy()
	if(active_hotspot)
		qdel(active_hotspot)
		active_hotspot = null
	// Adds the adjacent turfs to the current atmos processing
	for(var/T in atmos_adjacent_turfs)
		SSair.add_to_active(T)
	return ..()

/////////////////GAS MIXTURE PROCS///////////////////

/turf/open/assume_air(datum/gas_mixture/giver) //use this for machines to adjust air
	if(!giver)
		return FALSE
	air.merge(giver)
	update_visuals()
	return TRUE

/turf/open/remove_air(amount)
	var/datum/gas_mixture/ours = return_air()
	var/datum/gas_mixture/removed = ours.remove(amount)
	update_visuals()
	return removed

/turf/open/proc/copy_air_with_tile(turf/open/T)
	if(istype(T))
		air.copy_from(T.air)

/turf/open/proc/copy_air(datum/gas_mixture/copy)
	if(copy)
		air.copy_from(copy)

/turf/return_air()
	var/datum/gas_mixture/GM = new
	GM.copy_from_turf(src)
	return GM

/turf/open/return_air()
	return air

/turf/temperature_expose()
	if(temperature > heat_capacity)
		to_be_destroyed = TRUE

/turf/proc/archive()
	temperature_archived = temperature

/turf/open/archive()
	air.archive()
	archived_cycle = SSair.times_fired
	temperature_archived = temperature

/////////////////////////GAS OVERLAYS//////////////////////////////

/turf/open/proc/update_visuals()
	var/list/new_overlay_types = tile_graphic()
	var/list/atmos_overlay_types = src.atmos_overlay_types // Cache for free performance

	#if DM_VERSION >= 513
	#warning 512 is stable now for sure, remove the old code
	#endif

	#if DM_VERSION >= 512
	if (atmos_overlay_types)
		for(var/overlay in atmos_overlay_types-new_overlay_types) //doesn't remove overlays that would only be added
			vars["vis_contents"] -= overlay

	if (new_overlay_types.len)
		if (atmos_overlay_types)
			vars["vis_contents"] += new_overlay_types - atmos_overlay_types //don't add overlays that already exist
		else
			vars["vis_contents"] += new_overlay_types
	#else
	if (atmos_overlay_types)
		for(var/overlay in atmos_overlay_types-new_overlay_types) //doesn't remove overlays that would only be added
			cut_overlay(overlay)

	if (new_overlay_types.len)
		if (atmos_overlay_types)
			add_overlay(new_overlay_types - atmos_overlay_types) //don't add overlays that already exist
		else
			add_overlay(new_overlay_types)
	#endif

	UNSETEMPTY(new_overlay_types)
	src.atmos_overlay_types = new_overlay_types


/turf/open/proc/tile_graphic()
	. = new /list
	if(air)
		var/list/gases = air.gases
		for(var/id in gases)
			var/gas = gases[id]
			var/gas_meta = gas[GAS_META]
			var/gas_overlay = gas_meta[META_GAS_OVERLAY]
			if(gas_overlay && gas[MOLES] > gas_meta[META_GAS_MOLES_VISIBLE])
				. += gas_overlay


/proc/perfor_test

/////////////////////////////SIMULATION///////////////////////////////////

#define DONEZO \
	if(!(our_air.temperature > MINIMUM_TEMPERATURE_FOR_SUPERCONDUCTION && consider_superconductivity(starting = TRUE))\
	  && still_active){\
	  	SSair.remove_from_active(src);\
		our_air.garbage_collect();\
	}

/turf/proc/process_cell(fire_count)
	SSair.remove_from_active(src)

/turf/open/process_cell(fire_count)
	if(archived_cycle < fire_count) //archive self if not already done
		archive()

	current_cycle = fire_count

	//cache for sanic speed
	var/list/adjacent_turfs = atmos_adjacent_turfs
	var/adjacent_turfs_length = LAZYLEN(adjacent_turfs)

	var/planet_atmos = planetary_atmos
	if (planet_atmos)
		adjacent_turfs_length++

	var/datum/gas_mixture/our_air = air

	for(var/t in adjacent_turfs)
		var/turf/open/enemy_tile = t

		if(fire_count <= enemy_tile.current_cycle)
			continue
		enemy_tile.archive()
		var/difference = air.share(enemy_tile.air, adjacent_turfs_length)
		if(abs(difference) > MINIMUM_AIR_RATIO_TO_MOVE)
			aa1++
			if(difference > 0)
				consider_pressure_difference(enemy_tile, difference)
			else
				enemy_tile.consider_pressure_difference(src, -difference)
		if(air.last_share > MINIMUM_AIR_RATIO_TO_SUSPEND)
			aa2++
			last_react = 1
			if(!enemy_tile.excited)
				SSair.add_to_active(enemy_tile)
	if (planet_atmos) //share our air with the "atmosphere" "above" the turf
		var/datum/gas_mixture/G = new
		G.copy_from_turf(src)
		G.archive()
		var/difference = our_air.share(G, adjacent_turfs_length)
		if(abs(difference) > MINIMUM_AIR_RATIO_TO_MOVE)
			last_react = 1
	if(last_react)
		last_react = our_air.react(src)
		update_visuals()
	else
		SSair.remove_from_active(src)
		our_air.garbage_collect()

//////////////////////////SPACEWIND/////////////////////////////

/turf/open/proc/consider_pressure_difference(turf/T, difference)
	SSair.high_pressure_delta |= src
	if(difference > pressure_difference)
		pressure_direction = get_dir(src, T)
		pressure_difference = difference

/turf/open/proc/high_pressure_movements()
	var/atom/movable/M
	for(var/thing in src)
		M = thing
		if (!M.anchored && !M.pulledby && M.last_high_pressure_movement_air_cycle < SSair.times_fired)
			M.experience_pressure_difference(pressure_difference, pressure_direction)

/atom/movable/var/pressure_resistance = 10
/atom/movable/var/last_high_pressure_movement_air_cycle = 0

/atom/movable/proc/experience_pressure_difference(pressure_difference, direction, pressure_resistance_prob_delta = 0)
	var/const/PROBABILITY_OFFSET = 25
	var/const/PROBABILITY_BASE_PRECENT = 75
	set waitfor = 0
	var/move_prob = 100
	if (pressure_resistance > 0)
		move_prob = (pressure_difference/pressure_resistance*PROBABILITY_BASE_PRECENT)-PROBABILITY_OFFSET
	move_prob += pressure_resistance_prob_delta
	if (move_prob > PROBABILITY_OFFSET && prob(move_prob))
		step(src, direction)
		last_high_pressure_movement_air_cycle = SSair.times_fired

////////////////////////SUPERCONDUCTIVITY/////////////////////////////
/turf/proc/conductivity_directions()
	if(archived_cycle < SSair.times_fired)
		archive()
	return NORTH|SOUTH|EAST|WEST

/turf/open/conductivity_directions()
	if(blocks_air)
		return ..()
	for(var/direction in GLOB.cardinals)
		var/turf/T = get_step(src, direction)
		if(!(T in atmos_adjacent_turfs) && !(atmos_supeconductivity & direction))
			. |= direction

/turf/proc/neighbor_conduct_with_src(turf/open/other)
	if(!other.blocks_air) //Open but neighbor is solid
		other.temperature_share_open_to_solid(src)
	else //Both tiles are solid
		other.share_temperature_mutual_solid(src, thermal_conductivity)
	temperature_expose(null, temperature, null)

/turf/open/neighbor_conduct_with_src(turf/other)
	if(!other.blocks_air) //Both tiles are open
		var/turf/open/T = other
		T.air.temperature_share(air, WINDOW_HEAT_TRANSFER_COEFFICIENT)
	else //Solid but neighbor is open
		temperature_share_open_to_solid(other)
	SSair.add_to_active(src)

/turf/proc/super_conduct()
	var/conductivity_directions = conductivity_directions()

	if(conductivity_directions)
		//Conduct with tiles around me
		for(var/direction in GLOB.cardinals)
			if(conductivity_directions & direction)
				var/turf/neighbor = get_step(src,direction)

				if(!neighbor.thermal_conductivity)
					continue

				if(neighbor.archived_cycle < SSair.times_fired)
					neighbor.archive()

				neighbor.neighbor_conduct_with_src(src)

				neighbor.consider_superconductivity()

	radiate_to_spess()

	finish_superconduction()

/turf/proc/finish_superconduction(temp = temperature)
	//Make sure still hot enough to continue conducting heat
	if(temp < MINIMUM_TEMPERATURE_FOR_SUPERCONDUCTION)
		SSair.active_super_conductivity -= src
		return FALSE

/turf/open/finish_superconduction()
	//Conduct with air on my tile if I have it
	if(!blocks_air)
		temperature = air.temperature_share(null, thermal_conductivity, temperature, heat_capacity)
	..((blocks_air ? temperature : air.temperature))

/turf/proc/consider_superconductivity()
	if(!thermal_conductivity)
		return FALSE

	SSair.active_super_conductivity |= src
	return TRUE

/turf/open/consider_superconductivity(starting)
	if(air.temperature < MINIMUM_TEMPERATURE_FOR_SUPERCONDUCTION)
		return FALSE
	if(air.heat_capacity() < M_CELL_WITH_RATIO) // Was: MOLES_CELLSTANDARD*0.1*0.05 Since there are no variables here we can make this a constant.
		return FALSE
	return ..()

/turf/closed/consider_superconductivity(starting)
	if(temperature < MINIMUM_TEMPERATURE_FOR_SUPERCONDUCTION)
		return FALSE
	return ..()

/turf/proc/radiate_to_spess() //Radiate excess tile heat to space
	if(temperature > T0C) //Considering 0 degC as te break even point for radiation in and out
		var/delta_temperature = (temperature_archived - TCMB) //hardcoded space temperature
		if((heat_capacity > 0) && (abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER))

			var/heat = thermal_conductivity*delta_temperature* \
				(heat_capacity*HEAT_CAPACITY_VACUUM/(heat_capacity+HEAT_CAPACITY_VACUUM))
			temperature -= heat/heat_capacity

/turf/open/proc/temperature_share_open_to_solid(turf/sharer)
	sharer.temperature = air.temperature_share(null, sharer.thermal_conductivity, sharer.temperature, sharer.heat_capacity)

/turf/proc/share_temperature_mutual_solid(turf/sharer, conduction_coefficient) //to be understood
	var/delta_temperature = (temperature_archived - sharer.temperature_archived)
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER && heat_capacity && sharer.heat_capacity)

		var/heat = conduction_coefficient*delta_temperature* \
			(heat_capacity*sharer.heat_capacity/(heat_capacity+sharer.heat_capacity))

		temperature -= heat/heat_capacity
		sharer.temperature += heat/sharer.heat_capacity