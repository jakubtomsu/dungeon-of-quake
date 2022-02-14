package doq



import rl "vendor:raylib"
import "gui"



asset_data : struct {
	defaultShader			: rl.Shader,
	tileShader			: rl.Shader,
	portalShader			: rl.Shader,
	cloudShader			: rl.Shader,
	bulletLineShader		: rl.Shader,

	tileShaderCamPosUniformIndex	: rl.ShaderLocationIndex,

	wallTexture		: rl.Texture2D,
	portalTexture		: rl.Texture2D,
	elevatorTexture		: rl.Texture2D,
	cloudTexture		: rl.Texture2D,

	backgroundMusic		: rl.Music,
	ambientMusic		: rl.Music,
	elevatorSound		: rl.Sound,
	elevatorEndSound	: rl.Sound,

	tileModel		: rl.Model,
	elevatorModel		: rl.Model,
	healthPickupModel	: rl.Model,
	boxModel		: rl.Model, // the wooden crate
	thornsModel		: rl.Model,
	
	player : struct {
		jumpSound		: rl.Sound,
		footstepSound		: rl.Sound,
		landSound		: rl.Sound,
		damageSound		: rl.Sound,
		swooshSound		: rl.Sound,
		healthPickupSound	: rl.Sound,
	},
	
	gun : struct {
		flareModel	: rl.Model,
		gunModels	: [GUN_COUNT]rl.Model,
	
		shotgunSound	: rl.Sound,
		machinegunSound	: rl.Sound,
		laserrifleSound	: rl.Sound,
		headshotSound	: rl.Sound,
		emptyMagSound	: rl.Sound,
		ammoPickupSound	: rl.Sound,
		gunSwitchSound	: rl.Sound,
	},
	
	enemy : struct {
		gruntHitSound		: rl.Sound,
		gruntDeathSound		: rl.Sound,
		knightHitSound		: rl.Sound,
		knightDeathSound	: rl.Sound,
	
		gruntModel		: rl.Model,
		knightModel		: rl.Model,

		knightAnim		: [^]rl.ModelAnimation,
		knightAnimCount		: i32,
	
		knightTexture		: rl.Texture2D,
	},
	
	loadScreenLogo	: rl.Texture,
	loadScreenMusic	: rl.Music,

}



// loads assets we don't need to unload until end of the game
asset_loadPersistent :: proc() {
	asset_data.loadScreenLogo	= loadTexture("dungeon_of_quake_logo.png")
	asset_data.loadScreenMusic	= loadMusic("ambient0.wav")
	rl.SetTextureFilter(asset_data.loadScreenLogo, rl.TextureFilter.TRILINEAR)
	rl.PlayMusicStream(asset_data.loadScreenMusic)

	asset_data.defaultShader	= loadShader("default.vert", "default.frag")
	postprocessShader		= loadFragShader("postprocess.frag")
	asset_data.tileShader		= loadShader("tile.vert", "tile.frag")
	asset_data.portalShader		= loadShader("portal.vert", "portal.frag")
	asset_data.cloudShader		= loadShader("primitive.vert", "cloud.frag")
	asset_data.bulletLineShader	= loadShader("bulletLine.vert", "bulletLine.frag")
	asset_data.tileShaderCamPosUniformIndex = cast(rl.ShaderLocationIndex)rl.GetShaderLocation(asset_data.tileShader, "camPos")

	asset_data.wallTexture		= loadTexture("tile0.png")
	asset_data.portalTexture	= loadTexture("portal.png")
	asset_data.elevatorTexture	= loadTexture("metal.png")
	asset_data.cloudTexture		= loadTexture("clouds.png")

	asset_data.backgroundMusic	= loadMusic("music0.wav")
	asset_data.ambientMusic		= loadMusic("wind.wav")
	asset_data.elevatorSound	= loadSound("elevator.wav")
	asset_data.elevatorEndSound	= loadSound("elevator_end0.wav")
	rl.SetSoundVolume(asset_data.elevatorSound, 0.4)
	rl.PlayMusicStream(asset_data.ambientMusic)
	rl.SetMasterVolume(0.5)

	asset_data.gun.shotgunSound	= loadSound("shotgun.wav")
	asset_data.gun.machinegunSound	= loadSound("machinegun.wav")
	asset_data.gun.laserrifleSound	= loadSound("laserrifle.wav")
	asset_data.gun.headshotSound	= loadSound("headshot.wav")
	asset_data.gun.emptyMagSound	= loadSound("emptymag.wav")
	asset_data.gun.ammoPickupSound	= loadSound("ammo_pickup.wav")
	asset_data.gun.gunSwitchSound	= loadSound("gun_switch.wav")
	rl.SetSoundVolume(asset_data.gun.headshotSound, 1.0)
	rl.SetSoundPitch (asset_data.gun.headshotSound, 0.85)
	rl.SetSoundVolume(asset_data.gun.shotgunSound, 0.55)
	rl.SetSoundPitch (asset_data.gun.shotgunSound, 1.1)
	rl.SetSoundVolume(asset_data.gun.laserrifleSound, 0.2)
	rl.SetSoundPitch(asset_data.gun.laserrifleSound, 0.8)
	rl.SetSoundVolume(asset_data.gun.emptyMagSound, 0.6)
	rl.SetSoundVolume(asset_data.gun.ammoPickupSound, 1.2)

	asset_data.player.jumpSound		= loadSound("jump.wav")
	asset_data.player.footstepSound		= loadSound("footstep.wav")
	asset_data.player.landSound		= loadSound("land.wav")
	asset_data.player.damageSound		= loadSound("death0.wav")
	asset_data.player.swooshSound		= loadSound("swoosh.wav")
	asset_data.player.healthPickupSound	= loadSound("heal.wav")
	rl.SetSoundVolume(asset_data.player.footstepSound, 1.1)
	rl.SetSoundVolume(asset_data.player.landSound, 0.45)
	rl.SetSoundPitch (asset_data.player.landSound, 0.8)

	asset_data.gun.gunModels[cast(i32)gun_kind_t.SHOTGUN]		= loadModel("shotgun.glb")
	asset_data.gun.gunModels[cast(i32)gun_kind_t.MACHINEGUN]	= loadModel("machinegun.glb")
	asset_data.gun.gunModels[cast(i32)gun_kind_t.LASERRIFLE]	= loadModel("laserrifle.glb")
	asset_data.gun.flareModel					= loadModel("flare.glb")

	asset_data.tileModel		= rl.LoadModelFromMesh(rl.GenMeshCube(1.0, 1.0, 1.0))
	asset_data.elevatorModel	= loadModel("elevator.glb")
	asset_data.healthPickupModel	= loadModel("healthpickup.glb")
	asset_data.boxModel		= loadModel("box.glb")
	asset_data.thornsModel		= loadModel("thorns.glb")
	rl.SetMaterialTexture(&asset_data.tileModel.materials[0], rl.MaterialMapIndex.DIFFUSE, asset_data.wallTexture)
	rl.SetMaterialTexture(&asset_data.elevatorModel.materials[0], rl.MaterialMapIndex.DIFFUSE, asset_data.elevatorTexture)
	asset_data.tileModel.materials[0].shader	= asset_data.tileShader
	asset_data.elevatorModel.materials[0].shader	= asset_data.tileShader
	asset_data.boxModel.materials[1].shader		= asset_data.defaultShader

	asset_data.enemy.gruntHitSound		= loadSound("death3.wav")
	asset_data.enemy.gruntDeathSound	= asset_data.enemy.gruntHitSound
	asset_data.enemy.knightHitSound		= asset_data.enemy.gruntHitSound
	asset_data.enemy.knightDeathSound	= asset_data.enemy.gruntHitSound
	asset_data.enemy.gruntModel		= loadModel("grunt.glb")
	asset_data.enemy.knightModel		= loadModel("knight.iqm")
	asset_data.enemy.knightAnim		= loadModelAnim("knight.iqm", &asset_data.enemy.knightAnimCount)
	asset_data.enemy.knightTexture		= loadTexture("knight.png")
	rl.SetMaterialTexture(&asset_data.enemy.knightModel.materials[0], rl.MaterialMapIndex.DIFFUSE, asset_data.enemy.knightTexture)
	rl.SetSoundVolume(asset_data.enemy.gruntHitSound, 0.35)
	rl.SetSoundPitch(asset_data.enemy.gruntHitSound, 1.3)

	gui.menuContext.normalFont	= loadFont("germania_one.ttf")
	gui.menuContext.selectSound	= loadSound("button4.wav")
	gui.menuContext.setValSound	= loadSound("button3.wav")
	rl.SetSoundVolume(gui.menuContext.selectSound, 0.6)
	rl.SetSoundVolume(gui.menuContext.setValSound, 0.8)
}