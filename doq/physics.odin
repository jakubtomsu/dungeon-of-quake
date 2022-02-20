package doq

import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"



PHY_MAX_TILE_BOXES :: 4
PHY_BOXCAST_EPS :: 1e-2
PHY_COMPARISON_EPS :: PHY_BOXCAST_EPS*3.0

box_t :: struct {
	pos  : vec3,
	size : vec3,
}



// util
// @returns: true if the two boxes intersect
phy_boxVsBox :: proc(pos0 : vec3, size0 : vec3, pos1 : vec3, size1 : vec3) -> bool {
	return  (pos0.x + size0.x > pos1.x - size1.x && pos0.x - size0.x < pos1.x + size1.x) &&
		(pos0.y + size0.y > pos1.y - size1.y && pos0.y - size0.y < pos1.y + size1.y) &&
		(pos0.z + size0.z > pos1.z - size1.z && pos0.z - size0.z < pos1.z + size1.z)
}

// calculates near and far hit points with a box
// @param pos: relative to box center
// orig. by Inigo Quilez
phy_rayBoxNearFar :: proc(pos : vec3, dirinv : vec3, dirinvabs : vec3, size : vec3) -> (f32, f32) {
	n := dirinv * pos
	k := dirinvabs * size
	t1 := -n - k
	t2 := -n + k
	tn := max(max(t1.x, t1.y), t1.z)
	tf := min(min(t2.x, t2.y), t2.z)
	return tn, tf
}

// raycast box with precomputed ray paramterers
// @param pos: relative to box center
// @returns: time near, time far, normal
phy_raycastBox :: proc(pos : vec3, dirinv : vec3, dirinvabs : vec3, dirsign : vec3, boxsize : vec3) -> (tn : f32, tf : f32, normal : vec3) {
	//using glsl
	n := dirinv * pos
	k := dirinvabs * boxsize
	t1 := -n - k
	t2 := -n + k
	tn = max(max(t1.x, t1.y), t1.z)
	tf = min(min(t2.x, t2.y), t2.z)

	if tn>tf || tf<0.0 do return 1e6, -1e6, {} // no intersection (nside counts as intersection)

	normal = vec3((glsl.step(glsl.vec3{t1.y,t1.z,t1.x}, glsl.vec3{t1.x,t1.y,t1.z}) * glsl.step(glsl.vec3{t1.z,t1.x,t1.y}, glsl.vec3{t1.x,t1.y,t1.z}))) * -dirsign

	return tn, tf, normal
}

// @param rpos: relative to a point on the plane
phy_rayPlane :: proc(rpos : vec3, rdir : vec3, pnorm : vec3) -> f32 {
	using linalg
	return -dot(rpos, pnorm) / dot(rdir, pnorm)
}

// @returns: true if hit or inside
phy_nearFarHit :: proc(tn : f32, tf : f32) -> bool {
	return tn<tf && tf>0
}



// `linecast` box through the map
// `boxsize` < `TILE_WIDTH`
// @returns: newpos, normal, tmin
//
// uses custom DDA for traversing the uniform grid, but also looks at the skipped tile so we don't miss them.
// The boxes queried from a given tile then get expaned by the original boxcast volume, and then raycasted.
// TODO: input pos, dir and length
phy_boxcastTilemap :: proc(pos : vec3, wishpos : vec3, boxsize : vec3) -> (f32, vec3, bool) {
	using math
	posxz := vec2{pos.x, pos.z}
	dir := wishpos - pos
	linelen := linalg.length(dir)
	//println("PHY: linelen", linelen)
	if !map_isTilePosValid(map_worldToTile(pos)) do return linelen, {0,0.1,0}, false
	lowerleft := map_tilePosClamp(map_worldToTile(pos - vec3{dir.x>0.0 ? 1.0:-1.0, 0.0, dir.z>0.0 ? 1.0:-1.0}*TILE_WIDTH))
	tilepos := lowerleft

	dir = linelen == 0.0 ? {0,-1,0} : dir / linelen
	ddadir := linalg.normalize(vec2{dir.x, dir.z})

	phy_boxcastContext_t :: struct {
		pos		: vec3,
		dirsign		: vec3,
		dirinv		: vec3, // 1.0/dir
		dirinvabs	: vec3, // abs(1.0/dir)
		boxoffs		: vec3,
		tmin		: f32,
		normal		: vec3,
		boxlen		: f32,
		hit		: bool,
		linelen		: f32,
	}

	ctx : phy_boxcastContext_t = {}

	//linelen = glsl.max(linelen, PHY_BOXCAST_EPS*2.0)

	ctx.pos		= pos
	ctx.dirsign	= vec3{sign(dir.x), sign(dir.y), sign(dir.z)}
	ctx.dirinv	= vec3{
		dir.x==0.0?1e6:1.0/dir.x,
		dir.y==0.0?1e6:1.0/dir.y,
		dir.z==0.0?1e6:1.0/dir.z,
	}//vec3{1,1,1}/dir
	ctx.dirinvabs	= vec3{abs(ctx.dirinv.x), abs(ctx.dirinv.y), abs(ctx.dirinv.z)}
	ctx.boxoffs	= boxsize + {PHY_BOXCAST_EPS, PHY_BOXCAST_EPS, PHY_BOXCAST_EPS}
	ctx.tmin	= linelen
	ctx.normal	= vec3{0,0.1,0} // debug value
	ctx.boxlen	= linalg.length(boxsize)
	ctx.hit		= false
	ctx.linelen	= linelen

	// DDA init
	deltadist := vec2{abs(1.0/ddadir.x), abs(1.0/ddadir.y)}
	raystepf := vec2{sign(ddadir.x), sign(ddadir.y)}
	griddiff := vec2{cast(f32)lowerleft.x, cast(f32)lowerleft.y} - posxz/TILE_WIDTH
	sidedist := (raystepf * griddiff + (raystepf * 0.5) + vec2{0.5, 0.5}) * deltadist
	raystep := ivec2{ddadir.x>0.0 ? 1 : -1, ddadir.y>0.0 ? 1 : -1}

	//println("pos", pos, "griddiff", griddiff, "lowerleft", lowerleft, "posxz", posxz, "sidedist", sidedist, "deltadist", deltadist)

	// DDA traversal
	for {
		if !map_isTilePosValid(tilepos) ||
		(linalg.length(vec2{cast(f32)(tilepos.x - lowerleft.x), cast(f32)(tilepos.y - lowerleft.y)})-3.0)*TILE_WIDTH > ctx.tmin {
			break
		}

		checktiles : [2]ivec2
		checktiles[0] = tilepos
		checktiles[1] = tilepos

		// advance DDA
		if sidedist.x < sidedist.y {
			sidedist.x += deltadist.x
			tilepos.x += raystep.x
			checktiles[1].y += raystep.y
		} else {
			sidedist.y += deltadist.y
			tilepos.y += raystep.y
			checktiles[1].x += raystep.x
		}

		//println("tilepos", tilepos, "(orig)checktiles[0]", checktiles[0], "(near)checktiles[1]", checktiles[1])
	
		for j : i32 = 0; j < len(checktiles); j += 1 {
			//println("checktile")
			if !map_isTilePosValid(checktiles[j]) do continue
			phy_boxcastTilemapTile(checktiles[j], &ctx)
			//rl.DrawCube(map_tileToWorld(checktiles[j]), TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.Fade(j==0? rl.BLUE : rl.ORANGE, 0.1))
			//rl.DrawCube(map_tileToWorld(checktiles[j]), 2, 1000, 2, rl.Fade(j==0? rl.BLUE : rl.ORANGE, 0.1))
			//rl.DrawCubeWires(map_tileToWorld(checktiles[j]), TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.Fade(j==0? rl.BLUE : rl.ORANGE, 0.1))
		}
	}

	// @dir: precomputed `normalize(wishpos - pos)`
	// @returns : clipped pos
	phy_boxcastTilemapTile :: proc(coord : ivec2, ctx : ^phy_boxcastContext_t) {
		boxbuf : [PHY_MAX_TILE_BOXES]box_t = {}
		boxcount := map_getTileBoxes(coord, boxbuf[:])

		for i : i32 = 0; i < boxcount; i += 1 {
			box := boxbuf[i]

			// if debugIsEnabled do rl.DrawCube(box.pos, box.size.x*2+0.2, box.size.y*2+0.2, box.size.z*2+0.2, rl.Fade(rl.GREEN, 0.1))

			n := ctx.dirinv * (ctx.pos - box.pos)
			k := ctx.dirinvabs * (box.size + ctx.boxoffs)
			t1 := -n - k
			t2 := -n + k
			tn := max(max(t1.x, t1.y), t1.z)
			tf := min(min(t2.x, t2.y), t2.z)

			if tn>tf || tf<PHY_COMPARISON_EPS do continue // no intersection (inside counts as intersection)
			if tn>ctx.tmin do continue // this hit is worse than the one we already have
			if tn<-glsl.max(ctx.linelen, 1.0)*5.0 - PHY_COMPARISON_EPS do continue // disallow movement too far back
			if math.is_nan(tn) || math.is_nan(tf) || math.is_inf(tn) || math.is_inf(tf) do continue

			ctx.tmin = tn
			ctx.normal = -ctx.dirsign * cast(vec3)(glsl.step(glsl.vec3{t1.y,t1.z,t1.x}, glsl.vec3{t1.x,t1.y,t1.z}) * glsl.step(glsl.vec3{t1.z,t1.x,t1.y}, glsl.vec3{t1.x,t1.y,t1.z}))
			ctx.hit = true
		}
	}
	
	ctx.tmin = clamp(ctx.tmin, -MAP_SIDE_TILE_COUNT*TILE_WIDTH, MAP_SIDE_TILE_COUNT*TILE_WIDTH)

	return ctx.tmin, ctx.normal, ctx.hit
}



// just a brute-force raycast of all enemies, good enough though
// O(n), n = number of enemies
phy_boxcastEnemies :: proc(pos : vec3, wishpos : vec3, boxsize : vec3) -> (res_tn : f32, res_hit : bool, res_enemykind : enemy_kind_t, res_enemyindex : i32) {
	using math

	dir := wishpos - pos
	dirlen := linalg.length(dir)
	dir = dirlen == 0.0 ? {0,-1,0} : dir/dirlen
	dirinv := vec3{
		dir.x==0.0?1e6:1.0/dir.x,
		dir.y==0.0?1e6:1.0/dir.y,
		dir.z==0.0?1e6:1.0/dir.z,
	}
	dirinvabs := vec3{abs(dirinv.x), abs(dirinv.y), abs(dirinv.z)}

	tnear : f32 = dirlen

	for i : i32 = 0; i < enemy_data.gruntCount; i += 1 {
		if enemy_data.grunts[i].health <= 0.0 do continue
		tn, tf := phy_rayBoxNearFar(pos - enemy_data.grunts[i].pos, dirinv, dirinvabs, ENEMY_GRUNT_SIZE + boxsize)
		if phy_nearFarHit(tn, tf) && tn < tnear {
			tnear = tn
			res_hit = true
			res_enemykind = enemy_kind_t.GRUNT
			res_enemyindex = i
		}
	}

	for i : i32 = 0; i < enemy_data.knightCount; i += 1 {
		if enemy_data.knights[i].health <= 0.0 do continue
		tn, tf := phy_rayBoxNearFar(pos - enemy_data.knights[i].pos, dirinv, dirinvabs, ENEMY_KNIGHT_SIZE + boxsize)
		if phy_nearFarHit(tn, tf) && tn < tnear {
			tnear = tn
			res_hit = true
			res_enemykind = enemy_kind_t.KNIGHT
			res_enemyindex = i
		}
	}

	res_tn = tnear
	return
}



// fires ray directly downwards
// @returns: minimum depth
phy_raycastDepth :: proc(pos : vec3) -> f32 {
	tilecoord := map_worldToTile(pos)
	if !map_isTilePosValid(tilecoord) do return 1e6
	boxbuf : [PHY_MAX_TILE_BOXES]box_t
	boxcount := map_getTileBoxes(tilecoord, boxbuf[0:])

	tmin : f32 = 1e6
	for i : i32 = 0; i < boxcount; i += 1 {
		relpos := pos - boxbuf[i].pos
		// check XZ bounds
		if relpos.x > boxbuf[i].size.x || relpos.z > boxbuf[i].size.z || relpos.x < -boxbuf[i].size.x || relpos.z < -boxbuf[i].size.z {
			continue
		}
	
		tn := -(+boxbuf[i].size.y-relpos.y)
		tf := -(-boxbuf[i].size.y-relpos.y)
		if tf>0.0 && tn<tmin {
			tmin = tn
		}
	}

	return tmin
}



phy_boxcastPlayer :: proc(pos : vec3, dir : vec3, boxsize : vec3) -> (f32, bool) {
	dirinv := vec3{
		dir.x==0.0?1e6:1.0/dir.x,
		dir.y==0.0?1e6:1.0/dir.y,
		dir.z==0.0?1e6:1.0/dir.z,
	}
	dirinvabs := vec3{abs(dirinv.x), abs(dirinv.y), abs(dirinv.z)}
	tn, tf := phy_rayBoxNearFar(pos - player_data.pos, dirinv, dirinvabs, PLAYER_SIZE + boxsize)
	return tn, phy_nearFarHit(tn, tf)
}




phy_boxcastWorld :: proc(pos : vec3, wishpos : vec3, boxsize : vec3) -> (res_tn : f32, res_hit : bool, res_enemykind : enemy_kind_t, res_enemyindex : i32) {
	e_tn, e_hit, e_enemykind, e_enemyindex := phy_boxcastEnemies(pos, wishpos, boxsize)
	t_tn, t_norm, t_hit := phy_boxcastTilemap(pos, wishpos, boxsize)
	_ = t_norm

	if e_tn < t_tn {
		res_tn		= e_tn
		res_hit		= e_hit
		res_enemykind	= e_enemykind
		res_enemyindex	= e_enemyindex
	} else {
		res_tn		= t_tn
		res_hit		= t_hit
		res_enemykind	= enemy_kind_t.NONE
	}

	return
}



phy_clipVelocity :: proc(vel : vec3, normal : vec3, overbounce : f32) -> vec3 {
	backoff := linalg.vector_dot(vel, normal) * overbounce
	change := normal*backoff
	return vel - change
}

// retains speed
phy_slideVelocityOnSurf :: proc(vel : vec3, normal : vec3) -> vec3 {
	using linalg
	d := dot(vel, normal)
	if d > 0.0 do return vel
	vlen := length(vel)
	slidevec := vel - normal*d
	if slidevec == {} do return {}
	slidevel := normalize(slidevec) * vlen
	return slidevel
}



phy_applyFrictionToVelocity :: proc(vel : vec3, friction : f32, disallowNegative : bool = true) -> vec3 {
	len := linalg.length(vel)
	drop := len * friction * deltatime
	if disallowNegative do return (len == 0.0 ? {} : vel / len) * glsl.max(0.0, len - drop)
	return (len == 0.0 ? {} : vel / len) * (len - drop)
}




// collides only with static geo!
// @param rad: this expands the box to rounded box with that radius
phy_simulateMovingBox :: proc(pos : vec3, vel : vec3, friction : f32, boxsize : vec3, rad : f32) -> (newpos : vec3, newvel : vec3, hit : bool, normal : vec3) {
	using linalg
	wishpos := pos + vel*deltatime
	vellen := length(vel)
	if vellen == 0.0 do return wishpos, vel, false, {}
	dir := vel / vellen
	_ = dir

	RESTITUTUION_BIAS :: 0.0
	SOLVER_BETA :: 0.4
	SOLVER_SLOP :: 0.1

	// discrete collision detection
	/*
	{
		tilepos := map_worldToTile(pos)
		//box := box_t{pos, boxsize}

		impulse := vec3{}
		penetration_accumulated_impulse : f32 = 0.0

		//dirinv := vec3InvSafe(dir)
		//dirinvabs := vec3(glsl.abs(transmute(glsl.vec3)dirinv))
		//dirsign := vec3(glsl.sign(transmute(glsl.vec3)dir))

		for x : i32 = 0; x <= 1; x += 1 {
			for y : i32 = 0; y <= 1; y += 1 {
				coord := tilepos + {x, y}
				boxbuf : [PHY_MAX_TILE_BOXES]box_t = {}
				boxcount := map_getTileBoxes(coord, boxbuf[:])

				for i : i32 = 0; i < boxcount; i += 1 {
					penetration_depth, sep_axis := phy_sdgBox(
						pos-boxbuf[i].pos,
						boxsize+boxbuf[i].size,
					)
					penetration_depth = -penetration_depth - rad
	
					if penetration_depth < 0.0 do continue

					if penetration_depth > 0.0 {
						hit = true
						normal += sep_axis
					}

					// solve constraint
					delta_v := vel
					delta_v_dot_n : f32 = dot(delta_v, sep_axis)
					bias_penetration_depth : f32 = -(SOLVER_BETA / deltatime) * glsl.max(0.0, penetration_depth - SOLVER_SLOP)
					constraint_bias : f32 = bias_penetration_depth + RESTITUTUION_BIAS
					penetration_delta_lambda_initial : f32 = -(delta_v_dot_n + constraint_bias)
					penetration_lambda_temp : f32 = penetration_accumulated_impulse
					// clamp lambda the correct way
					penetration_accumulated_impulse = glsl.max(0.0, penetration_delta_lambda_initial + penetration_lambda_temp)
					penetration_delta_lambda_final : f32 = penetration_accumulated_impulse - penetration_lambda_temp
					linear_impulse := sep_axis * penetration_delta_lambda_final
					impulse += linear_impulse
				}
			}
		}

		normal = linalg.normalize(normal)
		newvel = vel + impulse
		newpos = pos + newvel*deltatime

		return newpos, newvel, hit, normal
	}
	*/

	// continuous collision
	// can be buggy with small delta
	cast_tn, cast_norm, cast_hit := phy_boxcastTilemap(pos, wishpos, boxsize)

	if !cast_hit {
		newpos = wishpos
		newvel = vel
		hit = false
		normal = cast_norm
		return newpos, newvel, hit, normal
	}

	//contact_point := pos + dir*cast_tn

	//slop_tn := phy_rayPlane(pos - (cast_point - cast_norm*PHY_BOXCAST_EPS), dir, cast_norm)



	// constraint solver attempt.
	// works, but glitches sometimes :(
	/*
	delta_v := vel
	penetration_depth : f32 = dot(pos - contact_point, cast_norm) //!!!
	delta_v_dot_n : f32 = dot(delta_v, cast_norm)
	bias_penetration_depth : f32 = -(SOLVER_BETA / deltatime) * glsl.max(0.0, penetration_depth - SOLVER_SLOP)
	constraint_bias : f32 = bias_penetration_depth + RESTITUTUION_BIAS
	speculative_offset := cast_tn
	_ = speculative_offset
	penetration_delta_lambda : f32 = -(delta_v_dot_n + constraint_bias + speculative_offset)
	linear_impulse := cast_norm * penetration_delta_lambda
	newvel = vel + linear_impulse
	newpos = pos + newvel*deltatime
	*/



	EPS :: 0.05
	newpos = pos + dir*cast_tn + cast_norm*EPS
	//newvel = dir*(glsl.max(0.0, cast_tn)/deltatime + EPS/deltatime) - cast_norm*0.1*EPS/deltatime
	newvel = dir*(cast_tn/deltatime + EPS/deltatime) - cast_norm*0.1*EPS/deltatime

	hit = true //cast_tn>0.0
	normal = cast_norm
	return newpos, newvel, hit, normal
}



phy_boxPenetrationDepth :: proc(b0 : box_t, b1 : box_t) -> (penetration : f32, axis : vec3) {
	using math

	size := b0.size + b1.size

	dx := abs(b0.pos.x - b1.pos.x)
	dy := abs(b0.pos.y - b1.pos.y)
	dz := abs(b0.pos.z - b1.pos.z)

	axis = {}

	cx := dx / size.x
	cy := dy / size.y
	cz := dz / size.z

	if cx > cy {
		if cx > cz {
			penetration = size.x - dx
			axis.x = b0.pos.x > b1.pos.x ? 1.0 : -1.0
		} else {
			penetration = size.z - dz
			axis.z = b0.pos.z > b1.pos.z ? 1.0 : -1.0
		}
	
	} else {
		if cy > cz {
			penetration = size.y - dy
			axis.y = b0.pos.y > b1.pos.y ? 1.0 : -1.0
		} else {
			penetration = size.z - dz
			axis.z = b0.pos.z > b1.pos.z ? 1.0 : -1.0
		}
	}

	return penetration, axis
}

// https://iquilezles.org/www/articles/distgradfunctions2d/distgradfunctions2d.htm
// box signed-distance and gradient, extended to 3d
phy_sdgBox :: proc(p : vec3, b : vec3) -> (sd : f32, grad : vec3) {
	w : glsl.vec3 = glsl.abs(glsl.vec3(p)) - glsl.vec3(b)
	s := glsl.vec3{p.x<0.0?-1:1, p.y<0.0?-1:1, p.z<0.0?-1:1}
	g := glsl.max(w.x, glsl.max(w.y, w.z))
	q := glsl.max(w, 0.0)
	l := glsl.length(q)
	sd = (g>0.0)?l:g
	grad = vec3(s * ((g>0.0)? q/l : (w.x>w.y? (w.x>w.z? glsl.vec3{1,0,0}:glsl.vec3{0,0,1}) : (w.y>w.z? glsl.vec3{0,1,0}:glsl.vec3{0,0,1}))))
	return sd, grad
}



vec3InvSafe :: proc(v : vec3) -> vec3 {
	return {
		v.x == 0.0 ? 1e6 : 1.0/v.x,
		v.y == 0.0 ? 1e6 : 1.0/v.y,
		v.z == 0.0 ? 1e6 : 1.0/v.z,
	}
}