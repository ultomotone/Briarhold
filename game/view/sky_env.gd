## Sky, fog, ambient, and the sun, all from the palette, blended by the clock. Day and night are
## two full palettes; the view blends them by one continuous darkness value (see darkness()).
class_name SkyEnv
extends Node3D

var env: WorldEnvironment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var pal: PaletteData


func build(p: PaletteData) -> void:
	pal = p
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 22.0
	sky_mat.sun_curve = 0.14
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.55
	# the palette's greens were coming out as mud: the grey sky ambient plus the filmic curve
	# desaturate everything. Pull the saturation back up in the final grade.
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.2
	e.adjustment_contrast = 1.06
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.tonemap_white = 4.0
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_sky_affect = 0.35
	e.fog_aerial_perspective = 0.3
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.012
	e.volumetric_fog_anisotropy = 0.55
	e.volumetric_fog_length = 96.0
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 1.6
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 1.05
	env = WorldEnvironment.new()
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.2
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.6
	sun.light_angular_distance = 1.2
	add_child(sun)
	apply(300.0, 900.0, 360.0)


## One darkness value over the whole cycle, never a switch: dusk runs from DUSK_LEAD seconds
## before nightfall to DUSK_TAIL after it; dawn from DAWN_LEAD before daybreak to DAWN_TAIL
## after. Both ends meet, so the frame at nightfall and the frame at daybreak match their
## neighbours exactly (it used to drop from half-dark back to day at nightfall).
const DUSK_LEAD: float = 150.0
const DUSK_TAIL: float = 70.0
const DAWN_LEAD: float = 90.0
const DAWN_TAIL: float = 45.0


static func darkness(time: float, day_s: float, night_s: float) -> float:
	var cycle: float = day_s + night_s
	var dusk: float = smoothstep(day_s - DUSK_LEAD, day_s + DUSK_TAIL, time)
	var dawn: float = smoothstep(cycle - DAWN_LEAD, cycle + DAWN_TAIL, time)
	var tail: float = 1.0 - smoothstep(-DAWN_LEAD, DAWN_TAIL, time) # the end of last night's dawn
	return maxf(dusk * (1.0 - dawn), tail)


## time: seconds into the cycle (0 = daybreak, day_s = nightfall).
func apply(time: float, day_s: float, night_s: float) -> void:
	var n: float = darkness(time, day_s, night_s)
	# the warm band: strongest halfway through dusk or dawn, nothing at noon or midnight
	var glow: float = 4.0 * n * (1.0 - n)
	var sun_t: float = clampf(time / day_s, 0.0, 1.0)
	var night_t: float = clampf((time - day_s) / night_s, 0.0, 1.0)
	sky_mat.sky_top_color = pal.col("sky_zenith_day").lerp(pal.col("sky_zenith_night"), n)
	var horizon: Color = pal.col("sky_horizon_day").lerp(pal.col("sky_horizon_night"), n)
	sky_mat.sky_horizon_color = horizon.lerp(pal.col("sky_horizon_dusk"), glow * 0.65)
	sky_mat.ground_bottom_color = pal.col("terrain_loam").darkened(0.5)
	sky_mat.ground_horizon_color = pal.col("fog_day").lerp(pal.col("fog_night"), n)
	var e: Environment = env.environment
	e.fog_light_color = pal.col("fog_day").lerp(pal.col("fog_night"), n).lerp(pal.col("sky_horizon_dusk"), glow * 0.3)
	e.fog_density = lerpf(pal.num("fog_density_day"), pal.num("fog_density_night"), n)
	e.volumetric_fog_albedo = e.fog_light_color
	e.volumetric_fog_density = lerpf(0.004, 0.02, n)
	e.ambient_light_energy = lerpf(pal.num("ambient_energy_day"), pal.num("ambient_energy_night"), n)
	sun.light_color = pal.col("sun_day").lerp(pal.col("sun_night"), n).lerp(pal.col("sun_dusk"), glow * 0.7)
	sun.light_energy = lerpf(pal.num("sun_energy_day"), pal.num("sun_energy_night"), n)
	# the sun arcs low-high-low over the day; the moon crosses back over the night; the light is
	# a blend of the two by darkness, so it slides, it never jumps
	var day_pitch: float = -18.0 - (absf(pal.num("sun_pitch_day_deg")) - 18.0) * sin(PI * sun_t)
	var day_yaw: float = (sun_t - 0.5) * 70.0
	var night_yaw: float = (0.5 - night_t) * 70.0
	var pitch: float = lerpf(day_pitch, pal.num("sun_pitch_night_deg"), n)
	var yaw: float = pal.num("sun_yaw_deg") + lerpf(day_yaw, night_yaw, n)
	sun.rotation_degrees = Vector3(pitch, yaw, 0.0)
	sky_mat.sun_angle_max = 22.0
