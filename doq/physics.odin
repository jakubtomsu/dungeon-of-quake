package doq

//
// PHYSICS
//

import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"


PHY_MAX_TILE_BOXES :: 4
PHY_BOXCAST_EPS :: 1e-2
PHY_COMPARISON_EPS :: PHY_BOXCAST_EPS*3.0

phy_box_t :: struct {
	pos  : vec3,
	size : vec3,
}



phy_boxVsBox :: proc(pos0 : vec3, size0 : vec3, pos1 : vec3, size1 : vec3) -> bool {
	return  (pos0.x + size0.x > pos1.x - size1.x && pos0.x - size0.x < pos1.x + size1.x) &&
		(pos0.y + size0.y > pos1.y - size1.y && pos0.y - size0.y < pos1.y + size1.y) &&
		(pos0.z + size0.z > pos1.z - size1.z && pos0.z - size0.z < pos1.z + size1.z)
}

// calculates near and far hit points with a box
// @param pos: relative to box center
phy_rayBoxNearFar :: proc(pos : vec3, dirinv : vec3, dirinvabs : vec3, size : vec3) -> (f32, f32) {
	n := dirinv * pos
	k := dirinvabs * size
	t1 := -n - k
	t2 := -n + k
	tn := max(max(t1.x, t1.y), t1.z)
	tf := min(min(t2.x, t2.y), t2.z)
	return tn, tf
}

// hit or inside
phy_nearFarHit :: proc(tn : f32, tf : f32) -> bool {
	return tn<tf && tf>0
}



// "linecast" box through the map
// ! boxsize < TILE_WIDTH
// @returns: newpos, normal, tmin
phy_boxCastTilemap :: proc(pos : vec3, wishpos : vec3, boxsize : vec3) -> (f32, vec3, bool) {
	using math
	posxz := vec2{pos.x, pos.z}
	dir := wishpos - pos
	linelen := linalg.length(dir)
	if !map_isTilePosValid(map_worldToTile(pos)) do return linelen, {0,0.1,0}, false
	lowerleft := map_tilePosClamp(map_worldToTile(pos - vec3{dir.x>0.0 ? 1.0:-1.0, 0.0, dir.z>0.0 ? 1.0:-1.0}*TILE_WIDTH))
	tilepos := lowerleft

	dir = linelen == 0.0 ? {0,-1,0} : dir / linelen
	ddadir := linalg.normalize(vec2{dir.x, dir.z})

	phy_boxCastContext_t :: struct {
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

	ctx : phy_boxCastContext_t = {}

	ctx.pos		= pos
	ctx.dirsign	= vec3{sign(dir.x), sign(dir.y), sign(dir.z)}
	ctx.dirinv	= vec3{
		dir.x==0.0?1e6:1.0/dir.x,
		dir.y==0.0?1e6:1.0/dir.y,
		dir.z==0.0?1e6:1.0/dir.z,
	}//vec3{1,1,1}/dir
	ctx.dirinvabs	= vec3{abs(ctx.dirinv.x), abs(ctx.dirinv.y), abs(ctx.dirinv.z)}
	ctx.boxoffs	= boxsize - {PHY_BOXCAST_EPS, PHY_BOXCAST_EPS, PHY_BOXCAST_EPS}
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
			phy_boxCastTilemapTile(checktiles[j], &ctx)
			//rl.DrawCube(map_tileToWorld(checktiles[j]), TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.Fade(j==0? rl.BLUE : rl.ORANGE, 0.1))
			//rl.DrawCube(map_tileToWorld(checktiles[j]), 2, 1000, 2, rl.Fade(j==0? rl.BLUE : rl.ORANGE, 0.1))
			//rl.DrawCubeWires(map_tileToWorld(checktiles[j]), TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.Fade(j==0? rl.BLUE : rl.ORANGE, 0.1))
		}
	}

	// @dir: precomputed normalize(wishpos - pos)
	// @returns : clipped pos
	phy_boxCastTilemapTile :: proc(coord : ivec2, ctx : ^phy_boxCastContext_t) {
		boxbuf : [PHY_MAX_TILE_BOXES]phy_box_t = {}
		boxcount := map_getTileBoxes(coord, boxbuf[0:])

		for i : i32 = 0; i < boxcount; i += 1 {
			box := boxbuf[i]

			// if debugIsEnabled do rl.DrawCube(box.pos, box.size.x*2+0.2, box.size.y*2+0.2, box.size.z*2+0.2, rl.Fade(rl.GREEN, 0.1))

			n := ctx.dirinv * (ctx.pos - box.pos)
			k := ctx.dirinvabs * (box.size + ctx.boxoffs)
			t1 := -n - k
			t2 := -n + k
			tn := max(max(t1.x, t1.y), t1.z)
			tf := min(min(t2.x, t2.y), t2.z)

			//println("tn", tn, "tf", tf)

			if tn>tf || tf<PHY_COMPARISON_EPS do continue // no intersection (inside counts as intersection)
			if tn>ctx.tmin do continue // this hit is worse than the one we already have
			if tn<-glsl.max(ctx.linelen*1.1, 1.0)-PHY_COMPARISON_EPS do continue
			if math.is_nan(tn) || math.is_nan(tf) || math.is_inf(tn) || math.is_inf(tf) do continue

			//println("ok")
		
			ctx.tmin = tn
			ctx.normal = -ctx.dirsign * cast(vec3)(glsl.step(glsl.vec3{t1.y,t1.z,t1.x}, glsl.vec3{t1.x,t1.y,t1.z}) * glsl.step(glsl.vec3{t1.z,t1.x,t1.y}, glsl.vec3{t1.x,t1.y,t1.z}))
			ctx.hit = true
		}
	}
	
	ctx.tmin = clamp(ctx.tmin, -MAP_MAX_WIDTH*TILE_WIDTH, MAP_MAX_WIDTH*TILE_WIDTH)

	//return pos + dir*ctx.tmin, ctx.normal, ctx.hit
	return ctx.tmin, ctx.normal, ctx.hit
}



// O(n), n = number of enemies
phy_boxCastEnemies :: proc(pos : vec3, wishpos : vec3, boxsize : vec3) -> (res_tn : f32, res_hit : bool, res_enemykind : enemy_kind_t, res_enemyindex : i32) {
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



phy_boxCastPlayer :: proc(pos : vec3, dir : vec3, boxsize : vec3) -> (f32, bool) {
	dirinv := vec3{
		dir.x==0.0?1e6:1.0/dir.x,
		dir.y==0.0?1e6:1.0/dir.y,
		dir.z==0.0?1e6:1.0/dir.z,
	}
	dirinvabs := vec3{abs(dirinv.x), abs(dirinv.y), abs(dirinv.z)}
	tn, tf := phy_rayBoxNearFar(pos - player_data.pos, dirinv, dirinvabs, PLAYER_SIZE + boxsize)
	return tn, phy_nearFarHit(tn, tf)
}




phy_boxCastWorld :: proc(pos : vec3, wishpos : vec3, boxsize : vec3) -> (res_tn : f32, res_hit : bool, res_enemykind : enemy_kind_t, res_enemyindex : i32) {
	e_tn, e_hit, e_enemykind, e_enemyindex := phy_boxCastEnemies(pos, wishpos, boxsize)
	t_tn, t_norm, t_hit := phy_boxCastTilemap(pos, wishpos, boxsize)
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

phy_applyFrictionToVelocity :: proc(vel : vec3, friction : f32) -> vec3 {
	len := linalg.vector_length(vel)
	drop := len * friction * deltatime
	return (len == 0.0 ? {} : vel / len) * (len - drop)
}