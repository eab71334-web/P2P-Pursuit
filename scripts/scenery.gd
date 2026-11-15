# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name Scenery
extends RefCounted
## Looks of the 3D world: asphalt texture, low-poly peaks and clouds, sun glare. Pure code, no image files.

static var _asphalt: ImageTexture
static var _glare: GradientTexture2D


## grainy asphalt with a few lighter and darker blotches; tiled by world position (triplanar), so every road piece matches
static func road_material(base: Color) -> StandardMaterial3D:
	if _asphalt == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.07
		n.seed = 11
		var fine := FastNoiseLite.new()
		fine.noise_type = FastNoiseLite.TYPE_CELLULAR
		fine.frequency = 0.5
		fine.seed = 5
		var a := n.get_seamless_image(128, 128, false, false)
		var b := fine.get_seamless_image(128, 128, false, false)
		var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
		for y in 128:
			for x in 128:
				var v := 0.84 + 0.12 * (a.get_pixel(x, y).r - 0.5) * 2.0 + 0.08 * (b.get_pixel(x, y).r - 0.5)
				v = clampf(v, 0.55, 1.0)
				img.set_pixel(x, y, Color(v, v, v))
		img.generate_mipmaps()
		_asphalt = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.albedo_texture = _asphalt
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.22, 0.22, 0.22)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 0.92
	return m


static func plain(c: Color, rough := 0.9, fog := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.disable_fog = not fog
	return m


static func emissive(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## a low-poly peak: 5-sided cone, base radius 0.5, height 1, sitting on y = 0
static func peak_mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = 5
	m.rings = 1
	m.cap_bottom = false
	return m


static func tire_mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.45
	m.bottom_radius = 0.45
	m.height = 0.32
	m.radial_segments = 8
	m.rings = 1
	return m


static func cloud_mesh() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 8
	m.rings = 4
	return m


## soft round glow for the sun
static func glare_texture() -> GradientTexture2D:
	if _glare == null:
		var g := Gradient.new()
		g.set_offset(0, 0.0)
		g.set_color(0, Color(1.0, 0.97, 0.85, 0.95))
		g.add_point(0.12, Color(1.0, 0.93, 0.75, 0.7))
		g.add_point(0.4, Color(1.0, 0.85, 0.6, 0.18))
		g.set_offset(g.get_point_count() - 1, 1.0)
		g.set_color(g.get_point_count() - 1, Color(1.0, 0.8, 0.5, 0.0))
		_glare = GradientTexture2D.new()
		_glare.gradient = g
		_glare.fill = GradientTexture2D.FILL_RADIAL
		_glare.fill_from = Vector2(0.5, 0.5)
		_glare.fill_to = Vector2(1.0, 0.5)
		_glare.width = 256
		_glare.height = 256
	return _glare
