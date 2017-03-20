/obj/vehicle/space/speedbike
	name = "Speedbike"
	icon = 'icons/obj/bike.dmi'
	icon_state = "speedbike_blue"
	layer = LYING_MOB_LAYER
	var/overlay_state = "cover_blue"
	var/image/overlay = null

/obj/vehicle/space/speedbike/buckle_mob(mob/living/M, force = 0, check_loc = 1)
 	. = ..()
		riding_datum = new/datum/riding/space/speedbike

/obj/vehicle/space/speedbike/New()
	. = ..()
	overlay = image("icons/obj/bike.dmi", overlay_state)
	overlay.layer = ABOVE_MOB_LAYER
	add_overlay(overlay)

/obj/effect/overlay/temp/speedbike_trail
	name = "speedbike trails"
	icon_state = "ion_fade"
	layer = BELOW_MOB_LAYER
	duration = 10
	randomdir = 0

/obj/effect/overlay/temp/speedbike_trail/New(loc,move_dir)
	..()
	setDir(move_dir)

/obj/vehicle/space/speedbike/Move(newloc,move_dir)
	if(has_buckled_mobs())
		new /obj/effect/overlay/temp/speedbike_trail(loc,move_dir)
	. = ..()

/obj/vehicle/space/speedbike/red
	icon_state = "speedbike_red"
	overlay_state = "cover_red"

//BM SPEEDWAGON

/obj/vehicle/space/speedbike/speedwagon
	name = "BM Speedwagon"
	desc = "Push it to the limit, walk along the razor's edge."
	icon = 'icons/obj/car.dmi'
	icon_state = "speedwagon"
	layer = LYING_MOB_LAYER
	overlay_state = "speedwagon_cover"
	var/crash_all = FALSE //CHAOS
	pixel_y = -48 //to fix the offset when Initialized()
	pixel_x = -48

/obj/vehicle/space/speedbike/speedwagon/Bump(atom/movable/A)
	. = ..()
	if(A.density && has_buckled_mobs())
		var/atom/throw_target = get_edge_target_turf(A, src.dir)
		if(crash_all)
			A.throw_at(throw_target, 4, 3)
			visible_message("<span class='danger'>[src] crashes into [A]!</span>")
			playsound(src, 'sound/effects/bang.ogg', 50, 1)
		if(ishuman(A))
			var/mob/living/carbon/human/H = A
			H.Weaken(5)
			H.adjustStaminaLoss(30)
			H.apply_damage(rand(20,35), BRUTE)
			if(!crash_all)
				H.throw_at(throw_target, 4, 3)
				visible_message("<span class='danger'>[src] crashes into [H]!</span>")
				playsound(src, 'sound/effects/bang.ogg', 50, 1)

/obj/vehicle/space/speedbike/speedwagon/buckle_mob(mob/living/M, force = 0, check_loc = 1)
 	. = ..()
		riding_datum = new/datum/riding/space/speedwagon

/obj/vehicle/space/speedbike/speedwagon/Moved()
	. = ..()
	if(src.has_buckled_mobs())
		for(var/atom/A in range(2, src))
			if(!(A in src.buckled_mobs))
				Bump(A)

//Nukeop Warwagon

/obj/vehicle/space/speedbike/warwagon
	name = "Syndicate Boarding Vessel"
	desc = "Certain well-financed factions within the syndicate have spare no expense."
	icon = 'icons/obj/car.dmi'
	icon_state = "warwagon"
	layer = LYING_MOB_LAYER
	overlay_state = "warwagon_cover"
	max_buckled_mobs = 4
	var/obj/machinery/manned_turret/turret = null

/obj/vehicle/space/speedbike/warwagon/Initialize()
	pixel_y = -48 //to fix the offset when Initialized()
	pixel_x = -48
	turret = new(loc)

/obj/vehicle/space/speedbike/warwagon/Bump(atom/movable/A)
	. = ..()
	if(A.density && has_buckled_mobs())
		var/atom/throw_target = get_edge_target_turf(A, src.dir)
		if(ishuman(A))
			var/mob/living/carbon/human/H = A
			H.Weaken(5)
			H.adjustStaminaLoss(30)
			H.apply_damage(rand(20,35), BRUTE)
			H.throw_at(throw_target, 5, 7)
			visible_message("<span class='danger'>[src] crashes into [H]!</span>")
			playsound(src, 'sound/effects/bang.ogg', 50, 1)
			sleep(5)
			playsound(src, 'sound/items/carhorn.ogg', 50, 1)

/obj/vehicle/space/speedbike/warwagon/buckle_mob(mob/living/M, force = 0, check_loc = 1)
 	. = ..()
		riding_datum = new/datum/riding/space/speedwagon/warwagon

/obj/vehicle/space/speedbike/warwagon/Moved()
	. = ..()
	if(src.has_buckled_mobs())
		for(var/atom/A in range(1, src))
			if(!(A in src.buckled_mobs || A in turret.buckled_mobs))
				Bump(A)

// Manned Turret

/obj/machinery/manned_turret
	name = "Manned Machine Gun Turret"
	icon = 'icons/obj/turrets.dmi'
	icon_state = "syndie_manned"
	can_buckle = TRUE
	buckle_lying = 0
	layer = 4.2
	var/view_range = 9
	var/cooldown = 0
	var/projectile_type = /obj/item/projectile/bullet/weakbullet3

//BUCKLE HOOKS

/obj/machinery/manned_turret/unbuckle_mob(mob/living/buckled_mob,force = 0)
	playsound(src,'sound/mecha/mechmove01.ogg', 50, 1)
	for(var/obj/item/I in buckled_mob.held_items)
		if(istype(I, /obj/item/weapon/turret_control))
			qdel(I)
	if(istype(buckled_mob))
		buckled_mob.pixel_x = 0
		buckled_mob.pixel_y = 0
		if(buckled_mob.client)
			buckled_mob.client.change_view(world.view)
	. = ..()

/obj/machinery/manned_turret/user_buckle_mob(mob/living/M, mob/living/carbon/user)
	if(user.incapacitated() || !istype(user))
		return
	M.loc = get_turf(src)
	..()
	for(var/V in M.held_items)
		var/obj/item/I = V
		if(istype(I))
			if(M.dropItemToGround(I))
				var/obj/item/weapon/turret_control/TC = new /obj/item/weapon/turret_control()
				M.put_in_hands(TC)
		else	//Entries in the list should only ever be items or null, so if it's not an item, we can assume it's an empty hand
			var/obj/item/weapon/turret_control/TC = new /obj/item/weapon/turret_control()
			M.put_in_hands(TC)
	playsound(src,'sound/mecha/mechmove01.ogg', 50, 1)
	if(user.client)
		user.client.change_view(view_range)

/obj/item/weapon/turret_control
	name = "turret controls"
	icon_state = "offhand"
	w_class = WEIGHT_CLASS_HUGE
	flags = ABSTRACT | NODROP
	resistance_flags = FIRE_PROOF | UNACIDABLE | ACID_PROOF | NOBLUDGEON


/obj/item/weapon/turret_control/afterattack(atom/targeted_atom, mob/user)
	..()
	var/obj/machinery/manned_turret/E = user.buckled
	user.dir = get_dir(user,targeted_atom)
	E.dir = get_dir(E,targeted_atom)
	switch(E.dir)
		if(NORTH)
			E.layer = 3.9
			user.pixel_x = E.pixel_x
			user.pixel_y = E.pixel_y - 14
		if(EAST)
			E.layer = 4.1
			user.pixel_x = E.pixel_x - 14
			user.pixel_y = E.pixel_y
		if(SOUTH)
			E.layer = 4.1
			user.pixel_x = E.pixel_x
			user.pixel_y = E.pixel_y + 14
		if(WEST)
			E.layer = 4.1
			user.pixel_x = E.pixel_x + 14
			user.pixel_y = E.pixel_y
	E.fire(targeted_atom, user)

/obj/machinery/manned_turret/proc/fire(atom/targeted_atom, mob/user)
	if(world.time < cooldown)
		return
	else
		cooldown = world.time+60
		INVOKE_ASYNC(src, .proc/shoot, targeted_atom, user)

/obj/machinery/manned_turret/proc/shoot(atom/targeted_atom, mob/user)
	var/turf/targets_from = get_turf(src)
	if(targeted_atom == user || targeted_atom == targets_from)
		return
	for(var/i in 1 to 10)
		if(!targeted_atom)
			return
		var/obj/item/projectile/P = new projectile_type(targets_from)
		P.current = targets_from
		P.starting = targets_from
		P.firer = src
		P.original = targeted_atom
		playsound(src.loc, 'sound/weapons/Gunshot_smg.ogg', 50, 1)
		P.yo = targeted_atom.y - targets_from.y + rand(-1,1)
		P.xo = targeted_atom.x - targets_from.x + rand(-1,1)
		P.fire()
		cooldown = world.time
		sleep(2)