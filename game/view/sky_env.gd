## Sky, fog, ambient, and the sun, all from the palette, blended by the clock. Day and night are
## two full palettes; the view blends them by one continuous darkness value (see darkness()).
class_name SkyEnv
extends Node3D

var env: WorldEnvironment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var pal: PaletteData
## The climate round the gnome (arctic, desert, jungle), eased so crossing a border is a slow
## change of air, not a cut.
var climate_here: Vector3 = Vector3.ZERO
var attrs: CameraAttributesPractical
var _snow: GPUParticles3D
var _dust: GPUParticles3D
var _spores: GPUParticles3D


## Each frame: where he is (particles follow him) and what climate that is.
func follow(at: Vector3, cl: Vector3, cam_dist: float, delta: float) -> void:
	climate_here = climate_here.lerp(cl, clampf(delta * 0.6, 0.0, 1.0))
	for p: GPUParticles3D in [_snow, _dust, _spores]:
		p.global_position = at + Vector3(0.0, 9.0, 0.0)
	_snow.amount_ratio = clampf(climate_here.x * 1.2 - 0.1, 0.0, 1.0)
	_dust.amount_ratio = clampf(climate_here.y * 1.2 - 0.15, 0.0, 1.0)
	_spores.amount_ratio = clampf(climate_here.z * 1.2 - 0.1, 0.0, 1.0)
	_snow.emitting = _snow.amount_ratio > 0.01
	_dust.emitting = _dust.amount_ratio > 0.01
	_spores.emitting = _spores.amount_ratio > 0.01
	# the miniature look: what is far beyond the gnome softens
	attrs.dof_blur_far_distance = cam_dist + 16.0
	attrs.dof_blur_far_transition = 28.0 + cam_dist


func _particles(col: Color, size: float, count: int, fall: float, spread: float) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28.0, 6.0, 28.0)
	pm.direction = Vector3(0.3, -1.0, 0.1)
	pm.spread = spread
	pm.initial_velocity_min = fall * 0.6
	pm.initial_velocity_max = fall
	pm.gravity = Vector3(0.0, -fall * 0.3, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var q := SphereMesh.new()
	q.radius = size * 0.5
	q.height = size
	q.radial_segments = 6
	q.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.vertex_color_use_as_albedo = true
	q.material = m
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = 7.0
	p.preprocess = 4.0
	p.process_material = pm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-40.0, -30.0, -40.0), Vector3(80.0, 50.0, 80.0))
	p.local_coords = false
	p.emitting = false
	p.amount_ratio = 0.0
	add_child(p)
	return p


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
	attrs = CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 30.0
	attrs.dof_blur_far_transition = 40.0
	attrs.dof_blur_amount = 0.06
	env.camera_attributes = attrs
	add_child(env)
	_snow = _particles(Color(1.0, 1.0, 1.0, 0.9), 0.06, 1100, 2.0, 25.0)
	_dust = _particles(Color(0.95, 0.85, 0.6, 0.45), 0.04, 500, 0.6, 80.0)
	_spores = _particles(Color(0.85, 1.0, 0.6, 0.8), 0.045, 400, 0.3, 180.0)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 140.0
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
	# the climate's own air: pale cold haze, warm dust, green damp
	var cl: Vector3 = climate_here
	var day_fog: Color = pal.col("fog_day").lerp(pal.col("fog_arctic"), cl.x).lerp(pal.col("fog_desert"), cl.y).lerp(pal.col("fog_jungle"), cl.z)
	e.fog_light_color = day_fog.lerp(pal.col("fog_night"), n).lerp(pal.col("sky_horizon_dusk"), glow * 0.3)
	e.fog_density = lerpf(pal.num("fog_density_day") * (1.0 + cl.x * 1.2 + cl.y * 0.6 + cl.z * 1.6), pal.num("fog_density_night"), n)
	sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(day_fog, (cl.x + cl.y + cl.z) * 0.5 * (1.0 - n))
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
