/datum/pipeline
	var/datum/gas_mixture/air
	var/list/datum/gas_mixture/other_airs

	var/list/obj/machinery/atmospherics/pipe/members
	var/list/obj/machinery/atmospherics/components/other_atmosmch

	var/update = TRUE
	var/reconcile = FALSE //If the pipeline contains components that must be reconciled if our gas mix is updated

/datum/pipeline/New()
	other_airs = list()
	members = list()
	other_atmosmch = list()
	SSair.networks += src

/datum/pipeline/Destroy()
	SSair.networks -= src
	if(air && air.volume)
		temporarily_store_air()
	for(var/obj/machinery/atmospherics/pipe/P in members)
		P.parent = null
	for(var/obj/machinery/atmospherics/components/C in other_atmosmch)
		C.nullifyPipenet(src)
	return ..()

/datum/pipeline/process()
	if(update)
		var/datum/gas_mixture/our_air = air
		if(reconcile)
			reconcile_air()
		else
			our_air.update_pipeair(other_airs)
		update = our_air.react()

/datum/pipeline/proc/build_pipeline(obj/machinery/atmospherics/base)
	var/volume = 0
	if(istype(base, /obj/machinery/atmospherics/pipe))
		var/obj/machinery/atmospherics/pipe/E = base
		volume = E.volume
		members += E
		if(E.air_temporary)
			air = E.air_temporary
			E.air_temporary = null
	else
		addMachineryMember(base)
	if(!air)
		air = new
	var/list/possible_expansions = list(base)
	while(possible_expansions.len>0)
		for(var/obj/machinery/atmospherics/borderline in possible_expansions)

			var/list/result = borderline.pipeline_expansion(src)

			if(result.len>0)
				for(var/obj/machinery/atmospherics/P in result)
					if(istype(P, /obj/machinery/atmospherics/pipe))
						var/obj/machinery/atmospherics/pipe/item = P
						if(!members.Find(item))

							if(item.parent)
								var/static/pipenetwarnings = 10
								if(pipenetwarnings > 0)
									warning("build_pipeline(): [item.type] added to a pipenet while still having one. (pipes leading to the same spot stacking in one turf) Nearby: ([item.x], [item.y], [item.z])")
									pipenetwarnings -= 1
									if(pipenetwarnings == 0)
										warning("build_pipeline(): further messages about pipenets will be supressed")
							members += item
							possible_expansions += item

							volume += item.volume
							item.parent = src

							if(item.air_temporary)
								air.merge(item.air_temporary)
								item.air_temporary = null
					else
						P.setPipenet(src, borderline)
						addMachineryMember(P)

			possible_expansions -= borderline

	air.volume = volume

/datum/pipeline/proc/addMachineryMember(obj/machinery/atmospherics/components/C)
	other_atmosmch |= C
	var/datum/gas_mixture/G = C.returnPipenetAir(src)
	if(!G)
		stack_trace("addMachineryMember: Null gasmix added to pipeline datum from [C] which is of type [C.type]. Nearby: ([C.x], [C.y], [C.z])")
	other_airs |= G

/datum/pipeline/proc/addMember(obj/machinery/atmospherics/A, obj/machinery/atmospherics/N)
	if(istype(A, /obj/machinery/atmospherics/pipe))
		var/obj/machinery/atmospherics/pipe/P = A
		if(P.parent)
			merge(P.parent)
		P.parent = src
		var/list/adjacent = P.pipeline_expansion()
		for(var/obj/machinery/atmospherics/pipe/I in adjacent)
			if(I.parent == src)
				continue
			var/datum/pipeline/E = I.parent
			merge(E)
		if(!members.Find(P))
			members += P
			air.volume += P.volume
	else
		A.setPipenet(src, N)
		addMachineryMember(A)

/datum/pipeline/proc/merge(datum/pipeline/E)
	if(E == src)
		return
	air.volume += E.air.volume
	members.Add(E.members)
	for(var/obj/machinery/atmospherics/pipe/S in E.members)
		S.parent = src
	air.merge(E.air)
	for(var/obj/machinery/atmospherics/components/C in E.other_atmosmch)
		C.replacePipenet(E, src)
	other_atmosmch.Add(E.other_atmosmch)
	other_airs.Add(E.other_airs)
	E.members.Cut()
	E.other_atmosmch.Cut()
	update = TRUE
	qdel(E)

/obj/machinery/atmospherics/proc/addMember(obj/machinery/atmospherics/A)
	return

/obj/machinery/atmospherics/pipe/addMember(obj/machinery/atmospherics/A)
	parent.addMember(A, src)

/obj/machinery/atmospherics/components/addMember(obj/machinery/atmospherics/A)
	var/datum/pipeline/P = returnPipenet(A)
	P.addMember(A, src)


/datum/pipeline/proc/temporarily_store_air()
	//Update individual gas_mixtures by volume ratio

	for(var/obj/machinery/atmospherics/pipe/member in members)
		member.air_temporary = new
		member.air_temporary.volume = member.volume
		member.air_temporary.copy_from(air)
		var/member_gases = member.air_temporary.gases

		for(var/id in member_gases)
			member_gases[id][MOLES] *= member.volume/air.volume

		member.air_temporary.temperature = air.temperature

/datum/pipeline/proc/temperature_interact(turf/target, share_volume, thermal_conductivity)
	var/total_heat_capacity = air.heat_capacity()
	var/partial_heat_capacity = total_heat_capacity*(share_volume/air.volume)
	var/target_temperature
	var/target_heat_capacity

	if(isopenturf(target))

		var/turf/open/modeled_location = target
		target_temperature = modeled_location.GetTemperature()
		target_heat_capacity = modeled_location.GetHeatCapacity()

		if(modeled_location.blocks_air)

			if((modeled_location.heat_capacity>0) && (partial_heat_capacity>0))
				var/delta_temperature = air.temperature - target_temperature

				var/heat = thermal_conductivity*delta_temperature* \
					(partial_heat_capacity*target_heat_capacity/(partial_heat_capacity+target_heat_capacity))

				air.temperature -= heat/total_heat_capacity
				modeled_location.TakeTemperature(heat/target_heat_capacity)

		else
			var/delta_temperature = 0
			var/sharer_heat_capacity = 0

			delta_temperature = (air.temperature - target_temperature)
			sharer_heat_capacity = target_heat_capacity

			var/self_temperature_delta = 0
			var/sharer_temperature_delta = 0

			if((sharer_heat_capacity>0) && (partial_heat_capacity>0))
				var/heat = thermal_conductivity*delta_temperature* \
					(partial_heat_capacity*sharer_heat_capacity/(partial_heat_capacity+sharer_heat_capacity))

				self_temperature_delta = -heat/total_heat_capacity
				sharer_temperature_delta = heat/sharer_heat_capacity
			else
				return 1

			air.temperature += self_temperature_delta
			modeled_location.TakeTemperature(sharer_temperature_delta)


	else
		if((target.heat_capacity>0) && (partial_heat_capacity>0))
			var/delta_temperature = air.temperature - target.temperature

			var/heat = thermal_conductivity*delta_temperature* \
				(partial_heat_capacity*target.heat_capacity/(partial_heat_capacity+target.heat_capacity))

			air.temperature -= heat/total_heat_capacity
	update = TRUE

/datum/pipeline/proc/return_air()
	. = other_airs + air
	if(null in .)
		stack_trace("[src] has one or more null gas mixtures, which may cause bugs. Null mixtures will not be considered in reconcile_air().")
		return removeNullsFromList(.)

/datum/pipeline/proc/reconcile_air()
	var/list/datum/gas_mixture/GL = list()
	var/list/datum/pipeline/PL = list()
	PL += src
	for(var/i = 1; i <= PL.len; i++) //can't do a for-each here because we may add to the list within the loop
		var/datum/pipeline/P = PL[i]
		if(!P)
			continue
		if(i == 1)
			GL += P.other_airs
		else
			GL += P.return_air()
		for(var/obj/machinery/atmospherics/components/binary/valve/V in P.other_atmosmch)
			if(V.open)
				PL |= V.parents[1]
				PL |= V.parents[2]
		for(var/obj/machinery/atmospherics/components/unary/portables_connector/C in P.other_atmosmch)
			if(C.connected_device)
				GL += C.portableConnectorReturnAir()
	reconcile = FALSE
	air.update_pipeair(GL)

/datum/gas_mixture/proc/update_pipeair(list/other_airs)
	var/total_volume = volume
	for(var/i in other_airs)
		var/datum/gas_mixture/G = i
		total_volume += G.volume
		if(G.gases.len) //Average 0.6-0.8 false results for every proc call
			merge(G)
	var/list/cached_gases = gases
	if(gascomp) //Average 0.15 false results for every proc call
		for(var/i in other_airs)	//Update individual gas_mixtures by volume ratio
			var/datum/gas_mixture/G = i
			var/ratio = G.volume/total_volume
			G.temperature = temperature
			for(var/id in cached_gases)
				ASSERT_GAS(id,G)
				G.gases[id][MOLES] = ratio * cached_gases[id][MOLES]
