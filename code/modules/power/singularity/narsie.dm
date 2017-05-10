/obj/singularity/narsie //Moving narsie to a child object of the singularity so it can be made to function differently. --NEO
	name = "Nar-sie's Avatar"
	desc = "Your mind begins to bubble and ooze as it tries to comprehend what it sees."
	icon = 'icons/obj/magic_terror.dmi'
	pixel_x = -89
	pixel_y = -85
	density = 0
	current_size = 9 //It moves/eats like a max-size singulo, aside from range. --NEO
	contained = 0 //Are we going to move around?
	dissipate = 0 //Do we lose energy over time?
	move_self = 1 //Do we move on our own?
	grav_pull = 5 //How many tiles out do we pull?
	consume_range = 6 //How many tiles out do we eat
	light_power = 0.7
	light_range = 15
	light_color = rgb(255, 0, 0)
	gender = FEMALE
	var/clashing = FALSE //If Nar-Sie is fighting Ratvar

/obj/singularity/narsie/large
	name = "Nar-Sie"
	icon = 'icons/obj/narsie.dmi'
	// Pixel stuff centers Narsie.
	pixel_x = -236
	pixel_y = -256
	current_size = 12
	grav_pull = 10
	consume_range = 12 //How many tiles out do we eat

/obj/singularity/narsie/large/Initialize()
	. = ..()
	send_to_playing_players("<span class='narsie'>NAR-SIE HAS RISEN</span>")
	send_to_playing_players(pick('sound/hallucinations/im_here1.ogg', 'sound/hallucinations/im_here2.ogg'))

	var/area/A = get_area(src)
	if(A)
		var/mutable_appearance/alert_overlay = mutable_appearance('icons/effects/effects.dmi', "ghostalertsie")
		notify_ghosts("Nar-Sie has risen in \the [A.name]. Reach out to the Geometer to be given a new shell for your soul.", source = src, alert_overlay = alert_overlay, action=NOTIFY_ATTACK)
	narsie_spawn_animation()




/obj/singularity/narsie/large/cult  // For the new cult ending, guaranteed to end the round within 3 minutes
	var/list/souls_needed = list()
	var/soul_goal = 0
	var/souls = 0
	var/resolved = FALSE

/obj/singularity/narsie/large/cult/proc/resize(var/ratio)
	var/matrix/ntransform = matrix(transform) //aka transform.Copy()
	ntransform.Scale(ratio)
	animate(src, transform = ntransform, time = 40, easing = EASE_IN|EASE_OUT)

/obj/singularity/narsie/large/cult/Initialize()
	. = ..()
	resize(0.5)
	for(var/datum/mind/cult_mind in SSticker.mode.cult)
		if(ishuman(cult_mind.current))
			var/mob/living/M = cult_mind.current
			M.narsie_act()
	for(var/mob/living/player in GLOB.player_list)
		if(player.stat != DEAD && player.loc.z == 1 && !iscultist(player))
			souls_needed += player
	soul_goal = round(LAZYLEN(souls_needed) * 0.666)
	sleep(600)
	set_security_level("delta")
	SSshuttle.registerHostileEnvironment(src)
	SSshuttle.lockdown = TRUE
	sleep(1200)
	if(resolved == FALSE)
		var/bomb
		for(var/obj/machinery/nuclearbomb/nuke in GLOB.poi_list)
			if(istype(/obj/machinery/nuclearbomb/selfdestruct, nuke))
				bomb = nuke
		SSticker.station_explosion_cinematic(0,"cult", bomb)
		sleep(100)
		SSticker.force_ending = 1


/obj/singularity/narsie/large/cult/consume(atom/A)
	A.narsie_act(src)


/obj/singularity/narsie/large/attack_ghost(mob/dead/observer/user as mob)
	makeNewConstruct(/mob/living/simple_animal/hostile/construct/harvester, user, null, 0, loc_override = src.loc)
	new /obj/effect/particle_effect/smoke/sleeping(src.loc)


/obj/singularity/narsie/process()
	if(clashing)
		return
	eat()
	if(!target || prob(5))
		pickcultist()
	if(istype(target, /obj/structure/destructible/clockwork/massive/ratvar))
		move(get_dir(src, target)) //Oh, it's you again.
	else
		move()
	if(prob(25))
		mezzer()


/obj/singularity/narsie/Process_Spacemove()
	return clashing


/obj/singularity/narsie/Bump(atom/A)
	var/turf/T = get_turf(A)
	if(T == loc)
		T = get_step(A, A.dir) //please don't slam into a window like a bird, nar-sie
	forceMove(T)


/obj/singularity/narsie/mezzer()
	for(var/mob/living/carbon/M in viewers(consume_range, src))
		if(M.stat == CONSCIOUS)
			if(!iscultist(M))
				to_chat(M, "<span class='cultsmall'>You feel conscious thought crumble away in an instant as you gaze upon [src.name]...</span>")
				M.apply_effect(3, STUN)


/obj/singularity/narsie/consume(atom/A)
	A.narsie_act()


/obj/singularity/narsie/ex_act() //No throwing bombs at her either.
	return


/obj/singularity/narsie/proc/pickcultist() //Narsie rewards her cultists with being devoured first, then picks a ghost to follow.
	var/list/cultists = list()
	var/list/noncultists = list()
	for(var/obj/structure/destructible/clockwork/massive/ratvar/enemy in GLOB.poi_list) //Prioritize killing Ratvar
		if(enemy.z != z)
			continue
		acquire(enemy)
		return

	for(var/mob/living/carbon/food in GLOB.living_mob_list) //we don't care about constructs or cult-Ians or whatever. cult-monkeys are fair game i guess
		var/turf/pos = get_turf(food)
		if(pos.z != src.z)
			continue

		if(iscultist(food))
			cultists += food
		else
			noncultists += food

		if(cultists.len) //cultists get higher priority
			acquire(pick(cultists))
			return

		if(noncultists.len)
			acquire(pick(noncultists))
			return

	//no living humans, follow a ghost instead.
	for(var/mob/dead/observer/ghost in GLOB.player_list)
		if(!ghost.client)
			continue
		var/turf/pos = get_turf(ghost)
		if(pos.z != src.z)
			continue
		cultists += ghost
	if(cultists.len)
		acquire(pick(cultists))
		return


/obj/singularity/narsie/proc/acquire(atom/food)
	if(food == target)
		return
	to_chat(target, "<span class='cultsmall'>NAR-SIE HAS LOST INTEREST IN YOU.</span>")
	target = food
	if(ishuman(target))
		to_chat(target, "<span class ='cult'>NAR-SIE HUNGERS FOR YOUR SOUL.</span>")
	else
		to_chat(target, "<span class ='cult'>NAR-SIE HAS CHOSEN YOU TO LEAD HER TO HER NEXT MEAL.</span>")

//Wizard narsie
/obj/singularity/narsie/wizard
	grav_pull = 0

/obj/singularity/narsie/wizard/eat()
	set background = BACKGROUND_ENABLED
//	if(defer_powernet_rebuild != 2)
//		defer_powernet_rebuild = 1
	for(var/atom/X in urange(consume_range,src,1))
		if(isturf(X) || istype(X, /atom/movable))
			consume(X)
//	if(defer_powernet_rebuild != 2)
//		defer_powernet_rebuild = 0
	return


/obj/singularity/narsie/proc/narsie_spawn_animation()
	icon = 'icons/obj/narsie_spawn_anim.dmi'
	setDir(SOUTH)
	move_self = 0
	flick("narsie_spawn_anim",src)
	sleep(11)
	move_self = 1
	icon = initial(icon)



