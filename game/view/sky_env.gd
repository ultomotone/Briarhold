## Sky, fog, ambient, and the sun, all from the palette, blended by the clock. Day and night are
## two full palettes; the view lerps between them so dusk is a real transition, not a switch.
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
	e.ambient_light_sky_contribution = 0.85
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.tonemap_white = 1.2
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_sky_affect = 0.55
	e.fog_aerial_perspective = 0.6
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
	apply(0.35, 0.0)


## sun_t 0..1 through the day; night_t 0..1 through the night (0 by day).
func apply(sun_t: float, night_t: float) -> void:
	# dusk and dawn blend over the last/first tenth of the day and the first/last tenth of night
	var n: float = 0.0
	if night_t > 0.0:
		n = clampf(minf(night_t / 0.12, (1.0 - night_t) / 0.12), 0.0, 1.0)
	else:
		n = clampf((sun_t - 0.9) / 0.1, 0.0, 1.0) * 0.55
	sky_mat.sky_top_color = pal.col("sky_zenith_day").lerp(pal.col("sky_zenith_night"), n)
	sky_mat.sky_horizon_color = pal.col("sky_horizon_day").lerp(pal.col("sky_horizon_night"), n)
	sky_mat.ground_bottom_color = pal.col("terrain_loam").darkened(0.5)
	sky_mat.ground_horizon_color = pal.col("fog_day").lerp(pal.col("fog_night"), n)
	var e: Environment = env.environment
	e.fog_light_color = pal.col("fog_day").lerp(pal.col("fog_night"), n)
	e.fog_density = lerpf(pal.num("fog_density_day"), pal.num("fog_density_night"), n)
	e.volumetric_fog_albedo = e.fog_light_color
	e.volumetric_fog_density = lerpf(0.004, 0.02, n)
	e.ambient_light_energy = lerpf(pal.num("ambient_energy_day"), pal.num("ambient_energy_night"), n)
	sun.light_color = pal.col("sun_day").lerp(pal.col("sun_night"), n)
	sun.light_energy = lerpf(pal.num("sun_energy_day"), pal.num("sun_energy_night"), n)
	# the sun arcs: low at dawn and dusk, high at noon; the moon sits low and still
	var pitch: float
	if night_t > 0.0:
		pitch = pal.num("sun_pitch_night_deg")
	else:
		pitch = -18.0 - (absf(pal.num("sun_pitch_day_deg")) - 18.0) * sin(PI * sun_t)
	var yaw: float = pal.num("sun_yaw_deg") + (sun_t - 0.5) * 70.0
	sun.rotation_degrees = Vector3(pitch, yaw, 0.0)
	sky_mat.sun_angle_max = 22.0
