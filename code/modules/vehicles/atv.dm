
/obj/vehicle/atv
	name = "all-terrain vehicle"
	desc = "An all-terrain vehicle built for traversing rough terrain with ease. One of the few old-earth technologies that are still relevant on most planet-bound outposts."
	icon_state = "atv"
	var/static/image/atvcover = null

/obj/vehicle/atv/buckle_mob(mob/living/buckled_mob, force = 0, check_loc = 1)
	. = ..()
	riding_datum = new/datum/riding/atv

/obj/vehicle/atv/New()
	..()
	if(!atvcover)
		atvcover = image("icons/obj/vehicles.dmi", "atvcover")
		atvcover.layer = ABOVE_MOB_LAYER


/obj/vehicle/atv/post_buckle_mob(mob/living/M)
	if(has_buckled_mobs())
		add_overlay(atvcover)
	else
		cut_overlay(atvcover)


//TURRETS!
/obj/vehicle/atv/turret
	var/obj/machinery/manned_turret/turret = null

/obj/vehicle/atv/turret/New()
	. = ..()
	turret = new(loc)

/obj/vehicle/atv/turret/buckle_mob(mob/living/buckled_mob, force = 0, check_loc = 1)
	. = ..()
	riding_datum = new/datum/riding/atv/turret


// Manned Turret

/obj/machinery/manned_turret
	name = "Manned Machine Gun Turret"
	icon = 'icons/obj/turrets.dmi'
	icon_state = "syndie_manned"
	can_buckle = TRUE
	buckle_lying = 0
	var/view_range = 9
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
			user.pixel_x = 0
			user.pixel_y = -14
		if(EAST)
			E.layer = 4.1
			user.pixel_x = -14
			user.pixel_y = 0
		if(SOUTH)
			E.layer = 4.1
			user.pixel_x = 0
			user.pixel_y = 14
		if(WEST)
			E.layer = 4.1
			user.pixel_x = 14
			user.pixel_y = 0
	E.fire(targeted_atom, user)

/obj/machinery/manned_turret/proc/fire(atom/targeted_atom, mob/user)
	var/turf/targets_from = get_turf(src)
	if(targeted_atom == user || targeted_atom == targets_from)
		return
	for(var/i in 1 to 10)
		var/obj/item/projectile/P = new projectile_type(targets_from)
		P.current = targets_from
		P.starting = targets_from
		P.firer = src
		P.original = targeted_atom
		playsound(src.loc, 'sound/weapons/Gunshot_smg.ogg', 50, 1)
		P.yo = targeted_atom.y - targets_from.y + rand(-2,2)
		P.xo = targeted_atom.x - targets_from.x + rand(-2,2)
		P.fire()
		sleep(2)
	return