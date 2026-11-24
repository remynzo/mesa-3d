# Faz o "cartão de ramo" dos pinheiros, do jeito dos jogos: corta uma fatia de um abeto do Poly Haven
# (agulhas 3D, milhões de triângulos), deita ela e fotografa de cima com fundo transparente.
# O cenário monta cada pinheiro com tronco 3D e centenas de cartões dessa foto.
# Uso (uma vez): blender -b -P cenarios/foto_arvores.py
# Sai: assets/arvores/ramo.png e assets/arvores/medidas.json (comprimento e largura do ramo em metros).
import json
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

PH = os.path.expanduser("~/Projects/tabletop/assets/polyhaven")
OUT = os.path.expanduser("~/Projects/tabletop/assets/arvores")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
cena = bpy.context.scene
cena.render.engine = "BLENDER_EEVEE"
cena.render.film_transparent = True
cena.render.image_settings.file_format = "PNG"
cena.render.image_settings.color_mode = "RGBA"
cena.view_settings.view_transform = "Standard"
# luz quase por igual (quem ilumina de verdade depois é a mesa) e um sol fraco pra dar volume
mundo = bpy.data.worlds.new("w")
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
mundo.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
cena.world = mundo
sol = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
sol.data.energy = 2.0
sol.rotation_euler = (0.5, 0.3, 0)
cena.collection.objects.link(sol)

bpy.ops.import_scene.gltf(filepath=os.path.join(PH, "fir_tree_01", "fir_tree_01.gltf"))
o = next(x for x in bpy.data.objects if x.name.startswith("fir_tree_01_c"))   # o mais leve
for x in list(bpy.data.objects):
    if x.type == "MESH" and x is not o:
        bpy.data.objects.remove(x)
me = o.data
me.transform(o.matrix_world)
o.matrix_world = Matrix()
c = np.empty(len(me.polygons) * 3, np.float32)
me.polygons.foreach_get("center", c)
c = c.reshape(-1, 3)
z0, z1 = c[:, 2].min(), c[:, 2].max()
eixo = c[c[:, 2] < z0 + 0.5, :2].mean(axis=0)   # pé do tronco
d = c[:, :2] - eixo
r = np.hypot(d[:, 0], d[:, 1])
ang = np.arctan2(d[:, 1], d[:, 0])
# fatia: o gomo de 24° × 1,3 m de altura com mais agulhas (fora do tronco)
mat = np.empty(len(me.polygons), np.int32)
me.polygons.foreach_get("material_index", mat)
twig = np.isin(mat, [i for i, s in enumerate(o.material_slots) if "twig" in s.material.name]) & (r > 0.4)
hz = np.floor((c[twig, 2] - z0) / 1.3).astype(int)
ha = np.floor((ang[twig] + math.pi) / math.radians(24)).astype(int)
cont = np.zeros((hz.max() + 1, ha.max() + 1), int)
np.add.at(cont, (hz, ha), 1)
bz, ba = np.unravel_index(cont.argmax(), cont.shape)
ALT, AZ = z0 + bz * 1.3, -math.pi + (ba + 0.5) * math.radians(24)
az = np.angle(np.exp(1j * (ang - AZ)))
fica = (np.abs(az) < math.radians(12)) & (r > 0.15) & (c[:, 2] > ALT) & (c[:, 2] < ALT + 1.3)
bm = bmesh.new()
bm.from_mesh(me)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[f for f, k in zip(bm.faces, fica) if not k], context="FACES")
# deita o ramo apontando pro +X, com o tronco na origem
bmesh.ops.transform(bm, matrix=Matrix.Rotation(-AZ, 4, "Z") @ Matrix.Translation((-eixo[0], -eixo[1], -ALT)), verts=bm.verts)
bm.to_mesh(me)
bm.free()
lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
comp, larg = hi.x * 1.02, max(-lo.y, hi.y) * 2.04   # começa no tronco (x=0), centrado em y
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cena.collection.objects.link(cam)
cena.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = max(comp, larg)
cam.location = (comp / 2, 0, 30)   # de cima, olhando pra baixo
cena.render.resolution_x = round(1024 * comp / max(comp, larg))
cena.render.resolution_y = round(1024 * larg / max(comp, larg))
cena.render.filepath = os.path.join(OUT, "ramo.png")
bpy.ops.render.render(write_still=True)

# De longe o jogo usa a textura reduzida, onde agulha fina vira meio-transparente e o recorte (0,5)
# joga fora: a copa fica vazada. Engrossa as agulhas 1 px e pinta o fundo transparente com a cor
# vizinha, pra a redução não escurecer as bordas.
img = bpy.data.images.load(cena.render.filepath)
W, Hh = img.size
px = np.empty(W * Hh * 4, np.float32)
img.pixels.foreach_get(px)
px = px.reshape(Hh, W, 4)


def vizinhos(a, f):
    out = a.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            out = f(out, np.roll(np.roll(a, dy, 0), dx, 1))
    return out


alfa = vizinhos((px[..., 3] > 0.35).astype(np.float32), np.maximum)
cor, peso = px[..., :3] * px[..., 3:], px[..., 3:].copy()
for _ in range(12):   # espalha a cor das agulhas pelo fundo
    cor, peso = vizinhos(cor, np.add) / 9, vizinhos(peso, np.add) / 9
fundo = cor / np.maximum(peso, 1e-4)
px[..., :3] = np.where(px[..., 3:] > 0.35, px[..., :3], fundo)
px[..., 3] = alfa
img.pixels.foreach_set(np.clip(px, 0, 1).ravel())
img.save()
json.dump({"comprimento": comp, "largura": larg}, open(os.path.join(OUT, "medidas.json"), "w"), indent=1)
print("RAMO", cont.max(), "agulhas no melhor gomo,", round(comp, 2), round(larg, 2), len(me.polygons), "faces")
