/obj/item/projectile/bullet
	name = "bullet"
	icon_state = "bullet"
	fire_sound = 'sound/weapons/gunshot/gunshot_strong.ogg'
	damage = 60
	damage_type = BRUTE
	nodamage = 0
	check_armour = "bullet"
	embed = 1
	sharp = 1
	light_power = 2 //Tracers.
	light_range = 2
	light_color = "#E38F46"
	penetration_modifier = 1.0
	var/mob_passthrough_check = 0
	muzzle_type = /obj/effect/projectile/bullet/muzzle

/obj/item/projectile/bullet/on_hit(var/atom/target, var/blocked = 0)
	if (..(target, blocked))
		var/mob/living/L = target
		shake_camera(L, 3, 2)

/obj/item/projectile/bullet/attack_mob(var/mob/living/target_mob, var/distance, var/miss_modifier)
	if(penetrating > 0 && damage > 100 && prob(damage))
		mob_passthrough_check = 1
	else
		mob_passthrough_check = 0
	. = ..()

	if(. == 1 && iscarbon(target_mob))
		damage *= 0.7 //squishy mobs absorb KE

/obj/item/projectile/bullet/can_embed()
	//prevent embedding if the projectile is passing through the mob
	if(mob_passthrough_check)
		return 0
	return ..()

/obj/item/projectile/bullet/before_move()
	..()
	if(istype(starting, /turf/simulated/floor/trench)) //We started out shooting from the trench.
		if(trench_counter > 1 || do_not_pass_trench) //We did not start out at the edge of the trench.
			if(!istype(loc, /turf/simulated/floor/trench)) //We cannot shoot out.
				playsound(src, wall_hitsound, 100, TRUE)
				qdel(src)

		if(istype(loc, /turf/simulated/floor/trench)) //We have travelled to a new trench.
			if(non_trench_counter > 3) //But we passed over open terrain for at least 3 tiles.
				if(istype(loc, get_turf(original)))//We're at our destination.
					playsound(src, wall_hitsound, 100, TRUE)
					qdel(src) //We cannot shoot in.


	if(!istype(starting, /turf/simulated/floor/trench))//We did not start out in the trench.
		if(non_trench_counter > 0)//We have travelled over open terrain.
			if(istype(original.loc, /turf/simulated/floor/trench))//If we clicked on the trench.
				if(istype(loc, /turf/simulated/floor/trench))//We're now at the trench.
					playsound(src, wall_hitsound, 100, TRUE)
					qdel(src) //We cannot shoot in.


/obj/item/projectile/bullet/after_move()
	..()
	if(istype(starting, /turf/simulated/floor/trench)) //Started from a trench.
		if(istype(loc, /turf/simulated/floor/trench)) //Shooting into the same trench.
			trench_counter++ //Add to the counter
		else //Shooting over open terrain?
			non_trench_counter++ //Add to the open terrain counter.

	if(!istype(starting, /turf/simulated/floor/trench)) //Didn't start out in the trench.
		if(!istype(loc, /turf/simulated/floor/trench)) //Not shooting into the trench.
			non_trench_counter++ //Add to the open terrain counter.

/obj/item/projectile/bullet/check_penetrate(var/atom/A)
	if(!A || !A.density) return 1 //if whatever it was got destroyed when we hit it, then I guess we can just keep going

	if(istype(A, /obj/mecha))
		return 1 //mecha have their own penetration handling

	if(ismob(A))
		if(!mob_passthrough_check)
			return 0
		return 1

	var/chance = damage
	if(istype(A, /turf/simulated/wall))
		var/turf/simulated/wall/W = A
		chance = round(damage/W.integrity*180)
	else if(istype(A, /obj/structure/dirt_wall))
		chance = 5
	else if(istype(A, /obj/machinery/door))
		var/obj/machinery/door/D = A
		chance = round(damage/D.maxhealth*180)
		if(D.glass) chance *= 2
	else if(istype(A, /obj/structure/girder))
		chance = 100


	if(prob(chance))
		if(A.opacity)
			//display a message so that people on the other side aren't so confused
			A.visible_message("<span class='warning'>\The [src] pierces through \the [A]!</span>")
		return 1

	return 0

//For projectiles that actually represent clouds of projectiles
/obj/item/projectile/bullet/pellet
	name = "shrapnel" //'shrapnel' sounds more dangerous (i.e. cooler) than 'pellet'
	damage = 50
	icon_state = "shot" //TODO: would be nice to have it's own icon state
	range = 10 	//These disappear after a short distance.
	var/pellets = 4			//number of pellets
	var/range_step = 2		//projectile will lose a fragment each time it travels this distance. Can be a non-integer.
	var/base_spread = 40	//lower means the pellets spread more across body parts. If zero then this is considered a shrapnel explosion instead of a shrapnel cone
	var/spread_step = 10	//higher means the pellets spread more across body parts with distance
	light_power = 9 //No tracers.
	light_range = 0
	light_color = null

/*
/obj/item/projectile/bullet/pellet/Bumped()
	. = ..()
	bumped = 0 //can hit all mobs in a tile. pellets is decremented inside attack_mob so this should be fine.
*/
/obj/item/projectile/bullet/pellet/proc/get_pellets(var/distance)
	var/pellet_loss = round((distance - 1)/range_step) //pellets lost due to distance
	return max(pellets - pellet_loss, 1)

/obj/item/projectile/bullet/pellet/attack_mob(var/mob/living/target_mob, var/distance, var/miss_modifier)
	if (pellets < 0) return 1

	var/total_pellets = get_pellets(distance)
	var/spread = max(base_spread - (spread_step*distance), 0)

	//shrapnel explosions miss prone mobs with a chance that increases with distance
	var/prone_chance = 0
	if(!base_spread)
		prone_chance = max(spread_step*(distance - 2), 0)

	var/hits = 0
	for (var/i in 1 to total_pellets)
		if(target_mob.lying && target_mob != original && prob(prone_chance))
			continue

		//pellet hits spread out across different zones, but 'aim at' the targeted zone with higher probability
		//whether the pellet actually hits the def_zone or a different zone should still be determined by the parent using get_zone_with_miss_chance().
		var/old_zone = def_zone
		def_zone = ran_zone(def_zone, spread)
		if (..()) hits++
		def_zone = old_zone //restore the original zone the projectile was aimed at

	pellets -= hits //each hit reduces the number of pellets left
	if (hits >= total_pellets || pellets <= 0)
		return 1
	return 0

/obj/item/projectile/bullet/pellet/get_structure_damage()
	var/distance = get_dist(loc, starting)
	return ..() * get_pellets(distance)

/obj/item/projectile/bullet/pellet/Move()
	. = ..()

	//If this is a shrapnel explosion, allow mobs that are prone to get hit, too
	if(. && !base_spread && isturf(loc))
		for(var/mob/living/M in loc)
			if(M.lying || !M.CanPass(src, loc, 0.5, 0)) //Bump if lying or if we would normally Bump.
				if(Bump(M)) //Bump will make sure we don't hit a mob multiple times
					return

/* short-casing projectiles, like the kind used in pistols or SMGs */

/obj/item/projectile/bullet/pistol
	damage = 39 //9mm, .38, etc
	fire_sound = "gunshot"
	armor_penetration = 15

/obj/item/projectile/bullet/pistol/medium
	damage = 42 //.45
	armor_penetration = 15
	fire_sound = "gunshot"

/obj/item/projectile/bullet/pistol/medium/smg
	fire_sound = 'sound/weapons/gunshot/gunshot_smg.ogg'
	damage = 39 //10mm
	armor_penetration = 15

/obj/item/projectile/bullet/pistol/medium/revolver
	fire_sound = 'sound/weapons/gunshot/gunshot_strong.ogg'
	damage = 45 //.44 magnum or something
	armor_penetration = 15

/obj/item/projectile/bullet/pistol/strong //matebas
	fire_sound = 'sound/weapons/gunshot/gunshot_strong.ogg'
	damage = 47 //.50AE
	armor_penetration = 15

/obj/item/projectile/bullet/pistol/strong/revolver //revolvers
	damage = 47 //Revolvers get snowflake bullets, to keep them relevant
	armor_penetration = 15

/obj/item/projectile/bullet/pistol/rubber //"rubber" bullets
	name = "rubber bullet"
	check_armour = "bullet"
	damage = 0
	agony = 30
	embed = 0
	sharp = 0
	armor_penetration = 1

/* shotgun projectiles */

/obj/item/projectile/bullet/shotgun
	name = "slug"
	fire_sound = 'sound/weapons/gunshot/shotgun.ogg'
	damage = 65
	armor_penetration = 15
	stun = 1
	weaken = 1

/obj/item/projectile/bullet/shotgun/beanbag		//because beanbags are not bullets
	name = "beanbag"
	check_armour = "melee"
	damage = 10
	armor_penetration = 15
	agony = 60
	embed = 0
	sharp = 0

//Should do about 80 damage at 1 tile distance (adjacent), and 50 damage at 3 tiles distance.
//Overall less damage than slugs in exchange for more damage at very close range and more embedding
/obj/item/projectile/bullet/pellet/shotgun
	name = "buckshot"
	fire_sound = 'sound/weapons/gunshot/shotgun.ogg'
	damage = 30
	pellets = 8
	range_step = 1
	spread_step = 10
	range = 7

/* "Rifle" rounds */

/obj/item/projectile/bullet/rifle
	damage = 40
	armor_penetration = 5

/obj/item/projectile/bullet/rifle/a556
	fire_sound = 'sound/weapons/gunshot/gunshot3.ogg'
	damage = 40
	armor_penetration = 5

/obj/item/projectile/bullet/rifle/a762
	fire_sound = 'sound/weapons/gunshot/gunshot2.ogg'
	damage = 45
	armor_penetration = 30
	penetrating = TRUE
	stun = 1
	weaken = 1

/obj/item/projectile/bullet/rifle/a145
	fire_sound = 'sound/weapons/gunshot/sniper.ogg'
	damage = 65
	stun = 3
	weaken = 3
	armor_penetration = 45
	//hitscan = 1 //so the PTR isn't useless as a sniper weapon
	penetration_modifier = 1.25
	penetrating = 1

/obj/item/projectile/bullet/rifle/a145/apds
	damage = 55
	armor_penetration = 75
	penetration_modifier = 1.5

/obj/item/projectile/bullet/rifle/lp338
	fire_sound = 'sound/weapons/gunshot/sniper.ogg'
	stun = 1.5
	weaken = 1.5
	damage = 90
	armor_penetration = 45
	penetrating = TRUE

/obj/item/projectile/bullet/rifle/lp338/jhp
	name = "JHP bullet"
	fire_sound = 'sound/weapons/gunshot/sniper.ogg'
	stun = 2.5
	weaken = 2.5
	damage = 100
	armor_penetration = 30
	edge = 1

/obj/item/projectile/bullet/rifle/lp338/needler
	name = "needler bullet"
	fire_sound = 'sound/weapons/gunshot/needler.ogg'
	damage = 120
	damage_type = TOX
	stun = null
	weaken = null
	penetration_modifier = 2

/* Miscellaneous */

/obj/item/projectile/bullet/suffocationbullet//How does this even work?
	name = "CO2 bullet"
	damage = 25
	damage_type = OXY

/obj/item/projectile/bullet/cyanideround
	name = "poison bullet"
	damage = 45
	damage_type = TOX

/obj/item/projectile/bullet/burstbullet
	name = "exploding bullet"
	damage = 25
	embed = 0
	edge = 1

/obj/item/projectile/bullet/gyro
	fire_sound = 'sound/effects/explosion1.ogg'

/obj/item/projectile/bullet/gyro/on_hit(var/atom/target, var/blocked = 0)
	if(isturf(target))
		explosion(target, -1, 0, 2)
	..()

/obj/item/projectile/bullet/blank
	invisibility = 101
	damage = 0
	embed = 0


/obj/item/projectile/bullet/bpistol // This is .75 Bolt Pistol Round
	fire_sound = 'sound/effects/explosion1.ogg'
	damage = 50
	armor_penetration = 30
/* Explosive aspect of bullets doesn't work so triaging the code for now.
/obj/item/projectile/bullet/bpistol/on_hit(var/atom/target, var/blocked = 0)
	if(isturf(target))
		explosion(target, -1, 0, 2)
	..()
*/

/obj/item/projectile/bullet/bolt
	fire_sound = 'sound/effects/explosion1.ogg'
	damage = 60
	armor_penetration = 30
/* Explosive aspect of bullets doesn't work so triaging the code for now.
 /obj/item/projectile/bullet/bolt/on_hit(var/atom/target, var/blocked = 0) // This shit is broken.
	if(isturf(target))
		explosion(target, -1, 0, 2)
	..()
*/

/* Practice */

/obj/item/projectile/bullet/pistol/practice
	damage = 5

/obj/item/projectile/bullet/rifle/a762/practice
	damage = 5

/obj/item/projectile/bullet/shotgun/practice
	name = "practice"
	damage = 5

/obj/item/projectile/bullet/pistol/cap
	name = "cap"
	invisibility = 101
	fire_sound = null
	damage_type = PAIN
	damage = 0
	nodamage = 1
	embed = 0
	sharp = 0

/obj/item/projectile/bullet/pistol/cap/Process()
	loc = null
	qdel(src)

/obj/item/projectile/bullet/rock //spess dust
	name = "micrometeor"
	icon_state = "rock"
	damage = 40
	armor_penetration = 25
	range = 255
	light_power = 9 //No tracers.
	light_range = 0
	light_color = null

/obj/item/projectile/bullet/rock/New()
	icon_state = "rock[rand(1,3)]"
	pixel_x = rand(-10,10)
	pixel_y = rand(-10,10)
	..()

/* ORKY BULLETS */

/obj/item/projectile/bullet/ork
	name = "scrap"
	fire_sound = 'sound/weapons/gunshot/gunshot_strong.ogg'
	damage = 42

/obj/item/projectile/bullet/ork/shoota
	name = "piece of trash"
	fire_sound = 'sound/weapons/gunshot/gunshot_strong.ogg'
	damage = 42



//-----SPECIAL BOLT ROUNDS-----

/obj/item/projectile/bullet/bpistol/kp
	fire_sound = 'sound/effects/explosion1.ogg'
	damage = 50
	armor_penetration = 50
	penetration_modifier = 1.4

/obj/item/projectile/bullet/bolt/kp
	fire_sound = 'sound/effects/explosion1.ogg'
	damage = 60
	armor_penetration = 50
	penetration_modifier = 1.8

/obj/item/projectile/bullet/bpistol/ms // This is .75 Bolt Pistol Round
	fire_sound = 'sound/effects/explosion1.ogg'
	damage = 50
	armor_penetration = 20
/obj/item/projectile/bullet/gyro/on_hit(var/atom/target, var/blocked = 0)
	if(isturf(target))
		explosion(target, -1, 0, 2)
	..()

/obj/item/projectile/bullet/bolt/ms
	fire_sound = 'sound/effects/explosion1.ogg'
	damage = 50
	armor_penetration = 20
/obj/item/projectile/bullet/gyro/on_hit(var/atom/target, var/blocked = 0)
	if(isturf(target))
		explosion(target, -1, 0, 2)
	..()

/obj/item/projectile/bullet/rifle/lascannon
	fire_sound = 'sound/weapons/guns/misc/laser_searwall.ogg'
	icon_state = "lasbolt"
	damage = 100
	damage_type = BURN
	armor_penetration = 50
	penetration_modifier = 2

/obj/item/projectile/bullet/rifle/plasma
	fire_sound = 'sound/weapons/guns/misc/laser_searwall.ogg'
	damage = 90
	damage_type = BURN
	armor_penetration = 50
	penetration_modifier = 1.4

/obj/item/projectile/bullet/rifle/plasma/cannon //D E A T H
	fire_sound = 'sound/weapons/guns/misc/laser_searwall.ogg'
	damage = 200
	damage_type = BURN
	armor_penetration = 50
	penetration_modifier = 5

/obj/item/projectile/bullet/rifle/plasma/cannon/orkish //three colors of green!
	fire_sound = 'sound/weapons/guns/misc/laser_searwall.ogg'
	damage = 150
	damage_type = BURN
	armor_penetration = 30
	penetration_modifier = 3

/obj/item/projectile/bullet/rifle/plasma/pistol
	fire_sound = 'sound/weapons/guns/misc/laser_searwall.ogg'
	damage = 70
	damage_type = BURN
	armor_penetration = 40
	penetration_modifier = 1.2

/obj/item/projectile/bullet/rifle/plasma/tau //TAU pulse weapons are plasma weapons bro
	fire_sound = 'sound/weapons/guns/misc/laser_searwall.ogg'
	damage = 55
	damage_type = BURN
	armor_penetration = 20
	penetration_modifier = 1.4


	
/obj/item/projectile/bullet/rifle/lascannon/melta
	fire_sound = 'sound/weapons/guns/misc/laser_searwall.ogg'
	icon_state = "lasbolt"
	damage = 140
	damage_type = BURN
	penetration_modifier = 2 

/obj/item/projectile/bullet/rifle/lascannon/melta/inferno
	fire_sound = 'sound/weapons/guns/misc/laser_searwall.ogg'
	icon_state = "lasbolt"
	damage = 220
	damage_type = BURN
	penetration_modifier = 2

/obj/item/projectile/bullet/rifle/shuriken/catapult
	fire_sound = 'sound/weapons/gunshot/needler.ogg'
	icon_state = "shot"
	damage = 60
	damage_type = BRUTE
	armor_penetration = 35
	penetration_modifier = 2

/obj/item/projectile/bullet/rifle/shuriken/pistol
	fire_sound = 'sound/weapons/gunshot/needler.ogg'
	icon_state = "shot"
	damage = 40
	damage_type = BRUTE
	armor_penetration = 20
	penetration_modifier = 2
