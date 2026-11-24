# Cenário de teste: chão 30x30, plataforma de 2 m com rampa e 3 caixas.
# Uso: blender -b -P teste/gerar_teste.py -- teste/teste.glb
import sys

import bmesh
import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)


def peca(nome, verts, faces, cor):
    me = bpy.data.meshes.new(nome)
    me.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    mat = bpy.data.materials.new(nome)
    if hasattr(mat, "use_nodes") and not mat.use_nodes:
        mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None) or nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Base Color"].default_value = (*cor, 1)
    me.materials.append(mat)
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)


def caixa(nome, x0, x1, y0, y1, z0, z1, cor):
    v = [(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    peca(nome, v, f, cor)


caixa("chao", -15, 15, -15, 15, -0.2, 0, (0.35, 0.42, 0.3))
caixa("plataforma", 6, 12, -3, 3, 0, 2, (0.45, 0.45, 0.55))
peca("rampa",
     [(2, -3, 0), (6, -3, 0), (6, -3, 2), (2, 3, 0), (6, 3, 0), (6, 3, 2)],
     [(0, 1, 4, 3), (0, 3, 5, 2), (1, 2, 5, 4), (0, 2, 1), (3, 4, 5)],
     (0.55, 0.5, 0.4))
caixa("caixa1", -10, -8, 6, 8, 0, 1.5, (0.6, 0.4, 0.25))
caixa("caixa2", -2, 0, -10, -8, 0, 1, (0.6, 0.4, 0.25))
caixa("caixa3", 10, 12, 8, 10, 0, 3, (0.6, 0.4, 0.25))
# caminho de terra (fino, acima do chão pra não piscar)
caixa("caminho", -15, 15, -1.2, 1.2, 0, 0.02, (0.3, 0.24, 0.17))


def casa(nome, x0, x1, y0, y1, h):
    caixa(nome, x0, x1, y0, y1, 0, h, (0.42, 0.33, 0.24))
    xm = (x0 + x1) / 2
    peca(nome + "_telhado",
         [(x0 - 0.3, y0 - 0.3, h), (x1 + 0.3, y0 - 0.3, h), (xm, y0 - 0.3, h + 1.6),
          (x0 - 0.3, y1 + 0.3, h), (x1 + 0.3, y1 + 0.3, h), (xm, y1 + 0.3, h + 1.6)],
         [(0, 1, 4, 3), (0, 3, 5, 2), (1, 2, 5, 4), (0, 2, 1), (3, 4, 5)],
         (0.22, 0.17, 0.12))


casa("casa1", -12, -8, 8, 12, 2.4)
casa("casa2", 2, 6, 10, 13, 2.2)


def arvore(nome, x, y):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.25, radius2=0.2, depth=2.0)
    bmesh.ops.translate(bm, vec=(x, y, 1.0), verts=bm.verts)
    v = [tuple(vv.co) for vv in bm.verts]
    f = [tuple(vv.index for vv in ff.verts) for ff in bm.faces]
    bm.free()
    peca(nome + "_tronco", v, f, (0.25, 0.17, 0.1))
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=1.6, radius2=0.0, depth=3.5)
    bmesh.ops.translate(bm, vec=(x, y, 3.6), verts=bm.verts)
    v = [tuple(vv.co) for vv in bm.verts]
    f = [tuple(vv.index for vv in ff.verts) for ff in bm.faces]
    bm.free()
    peca(nome + "_copa", v, f, (0.12, 0.25, 0.15))


for i, (x, y) in enumerate([(-12, -4), (13, -5), (8, -12), (-6, -12), (-13, 12), (13, 12)]):
    arvore("arvore%d" % i, x, y)

bpy.ops.export_scene.gltf(filepath=sys.argv[sys.argv.index("--") + 1], export_format="GLB")

# o programa abre o que o Godot importou: importa de novo, senão ele continua abrindo a versão velha
import os
import subprocess
subprocess.run(["godot", "--headless", "--path", os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[sys.argv.index("--") + 1]))), "--import"], check=False)
