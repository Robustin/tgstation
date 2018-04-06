 /*
What are the archived variables for?
	Calculations are done using the archived variables with the results merged into the regular variables.
	This prevents race conditions that arise based on the order of tile processing.
*/
#define MINIMUM_HEAT_CAPACITY	0.0003
#define QUANTIZE(variable)		(round(variable,0.0001))/*I feel the need to document what happens here. Basically this is used to catch most rounding errors, however it's previous value made it so that
															once gases got hot enough, most procedures wouldnt occur due to the fact that the mole counts would get rounded away. Thus, we lowered it a few orders of magnititude */
GLOBAL_LIST_INIT(meta_gas_info, meta_gas_list()) //see ATMOSPHERICS/gas_types.dm
GLOBAL_LIST_INIT(gaslist_cache, init_gaslist_cache())
GLOBAL_LIST_INIT(nonreactive_gases, typecacheof(list(/datum/gas/oxygen, /datum/gas/nitrogen, /datum/gas/carbon_dioxide))) // These gasses cannot react amongst themselves

/proc/init_gaslist_cache()
	. = list()
	for(var/id in GLOB.meta_gas_info)
		var/list/cached_gas = new(3)

		.[id] = cached_gas

		cached_gas[MOLES] = 0
		cached_gas[ARCHIVE] = 0
		cached_gas[GAS_META] = GLOB.meta_gas_info[id]

/datum/gas_mixture
	var/list/gases
	var/temperature = 0 //kelvins
	var/tmp/temperature_archived = 0
	var/volume = CELL_VOLUME //liters
	var/last_share = 0
	var/gascomp = NO_GAS
	var/list/reaction_results
	var/BULLSHIT = ""

/datum/gas_mixture/New(volume)
	gases = new
	if (!isnull(volume))
		src.volume = volume
	reaction_results = new

//listmos procs
//use the macros in performance intensive areas. for their definitions, refer to code/__DEFINES/atmospherics.dm

	//assert_gas(gas_id) - used to guarantee that the gas list for this id exists in gas_mixture.gases.
	//Must be used before adding to a gas. May be used before reading from a gas.
/datum/gas_mixture/proc/assert_gas(gas_id)
	ASSERT_GAS(gas_id, src)

	//assert_gases(args) - shorthand for calling ASSERT_GAS() once for each gas type.
/datum/gas_mixture/proc/assert_gases()
	for(var/id in args)
		ASSERT_GAS(id, src)

	//add_gas(gas_id) - similar to assert_gas(), but does not check for an existing
		//gas list for this id. This can clobber existing gases.
	//Used instead of assert_gas() when you know the gas does not exist. Faster than assert_gas().
/datum/gas_mixture/proc/add_gas(gas_id)
	ADD_GAS(gas_id, gases)

	//add_gases(args) - shorthand for calling add_gas() once for each gas_type.
/datum/gas_mixture/proc/add_gases()
	var/cached_gases = gases
	for(var/id in args)
		ADD_GAS(id, cached_gases)

	//garbage_collect() - removes any gas list which is empty.
	//If called with a list as an argument, only removes gas lists with IDs from that list.
	//Must be used after subtracting from a gas. Must be used after assert_gas()
		//if assert_gas() was called only to read from the gas.
	//By removing empty gases, processing speed is increased.
/datum/gas_mixture/proc/garbage_collect(list/tocheck)
	var/list/cached_gases = tocheck || gases
	for(var/id in cached_gases)
		var/current_gas = cached_gases[id]
		if(QUANTIZE(current_gas[MOLES]) <= 0 && QUANTIZE(current_gas[ARCHIVE]) <= 0)
			gascomp -= current_gas[GAS_META][META_GAS_FLAG]
			cached_gases -= id

	//PV = nRT

/datum/gas_mixture/proc/heat_capacity(data = MOLES) //joules per kelvin
	var/list/cached_gases = gases
	. = 0
	for(var/id in cached_gases)
		var/gas_data = cached_gases[id]
		. += gas_data[data] * gas_data[GAS_META][META_GAS_SPECIFIC_HEAT]

/datum/gas_mixture/turf/heat_capacity()
	. = ..()
	if(!.)
		. += HEAT_CAPACITY_VACUUM //we want vacuums in turfs to have the same heat capacity as space

//prefer this in performance critical areas
#define TOTAL_MOLES(cached_gases, out_var)\
	out_var = 0;\
	for(var/total_moles_id in cached_gases){\
		out_var += cached_gases[total_moles_id][MOLES];\
	}

/datum/gas_mixture/proc/total_moles()
	var/cached_gases = gases
	TOTAL_MOLES(cached_gases, .)

/datum/gas_mixture/proc/return_pressure() //kilopascals
	if(volume > 0) // to prevent division by zero
		var/cached_gases = gases
		TOTAL_MOLES(cached_gases, .)
		. *= R_IDEAL_GAS_EQUATION * temperature / volume
		return
	return 0

/datum/gas_mixture/proc/return_temperature() //kelvins
	return temperature

/datum/gas_mixture/proc/return_volume() //liters
	return max(0, volume)

/datum/gas_mixture/proc/thermal_energy() //joules
	return THERMAL_ENERGY(src) //see code/__DEFINES/atmospherics.dm; use the define in performance critical areas

/datum/gas_mixture/proc/archive()
	//Update archived versions of variables
	//Returns: 1 in all cases

/datum/gas_mixture/proc/merge(datum/gas_mixture/giver)
	//Merges all air from giver into self. Deletes giver.
	//Returns: 1 if we are mutable, 0 otherwise

/datum/gas_mixture/proc/remove(amount)
	//Proportionally removes amount of gas from the gas_mixture
	//Returns: gas_mixture with the gases removed

/datum/gas_mixture/proc/remove_ratio(ratio)
	//Proportionally removes amount of gas from the gas_mixture
	//Returns: gas_mixture with the gases removed

/datum/gas_mixture/proc/copy()
	//Creates new, identical gas mixture
	//Returns: duplicate gas mixture

/datum/gas_mixture/proc/copy_from(datum/gas_mixture/sample)
	//Copies variables from sample
	//Returns: 1 if we are mutable, 0 otherwise

/datum/gas_mixture/proc/ratio_copy_from(datum/gas_mixture/sample, ratio = 1)
	//Works just like copy_from but will multiply the moles in the copy by a ratio

/datum/gas_mixture/proc/copy_from_turf(turf/model)
	//Copies all gas info from the turf into the gas list along with temperature
	//Returns: 1 if we are mutable, 0 otherwise

/datum/gas_mixture/proc/parse_gas_string(gas_string)
	//Copies variables from a particularly formatted string.
	//Returns: 1 if we are mutable, 0 otherwise

/datum/gas_mixture/proc/share(datum/gas_mixture/sharer)
	//Performs air sharing calculations between two gas_mixtures assuming only 1 boundary length
	//Returns: amount of gas exchanged (+ if sharer received)

/datum/gas_mixture/proc/after_share(datum/gas_mixture/sharer)
	//called on share's sharer to let it know it just got some gases

/datum/gas_mixture/proc/temperature_share(datum/gas_mixture/sharer, conduction_coefficient)
	//Performs temperature sharing calculations (via conduction) between two gas_mixtures assuming only 1 boundary length
	//Returns: new temperature of the sharer

/datum/gas_mixture/proc/compare(datum/gas_mixture/sample)
	//Compares sample to self to see if within acceptable ranges that group processing may be enabled
	//Returns: a string indicating what check failed, or "" if check passes

/datum/gas_mixture/proc/react(turf/open/dump_location)
	//Performs various reactions such as combustion or fusion (LOL)
	//Returns: 1 if any reaction took place; 0 otherwise

/datum/gas_mixture/archive()
	var/list/cached_gases = gases

	temperature_archived = temperature
	for(var/id in cached_gases)
		cached_gases[id][ARCHIVE] = cached_gases[id][MOLES]

	return 1

/datum/gas_mixture/merge(datum/gas_mixture/giver)
	if(!giver)
		return 0

	//heat transfer
	if(abs(temperature - giver.temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = heat_capacity()
		var/giver_heat_capacity = giver.heat_capacity()
		var/combined_heat_capacity = giver_heat_capacity + self_heat_capacity
		if(combined_heat_capacity)
			temperature = (giver.temperature * giver_heat_capacity + temperature * self_heat_capacity) / combined_heat_capacity

	var/list/cached_gases = gases //accessing datum vars is slower than proc vars
	var/list/giver_gases = giver.gases
	//gas transfer
	for(var/giver_id in giver_gases)
		ASSERT_GAS(giver_id, src)
		cached_gases[giver_id][MOLES] += giver_gases[giver_id][MOLES]
	return 1

/datum/gas_mixture/remove(amount)
	var/sum
	var/list/cached_gases = gases
	TOTAL_MOLES(cached_gases, sum)
	amount = min(amount, sum) //Can not take more air than tile has!
	if(amount <= 0)
		return null
	var/datum/gas_mixture/removed = new type
	var/list/removed_gases = removed.gases //accessing datum vars is slower than proc vars

	removed.temperature = temperature
	for(var/id in cached_gases)
		ADD_GAS(id, removed.gases)
		removed_gases[id][MOLES] = QUANTIZE((cached_gases[id][MOLES] / sum) * amount)
		cached_gases[id][MOLES] -= removed_gases[id][MOLES]
	garbage_collect()

	return removed

/datum/gas_mixture/remove_ratio(ratio)
	if(ratio <= 0)
		return null
	ratio = min(ratio, 1)

	var/list/cached_gases = gases
	var/datum/gas_mixture/removed = new type
	var/list/removed_gases = removed.gases //accessing datum vars is slower than proc vars

	removed.temperature = temperature
	for(var/id in cached_gases)
		ADD_GAS(id, removed.gases)
		removed_gases[id][MOLES] = QUANTIZE(cached_gases[id][MOLES] * ratio)
		cached_gases[id][MOLES] -= removed_gases[id][MOLES]

	garbage_collect()

	return removed

/datum/gas_mixture/copy()
	var/list/cached_gases = gases
	var/datum/gas_mixture/copy = new type
	var/list/copy_gases = copy.gases

	copy.temperature = temperature
	for(var/id in cached_gases)
		ADD_GAS(id, copy.gases)
		copy_gases[id][MOLES] = cached_gases[id][MOLES]
		copy.gascomp = gascomp
	return copy


/datum/gas_mixture/copy_from(datum/gas_mixture/sample)
	var/list/cached_gases = gases //accessing datum vars is slower than proc vars
	var/list/sample_gases = sample.gases

	temperature = sample.temperature
	for(var/id in sample_gases)
		ASSERT_GAS(id,src)
		cached_gases[id][MOLES] = sample_gases[id][MOLES]
	//remove all gases not in the sample
	cached_gases &= sample_gases
	gascomp = sample.gascomp

	return 1

/datum/gas_mixture/ratio_copy_from(datum/gas_mixture/sample, ratio = 1)
	var/list/cached_gases = gases //accessing datum vars is slower than proc vars
	var/list/sample_gases = sample.gases
	temperature = sample.temperature
	for(var/id in sample_gases)
		ASSERT_GAS(id,src)
		cached_gases[id][MOLES] = ratio * sample_gases[id][MOLES]

/datum/gas_mixture/copy_from_turf(turf/model)
	parse_gas_string(model.initial_gas_mix)

	//acounts for changes in temperature
	var/turf/model_parent = model.parent_type
	if(model.temperature != initial(model.temperature) || model.temperature != initial(model_parent.temperature))
		temperature = model.temperature

	return 1

/datum/gas_mixture/parse_gas_string(gas_string)
	var/list/gases = src.gases
	var/list/gas = params2list(gas_string)
	if(gas["TEMP"])
		temperature = text2num(gas["TEMP"])
		gas -= "TEMP"
	gases.Cut()
	for(var/id in gas)
		var/path = id
		if(!ispath(path))
			path = gas_id2path(path) //a lot of these strings can't have embedded expressions (especially for mappers), so support for IDs needs to stick around
		ASSERT_GAS(path, src)
		gases[path][MOLES] = text2num(gas[id])
	return 1

/proc/gastest(var/num)
	to_chat(world, "The gas is [GLOB.gaslist_cache[log(2, num)+1]].")

/proc/mathtest(var/num)
	var/output = log(2, num)
	to_chat(world, "The number is [output].")

/datum/gas_mixture/share(datum/gas_mixture/sharer, atmos_adjacent_turfs = 4)
	var/list/cached_gases = gases
	var/list/sharer_gases = sharer.gases
	var/our_total = 0
	var/sharer_total = 0
	var/old_temp = temperature_archived
	var/old_sharer_temp = sharer.temperature_archived
	var/abs_temperature_delta = abs(old_temp - old_sharer_temp)
	var/moved_moles = 0
	var/abs_moved_moles = 0
	if(abs_temperature_delta > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/old_self_heat_capacity = heat_capacity()
		var/old_sharer_heat_capacity = sharer.heat_capacity()
		var/new_self_heat_capacity = old_self_heat_capacity
		var/new_sharer_heat_capacity = old_sharer_heat_capacity

		var/us = gascomp
		var/them = sharer.gascomp
		var/g = us ^ them
		if(g)
			var/i = 2048
			while(i)
				if(i <= g)
					var/gas = gas_flag2path(i)
					if(us > them)
						ADD_GAS(gas, sharer_gases)
						sharer.gascomp |= i
						us -= i
					else
						ADD_GAS(gas, cached_gases)
						gascomp |= i
						them -= i
					g -= i
				i >>= 1
		for(var/id in cached_gases) // transfer gases
			var/gas = cached_gases[id]
			var/sharergas = sharer_gases[id]
			ASSERT_GAS(id, sharer)
			var/delta = QUANTIZE(gas[ARCHIVE] - sharergas[ARCHIVE])/(atmos_adjacent_turfs+1) //the amount of gas that gets moved between the mixtures
			if(delta)
				var/gas_heat_capacity = delta * gas[GAS_META][META_GAS_SPECIFIC_HEAT]
				if(delta > 0)
					new_self_heat_capacity -= gas_heat_capacity
					new_sharer_heat_capacity += gas_heat_capacity
				else
					new_self_heat_capacity += gas_heat_capacity
					new_sharer_heat_capacity -= gas_heat_capacity
				gas[MOLES]			-= delta
				sharergas[MOLES]	+= delta
				moved_moles			+= delta
				abs_moved_moles		+= abs(delta)
			our_total += gas[MOLES]
			sharer_total += sharergas[MOLES]

		//transfer of thermal energy (via changed heat capacity) between self and sharer
		if(new_self_heat_capacity > MINIMUM_HEAT_CAPACITY)
			temperature = (old_self_heat_capacity*temperature)/new_self_heat_capacity

		if(new_sharer_heat_capacity > MINIMUM_HEAT_CAPACITY)
			sharer.temperature = (old_sharer_heat_capacity*sharer.temperature)/new_sharer_heat_capacity
			if(abs(new_sharer_heat_capacity/old_sharer_heat_capacity - 1) < 0.1) // <10% change in sharer heat capacity
				if(old_sharer_heat_capacity > MINIMUM_HEAT_CAPACITY && old_self_heat_capacity > MINIMUM_HEAT_CAPACITY)
					var/heat = OPEN_HEAT_TRANSFER_COEFFICIENT*(old_temp - old_sharer_temp)*(old_self_heat_capacity*old_sharer_heat_capacity/(old_self_heat_capacity+old_sharer_heat_capacity))
					temperature = max(temperature - heat/old_self_heat_capacity, TCMB)
					sharer.temperature = max(sharer.temperature + heat/old_sharer_heat_capacity, TCMB)

	else
		var/us = gascomp
		var/them = sharer.gascomp
		var/g = us ^ them
		if(g)
			var/i = 2048
			while(i)
				if(i <= g)
					var/gas = gas_flag2path(i)
					if(us > them)
						ADD_GAS(gas, sharer_gases)
						sharer.gascomp |= i
						us -= i
					else
						ADD_GAS(gas, cached_gases)
						gascomp |= i
						them -= i
					g -= i
				i >>= 1
		for(var/id in cached_gases) // transfer gases
			var/gas = cached_gases[id]
			var/sharergas = sharer_gases[id]
			ASSERT_GAS(id, sharer)
			var/delta = QUANTIZE(gas[ARCHIVE] - sharergas[ARCHIVE])/(atmos_adjacent_turfs+1) //the amount of gas that gets moved between the mixtures
			if(delta)
				gas[MOLES]			-= delta
				sharergas[MOLES]	+= delta
				moved_moles			+= delta
				abs_moved_moles		+= abs(delta)
			our_total += gas[MOLES]
			sharer_total += sharergas[MOLES]

	last_share = abs_moved_moles

	sharer.after_share(src, atmos_adjacent_turfs)
	if(abs_temperature_delta > MINIMUM_TEMPERATURE_TO_MOVE || abs_moved_moles > MINIMUM_MOLES_DELTA_TO_MOVE)
		var/delta_pressure = temperature_archived*(our_total) - sharer.temperature_archived*(sharer_total)
		return delta_pressure * R_IDEAL_GAS_EQUATION / volume

/datum/gas_mixture/after_share(datum/gas_mixture/sharer, atmos_adjacent_turfs = 4)
	return

/datum/gas_mixture/temperature_share(datum/gas_mixture/sharer, conduction_coefficient, sharer_temperature, sharer_heat_capacity)
	//transfer of thermal energy (via conduction) between self and sharer
	if(sharer)
		sharer_temperature = sharer.temperature_archived
	var/temperature_delta = temperature_archived - sharer_temperature
	if(abs(temperature_delta) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = heat_capacity(ARCHIVE)
		sharer_heat_capacity = sharer_heat_capacity || sharer.heat_capacity(ARCHIVE)

		if((sharer_heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient*temperature_delta* \
				(self_heat_capacity*sharer_heat_capacity/(self_heat_capacity+sharer_heat_capacity))

			temperature = max(temperature - heat/self_heat_capacity, TCMB)
			sharer_temperature = max(sharer_temperature + heat/sharer_heat_capacity, TCMB)
			if(sharer)
				sharer.temperature = sharer_temperature
	return sharer_temperature
	//thermal energy of the system (self and sharer) is unchanged

/datum/gas_mixture/compare(datum/gas_mixture/sample)
	var/list/sample_gases = sample.gases //accessing datum vars is slower than proc vars
	var/list/cached_gases = gases

	for(var/id in cached_gases | sample_gases) // compare gases from either mixture
		var/gas_moles = cached_gases[id]
		gas_moles = gas_moles ? gas_moles[MOLES] : 0
		var/sample_moles = sample_gases[id]
		sample_moles = sample_moles ? sample_moles[MOLES] : 0
		var/delta = abs(gas_moles - sample_moles)
		if(delta > MINIMUM_MOLES_DELTA_TO_MOVE && \
			delta > gas_moles * MINIMUM_AIR_RATIO_TO_MOVE)
			return id

	var/our_moles
	TOTAL_MOLES(cached_gases, our_moles)
	if(our_moles > MINIMUM_MOLES_DELTA_TO_MOVE)
		var/temp = temperature
		var/sample_temp = sample.temperature

		var/temperature_delta = abs(temp - sample_temp)
		if(temperature_delta > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND)
			return "temp"

	return ""

/datum/gas_mixture/react(turf/open/dump_location)
	. = NO_REACTION
	var/list/cached_gases = gases
	if(gascomp > 130)
		reaction_results = new
		var/temp = temperature
		var/ener = THERMAL_ENERGY(src)

		reaction_loop:
			for(var/r in SSair.gas_reactions)
				var/datum/gas_reaction/reaction = r

				var/list/min_reqs = reaction.min_requirements.Copy()
				if((min_reqs["TEMP"] && temp < min_reqs["TEMP"]) \
				|| (min_reqs["ENER"] && ener < min_reqs["ENER"]))
					continue
				min_reqs -= "TEMP"
				min_reqs -= "ENER"

				for(var/id in min_reqs)
					if(!cached_gases[id] || cached_gases[id][MOLES] < min_reqs[id])
						continue reaction_loop
				//at this point, all minimum requirements for the reaction are satisfied.

				/*	currently no reactions have maximum requirements, so we can leave the checks commented out for a slight performance boost
					PLEASE DO NOT REMOVE THIS CODE. the commenting is here only for a performance increase.
					enabling these checks should be as easy as possible and the fact that they are disabled should be as clear as possible

				var/list/max_reqs = reaction.max_requirements.Copy()
				if((max_reqs["TEMP"] && temp > max_reqs["TEMP"]) \
				|| (max_reqs["ENER"] && ener > max_reqs["ENER"]))
					continue
				max_reqs -= "TEMP"
				max_reqs -= "ENER"
				for(var/id in max_reqs)
					if(cached_gases[id] && cached_gases[id][MOLES] > max_reqs[id])
						continue reaction_loop
				//at this point, all requirements for the reaction are satisfied. we can now react()
				*/

				. |= reaction.react(src, dump_location)
				if (. & STOP_REACTIONS)
					break
		if(.)
			garbage_collect()
			if(temperature < TCMB) //just for safety
				temperature = TCMB

//Takes the amount of the gas you want to PP as an argument
//So I don't have to do some hacky switches/defines/magic strings
//eg:
//Tox_PP = get_partial_pressure(gas_mixture.toxins)
//O2_PP = get_partial_pressure(gas_mixture.oxygen)

/datum/gas_mixture/proc/get_breath_partial_pressure(gas_pressure)
	return (gas_pressure * R_IDEAL_GAS_EQUATION * temperature) / BREATH_VOLUME
//inverse
/datum/gas_mixture/proc/get_true_breath_pressure(partial_pressure)
	return (partial_pressure * BREATH_VOLUME) / (R_IDEAL_GAS_EQUATION * temperature)

//Mathematical proofs:
/*
get_breath_partial_pressure(gas_pp) --> gas_pp/total_moles()*breath_pp = pp
get_true_breath_pressure(pp) --> gas_pp = pp/breath_pp*total_moles()

10/20*5 = 2.5
10 = 2.5/5*20
*/