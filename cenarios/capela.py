# Cenário "Capela abandonada", versão realista: texturas e modelos escaneados do Poly Haven (CC0)
# em assets/polyhaven/. Capela de pedra com campanário, muro de pedra rústico, cemitério no mato alto,
# cabana com varanda, poço e círculo de pedras numa clareira de floresta.
# Objetos "deco_*" (mato, samambaia, galhos) o programa junta em lotes e não ganham colisão.
# Uso: blender -b -P cenarios/capela.py -- <pasta de saída>
# Sai: capela.glb e capela_mesa.json (luzes, efeitos, personagens e névoa já postos).
import json
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector, noise

OUT = sys.argv[sys.argv.index("--") + 1]
PH = os.path.expanduser("~/Projects/tabletop/assets/polyhaven")
random.seed(7)
bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------- materiais ----------

def novo_material(nome):
    mat = bpy.data.materials.new(nome)
    if hasattr(mat, "use_nodes") and not mat.use_nodes:
        mat.use_nodes = True
    return mat, mat.node_tree, next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def imagem(caminho, lado):
    img = bpy.data.images.load(caminho)
    if img.size[0] > lado:
        img.scale(lado, lado)
    return img


def pbr(nome, pasta, lado=1024, tom=None):
    mat, nt, bsdf = novo_material(nome)
    d = os.path.join(PH, pasta)
    cor = nt.nodes.new("ShaderNodeTexImage")
    cor.image = imagem(os.path.join(d, "cor.jpg"), lado)
    if tom:   # tinge a própria imagem (o glTF não leva nó de mistura)
        px = np.empty(len(cor.image.pixels), np.float32)
        cor.image.pixels.foreach_get(px)
        px = px.reshape(-1, 4)
        px[:, :3] *= np.array(tom, np.float32)
        cor.image.pixels.foreach_set(px.ravel())
        cor.image.pack()
    nt.links.new(cor.outputs["Color"], bsdf.inputs["Base Color"])
    rug = nt.nodes.new("ShaderNodeTexImage")
    rug.image = imagem(os.path.join(d, "rugosidade.jpg"), lado)
    rug.image.colorspace_settings.name = "Non-Color"
    nt.links.new(rug.outputs["Color"], bsdf.inputs["Roughness"])
    nor = nt.nodes.new("ShaderNodeTexImage")
    nor.image = imagem(os.path.join(d, "normal.jpg"), lado)
    nor.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nor.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def liso(nome, cor, rough=0.9, emissao=None, forca=0.0, metal=0.0):
    mat, nt, bsdf = novo_material(nome)
    bsdf.inputs["Base Color"].default_value = (*cor, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emissao:
        bsdf.inputs["Emission Color"].default_value = (*emissao, 1)
        bsdf.inputs["Emission Strength"].default_value = forca
    return mat


# miolo escuro dentro da copa dos pinheiros: ruído gerado aqui
def tex_folha():
    n = 512
    rng = np.random.default_rng(15)
    g = rng.random((16, 16))
    t = np.arange(n) * 16 / n
    i0 = np.floor(t).astype(int)
    f = t - i0
    v = g[np.ix_(i0, i0)] * (1 - f[None, :]) + g[np.ix_(i0, (i0 + 1) % 16)] * f[None, :]
    v = v * (0.7 + 0.3 * rng.random((n, n)))
    c = np.stack([0.05 + 0.06 * v, 0.09 + 0.09 * v, 0.06 + 0.05 * v, np.ones_like(v)], axis=2).astype(np.float32)
    img = bpy.data.images.new("folha", n, n)
    img.pixels.foreach_set(c.ravel())
    img.pack()
    mat, nt, bsdf = novo_material("folha")
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = img
    nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return mat


# material -> metros por repetição da textura
MATS = {
    "parede": (pbr("parede", "rustic_stone_wall_02", 2048), 2.6),
    "muro": (pbr("muro", "mossy_stone_wall", 1024), 2.2),
    "telhado": (pbr("telhado", "roof_slates_02", 2048), 2.4),
    "chao": (pbr("chao", "forest_ground_04", 2048, (0.62, 0.72, 0.5)), 3.5),
    "lama": (pbr("lama", "brown_mud_leaves_01", 1024), 2.5),
    "tabua": (pbr("tabua", "weathered_planks", 1024), 2.0),
    "tabua_escura": (pbr("tabua_escura", "dark_wooden_planks", 1024), 1.8),
    "casca": (pbr("casca", "pine_bark", 1024), 1.4),
    "rocha": (pbr("rocha", "mossy_rock", 1024), 1.8),
    "folha": (tex_folha(), 3.0),
    "breu": (liso("breu", (0.012, 0.01, 0.01), 1.0), 1.0),
    "vela": (liso("vela", (0.9, 0.85, 0.7), 0.5, (1.0, 0.65, 0.3), 5.0), 1.0),
    "ferro": (liso("ferro", (0.06, 0.06, 0.065), 0.5, metal=0.8), 1.0),
    "bronze": (liso("bronze", (0.3, 0.22, 0.1), 0.45, metal=0.9), 1.0),
    "agua": (liso("agua", (0.01, 0.014, 0.016), 0.04), 1.0),
    "tapete": (liso("tapete", (0.22, 0.03, 0.03), 1.0), 1.0),
    "janela": (liso("janela", (0.05, 0.03, 0.02), 0.6, (1.0, 0.45, 0.12), 0.6), 1.0),
}

# ---------- geometria própria: tudo de um material vira um objeto ----------

LOTES = {}


def junta(mat, bm):
    escala = MATS[mat][1]
    uv = bm.loops.layers.uv.verify()
    bm.normal_update()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for lp in f.loops:
            p = lp.vert.co
            u, v = (p.x, p.y) if ax == 2 else (p.y, p.z) if ax == 0 else (p.x, p.z)
            lp[uv].uv = (u / escala, v / escala)
    me = bpy.data.meshes.new("tmp")
    bm.to_mesh(me)
    bm.free()
    LOTES.setdefault(mat, bmesh.new()).from_mesh(me)
    bpy.data.meshes.remove(me)


def M(pos=(0, 0, 0), rot=(0, 0, 0), esc=(1, 1, 1)):
    return Matrix.Translation(pos) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*esc, 1))


def caixa(mat, centro, tam, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.transform(bm, matrix=M(centro, rot, tam), verts=bm.verts)
    junta(mat, bm)


def bloco(mat, centro, tam, rot=(0, 0, 0), amp=0.05, freq=2.5, cortes=6, arredonda=0.0, seed=0.0):
    # caixa subdividida e amassada por ruído: pedra irregular, muro rústico, menir
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cortes, use_grid_fill=True)
    if arredonda:
        for v in bm.verts:   # topo arredondado (muro de pedra seca)
            if v.co.z > 0.1:
                v.co.y *= 1 - arredonda * ((v.co.z - 0.1) / 0.4) ** 2
    bmesh.ops.transform(bm, matrix=M((0, 0, 0), (0, 0, 0), tam), verts=bm.verts)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * amp * noise.noise(v.co * freq + Vector((seed, seed * 0.7, seed * 1.3)))
    bmesh.ops.transform(bm, matrix=M(centro, rot), verts=bm.verts)
    junta(mat, bm)


def cilindro(mat, base, r1, r2, h, seg=12, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h)
    bmesh.ops.translate(bm, vec=(0, 0, h / 2), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=M(base, rot), verts=bm.verts)
    junta(mat, bm)


def anel(mat, centro, r, esp, rot, seg=24):
    bm = bmesh.new()
    aneis = []
    for i in range(seg):
        a = i * math.tau / seg
        c = Vector((math.cos(a) * r, 0, math.sin(a) * r))
        out = c.normalized()
        aneis.append([bm.verts.new(c + (out * math.cos(b) + Vector((0, 1, 0)) * math.sin(b)) * esp) for b in [k * math.tau / 6 for k in range(6)]])
    for i in range(seg):
        for k in range(6):
            bm.faces.new((aneis[i][k], aneis[(i + 1) % seg][k], aneis[(i + 1) % seg][(k + 1) % 6], aneis[i][(k + 1) % 6]))
    bmesh.ops.transform(bm, matrix=M(centro, rot), verts=bm.verts)
    junta(mat, bm)


def oitao(mat, x0, x1, y, z, h, esp):
    bm = bmesh.new()
    xm = (x0 + x1) / 2
    vs = [bm.verts.new(p) for p in [(x0, y - esp / 2, z), (x1, y - esp / 2, z), (xm, y - esp / 2, z + h),
                                    (x0, y + esp / 2, z), (x1, y + esp / 2, z), (xm, y + esp / 2, z + h)]]
    for f in [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    junta(mat, bm)


def telhado(mat, x0, x1, y0, y1, z, h, beiral=0.35, esp=0.2, buracos=()):
    xm = (x0 + x1) / 2
    meia = (x1 - x0) / 2 + beiral
    ang = math.atan2(h, meia)
    comp = math.hypot(meia, h) + 0.1
    for lado in (-1, 1):
        trechos = [(y0 - beiral, y1 + beiral)]
        if lado == 1:
            for b0, b1 in buracos:
                trechos = [t for a, b in trechos for t in ((a, b0), (b1, b)) if t[1] - t[0] > 0.1]
        for a, b in trechos:
            caixa(mat, (xm + lado * meia / 2, (a + b) / 2, z + h / 2 - beiral * math.tan(ang) / 2), (comp, b - a, esp), (0, lado * ang, 0))
    caixa(mat, (xm, (y0 + y1) / 2, z + h + 0.05), (0.3, y1 - y0 + 2 * beiral, 0.2))   # cumeeira


# ---------- terreno ----------

def altura(x, y):
    r = math.hypot(x, y - 2)
    # perto sobe como antes, depois vira um planalto de floresta (~6 m) e só sobe de novo na borda, pra esconder o fim
    morro = 6.5 * (1 - math.exp(-max(0.0, r - 16) / 8)) + 0.1 * max(0.0, r - 42) ** 1.5
    ondas = 0.22 * math.sin(x * 0.31 + 1.3) * math.cos(y * 0.27) + 0.12 * math.sin(x * 0.7 + y * 0.5)
    return morro + ondas * min(1.0, max(0.0, r - 9) / 8) + 0.05 * noise.noise(Vector((x * 0.6, y * 0.6, 0)))


bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=260, y_segments=260, size=50)   # 100 × 100 m
for v in bm.verts:
    v.co.z = altura(v.co.x, v.co.y)
junta("chao", bm)

CAMINHO = []   # pontos das trilhas, pra não nascer mato em cima


def trilha(pontos, larg=2.0):
    pts = [Vector(p) for p in pontos]
    amostras = []
    for i in range(len(pts) - 1):
        p0, p1 = pts[max(i - 1, 0)], pts[i]
        p2, p3 = pts[i + 1], pts[min(i + 2, len(pts) - 1)]
        passos = max(2, int((p2 - p1).length / 0.4))
        for k in range(passos):
            t = k / passos
            amostras.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    amostras.append(pts[-1])
    bm = bmesh.new()
    ant = None
    for i, p in enumerate(amostras):
        CAMINHO.append((p.x, p.y, larg / 2))
        d = (amostras[min(i + 1, len(amostras) - 1)] - amostras[max(i - 1, 0)]).normalized()
        w = larg / 2 * (0.9 + 0.25 * noise.noise(Vector((p.x * 0.5, p.y * 0.5, 3))))
        lado = Vector((-d.y, d.x))
        linha = []
        for k in range(5):   # 5 vértices na largura, colados no chão
            s = -1 + k * 0.5
            q = p + lado * w * s
            linha.append(bm.verts.new((q.x, q.y, altura(q.x, q.y) + 0.035 - 0.02 * abs(s))))
        if ant:
            for k in range(4):
                bm.faces.new((ant[k], ant[k + 1], linha[k + 1], linha[k]))
        ant = linha
    junta("lama", bm)


trilha([(0, -47), (1.4, -37), (0, -26), (0.6, -17), (-0.6, -9), (0, -3)], 2.2)
trilha([(0, 1), (0, 3.5), (0, 5.4)], 1.8)
trilha([(-1.5, -3), (-5, -5.5), (-9.0, -6.8)], 1.4)
trilha([(1.5, 0.5), (4, 3.5), (5.6, 10.5), (7.0, 11)], 1.3)
trilha([(1.5, -2.5), (5, -5.5), (7.6, -7.2)], 1.2)
bm = bmesh.new()   # terreiro do poço
bmesh.ops.create_circle(bm, cap_ends=True, segments=28, radius=3.2)
for v in bm.verts:
    v.co.y -= 1
    v.co.z = altura(v.co.x, v.co.y) + 0.04
junta("lama", bm)
CAMINHO.append((0, -1, 3.4))

LIVRE = []   # retângulos sem mato: (x0, y0, x1, y1)

# ---------- capela (como a da referência: nave única, campanário de parede, quinas de pedra) ----------
X0, X1, Y0, Y1, H, E = -3.2, 3.2, 6, 15, 3.8, 0.6
LIVRE.append((X0 - 0.4, Y0 - 1.2, X1 + 0.4, Y1 + 0.4))
for x in (X0, X1):   # laterais com duas janelas estreitas cada
    cortes = [Y0, 8.6, 9.2, 12.0, 12.6, Y1]
    for a, b in zip(cortes[::2], cortes[1::2]):
        caixa("parede", (x, (a + b) / 2, H / 2), (E, b - a, H))
    for a, b in zip(cortes[1::2], cortes[2::2]):
        caixa("parede", (x, (a + b) / 2, 0.6), (E, b - a, 1.2))
        caixa("parede", (x, (a + b) / 2, 3.25), (E, b - a, 1.1))
        caixa("janela", (x, (a + b) / 2, 1.95), (0.1, b - a, 1.5))
# frente: porta no meio e duas janelinhas, como na foto
caixa("parede", (-2.25, Y0, H / 2), (2.4, E, H))
caixa("parede", (2.25, Y0, H / 2), (2.4, E, H))
caixa("parede", (0, Y0, 3.2), (2.0, E, 1.2))
for x in (-2.2, 2.2):
    caixa("breu", (x, Y0 - 0.02, 1.75), (0.45, E + 0.02, 1.4))
caixa("tabua_escura", (-0.45, Y0 - 0.12, 1.3), (0.88, 0.09, 2.6))
caixa("tabua_escura", (0.55, Y0 - 0.45, 1.3), (0.88, 0.09, 2.6), (0, 0, -0.75))   # folha entreaberta
caixa("breu", (0.2, Y0 + 0.05, 1.3), (0.9, 0.4, 2.6))
caixa("parede", (0, Y0 - 0.05, 2.68), (2.1, E + 0.14, 0.18))   # verga
caixa("parede", (0, Y1, H / 2), (X1 - X0 + E, E, H))
oitao("parede", X0 - E / 2, X1 + E / 2, Y0, H, 3.0, E)
oitao("parede", X0 - E / 2, X1 + E / 2, Y1, H, 3.0, E)
for x in (X0, X1):   # quinas salientes
    for y in (Y0, Y1):
        bloco("parede", (x + 0.06 * (1 if x > 0 else -1), y, H / 2), (E + 0.25, E + 0.25, H), amp=0.03, cortes=3)
# campanário de parede: pilar acima do frontão com vão do sino e chapéu de telha
caixa("parede", (0, Y0, 6.4), (1.9, E, 1.4))
for x in (-0.75, 0.75):
    caixa("parede", (x, Y0, 7.85), (0.4, E, 1.5))
caixa("parede", (0, Y0, 8.75), (1.9, E, 0.3))
oitao("parede", -0.95, 0.95, Y0, 8.9, 0.7, E)
telhado("telhado", -0.95, 0.95, Y0 - 0.3, Y0 + 0.3, 8.9, 0.7, 0.15, 0.12)
cilindro("bronze", (0, Y0, 7.3), 0.32, 0.14, 0.55, 16)
telhado("telhado", X0 - E / 2, X1 + E / 2, Y0 - 0.1, Y1 + 0.1, H, 3.0, buracos=[(11.0, 13.4)])
for i, (y, rz) in enumerate([(11.4, 0.3), (12.6, -0.4)]):   # vigas que caíram pelo buraco
    caixa("tabua_escura", (1.3 + i * 0.3, y, 0.3 + i * 0.12), (3.0, 0.2, 0.2), (0.15 * i, 0.3, rz))
for i in range(6):
    bloco("telhado", (random.uniform(0.6, 2.6), random.uniform(11, 13.4), 0.08), (random.uniform(0.3, 0.6), random.uniform(0.25, 0.5), 0.05), (0, 0, random.uniform(0, 3)), amp=0.01, cortes=1)
# dentro: piso, bancos, tapete, altar com velas e cruz
caixa("parede", (0, (Y0 + Y1) / 2, 0.03), (X1 - X0, Y1 - Y0, 0.06))
caixa("tapete", (0, 10.0, 0.07), (1.1, 6.5, 0.02))
for fila in range(4):
    for lado in (-1, 1):
        y = 7.6 + fila * 1.5
        tomb = fila == 2 and lado == 1
        rot = (1.35, 0, 0.2) if tomb else (0, 0, random.uniform(-0.05, 0.05))
        caixa("tabua", (lado * 1.65, y, 0.25 if tomb else 0.46), (1.9, 0.42, 0.06), rot)
        if not tomb:
            caixa("tabua", (lado * 1.65, y + 0.22, 0.78), (1.9, 0.05, 0.55))
            for px in (-0.85, 0.85):
                caixa("tabua", (lado * 1.65 + px, y, 0.23), (0.06, 0.38, 0.46))
caixa("parede", (0, 13.9, 0.15), (4, 1.6, 0.3))
bloco("rocha", (0, 14.0, 0.75), (1.8, 0.8, 0.9), amp=0.03, cortes=3)
for i, x in enumerate([-0.6, -0.35, 0.3, 0.65]):
    cilindro("vela", (x, 13.9, 1.2), 0.035, 0.035, 0.18 + 0.12 * (i % 2), 8)
caixa("tabua_escura", (0, 14.6, 2.2), (0.15, 0.12, 2.0))
caixa("tabua_escura", (0, 14.6, 2.65), (1.0, 0.12, 0.15))
bloco("parede", (0, Y0 - 0.75, 0.1), (2.6, 1.0, 0.2), amp=0.02, cortes=2)   # degrau

# ---------- muro rústico de pedra seca (frente da capela e cemitério) ----------


def muro(p0, p1, h=0.85, esp=0.6, seed=0.0):
    a, b = Vector(p0), Vector(p1)
    d = b - a
    n = max(1, int(d.length / 2.5))
    for k in range(n):
        c = a + d * ((k + 0.5) / n)
        z = altura(c.x, c.y)
        bloco("muro", (c.x, c.y, z + h / 2 - 0.08), (d.length / n + 0.15, esp, h), (0, 0, math.atan2(d.y, d.x)),
              amp=0.07, freq=1.8, cortes=8, arredonda=0.55, seed=seed + k * 3.1)
    LIVRE.append((min(a.x, b.x) - esp / 2, min(a.y, b.y) - esp / 2, max(a.x, b.x) + esp / 2, max(a.y, b.y) + esp / 2))


muro((-7, 3.6), (-1.3, 3.6), seed=1)
muro((1.3, 3.6), (6.2, 3.6), seed=2)
muro((-7, 3.6), (-7, 9), seed=3)
# cruz celta na quina do muro (como na foto)
CC = (-5.4, 4.6)
zc = altura(*CC)
bloco("rocha", (CC[0], CC[1], zc + 0.35), (0.9, 0.7, 0.7), amp=0.03, cortes=3)
bloco("rocha", (CC[0], CC[1], zc + 1.45), (0.22, 0.16, 1.6), amp=0.012, cortes=3)
bloco("rocha", (CC[0], CC[1], zc + 1.95), (0.85, 0.16, 0.2), amp=0.012, cortes=3)
anel("rocha", (CC[0], CC[1], zc + 1.95), 0.27, 0.05, (0, 0, 0))

# ---------- cemitério (leste) ----------
CX0, CX1, CY0, CY1 = 7.5, 17.5, 3.5, 17
muro((CX0, CY0), (CX1, CY0), seed=10)
muro((CX1, CY0), (CX1, CY1), seed=11)
muro((CX0, CY1), (CX1, CY1), seed=12)
muro((CX0, CY0), (CX0, 10.0), seed=13)
muro((CX0, 12.0), (CX0, CY1), seed=14)
for y in (10.0, 12.0):
    bloco("muro", (CX0, y, altura(CX0, y) + 0.7), (0.7, 0.7, 1.5), amp=0.05, cortes=4, seed=y)
caixa("ferro", (CX0 + 0.35, 10.7, altura(CX0, 10.7) + 0.7), (0.04, 1.1, 1.2), (0, 0, 0.9))
rng = random.Random(3)
TUMULOS = []
for i in range(4):
    for j in range(4):
        if (i, j) in ((3, 3), (3, 2)):
            continue
        x = 9.6 + i * 2.0 + rng.uniform(-0.35, 0.35)
        y = 5.4 + j * 2.7 + rng.uniform(-0.35, 0.35)
        z = altura(x, y)
        incl = (rng.uniform(-0.22, 0.22), rng.uniform(-0.12, 0.12), rng.uniform(-0.25, 0.25))
        TUMULOS.append((x, y))
        if rng.random() < 0.3:
            bloco("rocha", (x, y, z + 0.55), (0.13, 0.12, 1.1), incl, amp=0.01, cortes=2)
            bloco("rocha", (x, y, z + 0.8), (0.55, 0.12, 0.12), incl, amp=0.01, cortes=2)
        else:
            bloco("rocha", (x, y, z + 0.38), (0.6, 0.15, 0.75), incl, amp=0.015, cortes=3)
            cilindro("rocha", (x, y - 0.075, z + 0.75), 0.3, 0.3, 0.15, 14, (math.pi / 2 + incl[0], incl[1], incl[2]))
        bloco("lama", (x, y - 1.1, z + 0.02), (0.85, 1.7, 0.18), amp=0.04, cortes=3)
# mausoléu
caixa("parede", (15.6, 15.3, 1.4), (2.6, 2.6, 2.8))
caixa("breu", (15.6, 13.98, 1.0), (0.9, 0.06, 2.0))
oitao("parede", 14.3, 16.9, 14.0, 2.8, 1.0, 0.3)
telhado("telhado", 14.3, 16.9, 14.0, 16.6, 2.8, 1.0, 0.2, 0.15)
LIVRE.append((14.0, 13.6, 17.2, 17.0))

# ---------- poço ----------
PX, PY = 0, -1
z = altura(PX, PY)
for i in range(14):   # anel de pedras irregulares
    a = i * math.tau / 14
    bloco("muro", (PX + math.cos(a) * 0.95, PY + math.sin(a) * 0.95, z + 0.42), (0.55, 0.38, 0.85), (0, 0, a + math.pi / 2), amp=0.04, cortes=3, seed=i)
cilindro("agua", (PX, PY, z + 0.6), 0.8, 0.8, 0.01, 20)
for dx in (-1.05, 1.05):
    caixa("tabua_escura", (PX + dx, PY, z + 1.3), (0.13, 0.13, 1.8))
caixa("tabua_escura", (PX, PY, z + 1.9), (2.3, 0.1, 0.1))
telhado("tabua", PX - 1.2, PX + 1.2, PY - 0.7, PY + 0.7, z + 2.1, 0.7, 0.15, 0.06)

# ---------- cabana com varanda (sudoeste, clima da segunda referência) ----------
CAB = Matrix.Translation((-12.5, -7.0, altura(-12.5, -7.0))) @ Matrix.Rotation(0.25, 4, "Z")
LIVRE.append((-16.0, -11.6, -9.0, -3.0))


def cab(mat, centro, tam, rot=(0, 0, 0)):
    caixa(mat, CAB @ Vector(centro), tam, (rot[0], rot[1], rot[2] + 0.25))


for x in (-2.5, 2.5):
    cab("tabua", (x, 0, 1.3), (0.2, 4, 2.6))
cab("tabua", (0, 2, 1.3), (5, 0.2, 2.6))
cab("tabua", (-1.6, -2, 1.3), (1.8, 0.2, 2.6))
cab("tabua", (1.9, -2, 1.3), (1.2, 0.2, 2.6))
cab("tabua", (0.6, -2, 0.45), (1.4, 0.2, 0.9))
cab("tabua", (0.6, -2, 2.25), (1.4, 0.2, 0.7))
cab("janela", (0.6, -2.02, 1.4), (1.3, 0.08, 1.0))
cab("tabua", (-0.3, -2, 2.4), (0.9, 0.2, 0.4))
cab("tabua_escura", (-0.3, -2.05, 1.1), (0.9, 0.08, 2.2))
cab("tabua", (0, -3.0, 0.12), (5.6, 1.9, 0.14))
for x in (-2.6, 2.6):   # postes de tronco da varanda
    p = CAB @ Vector((x, -3.8, 0))
    cilindro("casca", (p.x, p.y, p.z), 0.11, 0.09, 2.5, 8)
for lado in (-1, 1):   # telhado de tábua, descendo até a varanda na frente
    ang = math.atan2(1.4, 3.0)
    p = CAB @ Vector((lado * 1.5, -0.9, 3.25))
    caixa("tabua_escura", p, (3.3, 6.2, 0.1), (0, lado * ang, 0.25))
for y in (-2, 2):
    bm = bmesh.new()
    vs = [bm.verts.new(CAB @ Vector(p)) for p in [(-2.6, y, 2.6), (2.6, y, 2.6), (0, y, 3.95)]]
    bm.faces.new(vs)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.2)
    junta("tabua", bm)
p = CAB @ Vector((1.8, 1.2, 0))
bloco("muro", (p.x, p.y, p.z + 2.5), (0.75, 0.75, 5.0), amp=0.04, cortes=5)
for i in range(11):   # cerca quebrada
    if i in (4, 7):
        continue
    p = CAB @ Vector((-5 + i, -6.2, 0))
    tomb = i == 9
    caixa("casca", (p.x, p.y, p.z + (0.25 if tomb else 0.55)), (0.1, 0.1, 1.1), (1.2 if tomb else rng.uniform(-0.1, 0.1), 0, 0))
for i in range(0, 10, 2):
    if i in (4, 6):
        continue
    p = CAB @ Vector((-4.5 + i, -6.2, 0.75))
    caixa("tabua", p, (2.0, 0.05, 0.11), (0, 0.06 * (i % 3), 0.25))

# ---------- círculo de pedras (sudeste) ----------
SX, SY = 10, -8
LIVRE.append((SX - 1.2, SY - 1.0, SX + 1.2, SY + 1.0))
for i in range(8):
    a = i * math.tau / 8
    x, y = SX + math.cos(a) * 3.6, SY + math.sin(a) * 3.6
    h = 1.8 + (i * 37 % 9) / 10
    bloco("rocha", (x, y, altura(x, y) + h / 2 - 0.25), (0.75, 0.5, h), (random.uniform(-0.12, 0.12), random.uniform(-0.12, 0.12), a + math.pi / 2),
          amp=0.09, freq=1.6, cortes=6, seed=i * 2.3)
    LIVRE.append((x - 0.5, y - 0.5, x + 0.5, y + 0.5))
bloco("rocha", (SX, SY, altura(SX, SY) + 0.3), (1.8, 1.0, 0.6), (0, 0, 0.4), amp=0.05, cortes=4)

# ---------- floresta de fundo e árvores secas ----------


def pinheiro(x, y, s, seed):
    z = altura(x, y) - 0.2
    cilindro("casca", (x, y, z), 0.28 * s, 0.14 * s, 3.2 * s, 8)
    for k in range(4):   # camadas tortas, não cones perfeitos
        bm = bmesh.new()
        r = (2.4 - k * 0.5) * s
        bmesh.ops.create_cone(bm, cap_ends=True, segments=11, radius1=r, radius2=0.0, depth=(2.6 - k * 0.3) * s)
        for v in bm.verts:
            if v.co.z < 0:
                f = 1 + 0.28 * noise.noise(Vector((v.co.x * 2 + seed, v.co.y * 2, k)))
                v.co.x *= f
                v.co.y *= f
                v.co.z -= 0.35 * s * abs(noise.noise(Vector((v.co.x + seed, v.co.y, 9))))
        bmesh.ops.transform(bm, matrix=M((x, y, z + (2.3 + k * 1.45) * s), (0, 0, seed + k)), verts=bm.verts)
        junta("folha", bm)


def galho(x, y, z, comp, ang, incl, r, prof):
    d = Vector((math.sin(incl) * math.cos(ang), math.sin(incl) * math.sin(ang), math.cos(incl)))
    rot = Vector((0, 0, 1)).rotation_difference(d).to_euler()
    cilindro("casca", (x, y, z), r, r * 0.6, comp, 7, tuple(rot))
    fim = Vector((x, y, z)) + d * comp
    if prof > 0:
        for k in range(2 + prof % 2):
            galho(fim.x, fim.y, fim.z, comp * 0.62, ang + random.uniform(-1.4, 1.4), incl + random.uniform(0.3, 0.8), r * 0.6, prof - 1)


for (x, y, s) in [(-15, 8, 1.2), (19, 13, 0.9), (-6, -15.5, 1.0)]:
    galho(x, y, altura(x, y) - 0.2, 3.2 * s, random.uniform(0, 6.3), random.uniform(0, 0.15), 0.26 * s, 3)
    LIVRE.append((x - 0.4, y - 0.4, x + 0.4, y + 0.4))

for nome, bm in LOTES.items():
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MATS[nome][0])
    for p in me.polygons:
        p.use_smooth = nome in ("chao", "folha", "rocha", "casca", "lama", "muro")
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)

# ---------- modelos do Poly Haven: importa, simplifica os pesados e espalha cópias ----------
MODELOS = {}


def importa(pasta, reduz=1.0):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(PH, pasta, pasta + ".gltf"))
    novos = [o for o in bpy.data.objects if o not in antes]
    for o in novos:
        if o.type != "MESH":
            continue
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
        o.location = (0, 0, 0)
        for s in bpy.context.selected_objects:
            s.select_set(False)
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        if reduz < 1.0:
            md = o.modifiers.new("menos", "DECIMATE")
            md.ratio = reduz
            bpy.ops.object.modifier_apply(modifier=md.name)
        for c in list(o.users_collection):
            c.objects.unlink(o)   # o original fica fora da cena; só as cópias são exportadas
        MODELOS.setdefault(pasta, []).append(o)
    for o in novos:
        if o.type != "MESH":
            bpy.data.objects.remove(o)


def poe(pasta, x, y, giro=None, esc=1.0, deco=False, idx=None, z=None):
    modelos = MODELOS[pasta]
    m = modelos[idx if idx is not None else random.randrange(len(modelos))]
    o = bpy.data.objects.new(("deco_" if deco else "obj_") + m.name, m.data)
    o.location = (x, y, altura(x, y) if z is None else z)
    o.rotation_euler = (0, 0, random.uniform(0, math.tau) if giro is None else giro)
    o.scale = (esc, esc, esc)
    bpy.context.scene.collection.objects.link(o)
    return o


importa("grass_medium_01", 0.35)
importa("grass_medium_02", 0.35)
importa("fern_02")
importa("nettle_plant", 0.25)
importa("dry_branches_medium_01", 0.3)
importa("rock_moss_set_01", 0.4)
importa("boulder_01", 0.08)
importa("tree_stump_01", 0.15)
importa("dead_tree_trunk", 0.06)
importa("root_cluster_01", 0.04)
importa("wooden_lantern_01")
importa("wooden_barrels_01", 0.5)
importa("wooden_crate_01")
importa("wooden_bucket_01")
importa("stone_fire_pit")


def pinheiros(n=4):
    """Pinheiro do jeito dos jogos: tronco 3D e centenas de cartões com a foto de um ramo de verdade
    (cenarios/foto_arvores.py), em andares, compridos embaixo e curtos em cima, caídos nas pontas.
    Cada ramo leva 3 cartões em leque pra não sumir quando visto de lado. Normais apontam pra fora da copa,
    então ela recebe luz como um volume (cartão com normal própria vira manchas claras e escuras)."""
    pasta = os.path.expanduser("~/Projects/tabletop/assets/arvores")
    m = json.load(open(os.path.join(pasta, "medidas.json")))
    proporcao = m["largura"] / m["comprimento"]
    mat, nt, bsdf = novo_material("ramo")
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = bpy.data.images.load(os.path.join(pasta, "ramo.png"))
    nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
    corte = nt.nodes.new("ShaderNodeMath")   # Round = recorte em 0,5 (o glTF sai com alphaMode MASK)
    corte.operation = "ROUND"
    nt.links.new(tx.outputs["Alpha"], corte.inputs[0])
    nt.links.new(corte.outputs[0], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.9
    # miolo: a mesma foto do ramo sem recorte (o fundo já foi pintado com a cor das agulhas), pra parecer
    # mais agulha lá dentro e não um cone escuro liso
    miolo, nt2, bsdf2 = novo_material("ramo_miolo")
    tx2 = nt2.nodes.new("ShaderNodeTexImage")
    tx2.image = tx.image
    nt2.links.new(tx2.outputs["Color"], bsdf2.inputs["Base Color"])
    bsdf2.inputs["Roughness"].default_value = 0.9
    for k in range(n):
        rnd = random.Random(100 + k)
        H = rnd.uniform(11, 16)
        vs, fs, uvs, mats, nor = [], [], [], [], []
        # tronco: 8 lados, afina até a ponta
        seg, r0 = 8, 0.22 * H / 13
        for i in range(seg + 1):
            a = i * math.tau / seg
            for z, r in ((0.0, r0), (H, 0.02)):
                vs.append((math.cos(a) * r, math.sin(a) * r, z))
                uvs.append((i / seg, z / 1.4))
                nor.append((math.cos(a), math.sin(a), 0))
        for i in range(seg):
            fs.append((2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1))
            mats.append(0)
        # miolo: cone fino dentro da copa (30% do comprimento dos ramos), pra não ver o céu através dela.
        # Para 2,5 m antes da ponta, onde os ramos são curtos e ele aparecia
        lados, alturas = 10, 12
        base = len(vs)
        for a_i in range(alturas + 1):
            t = a_i / alturas
            z = 2.0 + t * (H - 4.5)
            r = 0.3 * (0.5 + 3.0 * (1 - (z - 1.8) / (H - 1.8)) ** 1.1)
            for i in range(lados + 1):
                a = i * math.tau / lados
                rr = r * (1 + 0.25 * noise.noise(Vector((math.cos(a) * 2 + k * 7, math.sin(a) * 2, z * 0.8))))
                vs.append((math.cos(a) * rr, math.sin(a) * rr, z - 0.15 * rr))
                uvs.append((i / lados * 3, z / 1.2))
                nor.append(tuple(Vector((math.cos(a), math.sin(a), 0.7)).normalized()))
        for a_i in range(alturas):
            for i in range(lados):
                q = base + a_i * (lados + 1) + i
                fs.append((q, q + 1, q + lados + 2, q + lados + 1))
                mats.append(2)
        # ramos em andares
        z = rnd.uniform(1.8, 2.6)
        while z < H - 0.3:
            t = (z - 1.8) / (H - 1.8)
            L = 0.5 + 3.0 * (1 - t) ** 1.1
            cai = math.radians(-28 + 30 * t)   # embaixo caem mais
            giro0 = rnd.uniform(0, math.tau)
            nr = rnd.choice((7, 8, 9)) if t < 0.85 else 5
            for j in range(nr):
                az = giro0 + j * math.tau / nr + rnd.uniform(-0.3, 0.3)
                Lj = L * rnd.uniform(0.8, 1.15)
                w = Lj * proporcao
                for rolo in (math.radians(38), 0.0, math.radians(-38)):
                    rot = Matrix.Rotation(az, 3, "Z") @ Matrix.Rotation(-cai, 3, "Y") @ Matrix.Rotation(rolo, 3, "X")
                    i0 = len(vs)
                    for (u, v) in ((0, 0), (1, 0), (1, 1), (0, 1)):
                        q = rot @ Vector((u * Lj, (v - 0.5) * w, 0)) + Vector((0, 0, z))
                        q.z -= 0.25 * Lj * u * u * (1 - t)   # ponta pende
                        vs.append(tuple(q))
                        uvs.append((u, 1 - v))
                        fora = Vector((q.x, q.y, 0))
                        fora = fora.normalized() if fora.length > 0.05 else Vector((math.cos(az), math.sin(az), 0))
                        nor.append(tuple((fora + Vector((0, 0, 0.7))).normalized()))
                    fs.append((i0, i0 + 1, i0 + 2, i0 + 3))
                    mats.append(1)
            z += rnd.uniform(0.28, 0.4) * (1 - 0.4 * t)
        me = bpy.data.meshes.new(f"pinheiro_{k}")
        me.from_pydata(vs, [], fs)
        uv = me.uv_layers.new()
        for lp in me.loops:
            uv.data[lp.index].uv = uvs[lp.vertex_index]
        for pol, mi in zip(me.polygons, mats):
            pol.material_index = mi
            pol.use_smooth = True
        me.normals_split_custom_set([nor[lp.vertex_index] for lp in me.loops])
        me.materials.append(MATS["casca"][0])
        me.materials.append(mat)
        me.materials.append(miolo)
        MODELOS.setdefault("pinheiros", []).append(bpy.data.objects.new(f"pinheiro_{k}", me))
        print("PINHEIRO", k, len(fs) * 2, "triângulos")


pinheiros()
# grama: só as moitas mais altas, que leem de longe
MODELOS["grass_medium_01"] = [o for o in MODELOS["grass_medium_01"] if any(k in o.name for k in ("large", "mid", "tall"))]


# pinheiros de fundo
rng = random.Random(11)
feitas = 0
while feitas < 380:   # floresta até a borda do terreno
    x, y = rng.uniform(-48, 48), rng.uniform(-48, 48)
    if math.hypot(x, y - 2) < 18.5 or (abs(x) < 3.5 and y < -14):
        continue
    poe("pinheiros", x, y, esc=rng.uniform(0.85, 1.2), deco=True, z=altura(x, y) - 0.15)
    feitas += 1

def livre(x, y, folga=0.0):
    for cx, cy, w in CAMINHO:
        if (x - cx) ** 2 + (y - cy) ** 2 < (w + folga) ** 2:
            return False
    for x0, y0, x1, y1 in LIVRE:
        if x0 - folga < x < x1 + folga and y0 - folga < y < y1 + folga:
            return False
    return True


# mato: mancha densa perto de muros e no cemitério, rala no meio da clareira
rng = random.Random(21)
random.seed(22)
mato = 0
tentativas = 0
while mato < 7000 and tentativas < 90000:
    tentativas += 1
    x, y = rng.uniform(-21, 21), rng.uniform(-20, 23)
    r = math.hypot(x, y - 2)
    if r > 21 or not livre(x, y, 0.1):
        continue
    dens = 0.55 + 0.6 * noise.noise(Vector((x * 0.18, y * 0.18, 5)))
    if CX0 < x < CX1 and CY0 < y < CY1:
        dens += 0.6
    if rng.random() > dens:
        continue
    k = rng.random()
    if k < 0.4:
        poe("grass_medium_01", x, y, esc=rng.uniform(2.6, 3.8), deco=True)
    elif k < 0.88:
        poe("grass_medium_02", x, y, esc=rng.uniform(2.4, 3.4), deco=True)
    elif k < 0.95:
        poe("fern_02", x, y, esc=rng.uniform(0.9, 1.4), deco=True)
    else:
        poe("nettle_plant", x, y, esc=rng.uniform(4.0, 6.0), deco=True)
    mato += 1
for x, y in TUMULOS:   # mato alto encostado nas lápides
    for k in range(3):
        poe("grass_medium_01", x + rng.uniform(-0.5, 0.5), y + rng.uniform(-0.2, 0.3), esc=rng.uniform(3.0, 3.8), deco=True)
for i in range(18):
    x, y = rng.uniform(-18, 18), rng.uniform(-16, 20)
    if livre(x, y, 0.3):
        poe("dry_branches_medium_01", x, y, esc=rng.uniform(1.0, 1.6), deco=True)
# pedras, tocos, troncos caídos, raízes (com colisão)
for i in range(26):
    a = rng.uniform(0, math.tau)
    rr = rng.uniform(5, 20)
    x, y = math.cos(a) * rr, math.sin(a) * rr + 2
    if livre(x, y, 1.0) and not (CX0 - 1 < x < CX1 + 1 and CY0 - 1 < y < CY1 + 1):
        poe("rock_moss_set_01", x, y, esc=rng.uniform(0.25, 0.6), z=altura(x, y) - 0.15)
for (x, y, e) in [(-9.5, 10, 0.9), (16.5, -3, 0.7), (-17, -2, 1.1)]:
    poe("boulder_01", x, y, esc=e, z=altura(x, y) - 0.3)
for (x, y) in [(-6.5, -10.5), (4.5, -15), (12.5, 20.0), (-12.5, 14.5)]:
    poe("tree_stump_01", x, y, esc=0.9)
for (x, y, g) in [(-4.0, 13.5, 0.4), (6.0, -12.0, 2.0), (-14.0, 2.5, 1.2)]:
    poe("dead_tree_trunk", x, y, giro=g, esc=1.6, z=altura(x, y) + 0.12)
for (x, y, g) in [(-17.5, 10.0, 0.8), (18.0, 4.0, 3.5)]:
    poe("root_cluster_01", x, y, giro=g, esc=1.2, z=altura(x, y) - 0.2)

# varanda da cabana: lampião pendurado, barris, caixote, balde, fogueira de pedra
lamp = CAB @ Vector((-2.35, -3.75, 2.05))
for k in range(len(MODELOS["wooden_lantern_01"])):
    poe("wooden_lantern_01", lamp.x, lamp.y, giro=0.25, idx=k, z=lamp.z)
caixa_ferro = (lamp.x, lamp.y, lamp.z + 0.62)
for k, (dx, dy) in enumerate([(2.9, -2.8), (3.6, -2.4), (3.3, -1.6)]):
    p = CAB @ Vector((dx, dy, 0))
    poe("wooden_barrels_01", p.x, p.y, idx=k % 2, esc=1.0)
p = CAB @ Vector((-3.4, -2.6, 0))
for k in range(len(MODELOS["wooden_crate_01"])):
    poe("wooden_crate_01", p.x, p.y, giro=0.4, idx=k, z=p.z)
p = CAB @ Vector((-1.4, -3.5, 0.12))
for k in range(len(MODELOS["wooden_bucket_01"])):
    poe("wooden_bucket_01", p.x, p.y, giro=0.0, idx=k, z=p.z + 0.12)
FOGO = (-8.8, -10.6)
for k in range(len(MODELOS["stone_fire_pit"])):
    poe("stone_fire_pit", FOGO[0], FOGO[1], giro=0.0, idx=k)
p = (PX + 0.75, PY + 0.55)
for k in range(len(MODELOS["wooden_bucket_01"])):
    poe("wooden_bucket_01", p[0], p[1], giro=0.6, idx=k, z=altura(*p) + 0.85)

# a corrente do lampião entra no lote de ferro, que já foi montado: vira objeto próprio
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1)
bmesh.ops.transform(bm, matrix=M(caixa_ferro, (0, 0, 0), (0.02, 0.02, 0.4)), verts=bm.verts)
me = bpy.data.meshes.new("corrente")
bm.to_mesh(me)
me.materials.append(MATS["ferro"][0])
bpy.context.scene.collection.objects.link(bpy.data.objects.new("corrente", me))

os.makedirs(OUT, exist_ok=True)
glb = os.path.join(OUT, "capela.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_image_format="WEBP", export_image_quality=88)   # o JPEG do Blender 5.3 o Godot não lê


# ---------- mesa pronta (coordenadas do Godot: x, y pra cima, z = -y do Blender) ----------
def G(x, y, dz=0.0):
    return {"x": x, "y": altura(x, y) + dz, "z": -y}


chamine = CAB @ Vector((1.8, 1.2, 5.0))
janela_cab = CAB @ Vector((0.6, -1.6, 1.4))
objetos = [
    ("Tocha", -1.6, 4.9), ("Tocha", 1.6, 4.9),
    ("Luz mágica", 0, 13.6, 0.9), ("Sigilos", 0, 12.2), ("Luz quente", 0, 13.6, 1.4),
    ("Luz quente", -2.2, 9.0, 1.8), ("Luz quente", 2.2, 11.0, 1.8),
    ("Luz quente", lamp.x, lamp.y, lamp.z - altura(lamp.x, lamp.y)),
    ("Fogo", FOGO[0], FOGO[1], 0.1), ("Brasas", FOGO[0], FOGO[1], 0.2), ("Luz quente", FOGO[0], FOGO[1], 0.6),
    ("Fumaça", chamine.x, chamine.y, 5.0),
    ("Luz quente", janela_cab.x, janela_cab.y, 1.4),
    ("Neblina rasteira", 11, 7), ("Neblina rasteira", 14, 12), ("Neblina rasteira", 10, 15),
    ("Neblina rasteira", -4, 6), ("Neblina rasteira", 3, -14), ("Neblina rasteira", -3, -20),
    ("Sigilos", SX, SY, 0.62), ("Brasas", SX, SY, 0.62), ("Luz mágica", SX, SY, 0.0),
    ("Vaga-lumes", -13, 5), ("Vaga-lumes", 12, -1), ("Vaga-lumes", -4, -15),
    ("Lanterna", 1.6, -13), ("Lanterna", -1.6, -6.0), ("Lanterna", 6.3, 9.0),
    ("Tocha", CX0 - 0.6, 9.6), ("Tocha", CX0 - 0.6, 12.4),
]
pecas = []
for nome, var, x, y, giro in [("Arqueiro", "arco", -0.9, -6.5, 0.0), ("Vigia", "lanterna", 1.0, -7.5, 0.3), ("Encapuzado", "capuz", 13.5, 9.5, 2.4)]:
    p = G(x, y)
    p.update({"nome": nome, "cor": "8a6d4a", "perso": "arqueiro", "var": var, "giro": giro})
    pecas.append(p)
mesa = {
    "cenario": os.path.abspath(glb),
    "clima": "Entardecer com neblina",
    "pecas": pecas,
    "objetos": [dict(tipo=o[0], **G(o[1], o[2], o[3] if len(o) > 3 else 0.0)) for o in objetos],
    "planos": {},
}
with open(os.path.join(OUT, "capela_mesa.json"), "w") as f:
    json.dump(mesa, f, ensure_ascii=False, indent=1)
n_deco = sum(1 for o in bpy.context.scene.objects if o.name.startswith("deco_"))
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
print("CENARIO OK", glb, "deco", n_deco, "tris (cópias contam)", tris)

# o programa abre o que o Godot importou (detalhe menor de longe, textura compactada): importa de novo,
# senão ele continua abrindo a versão velha (uns 2 min)
import subprocess
subprocess.run(["godot", "--headless", "--path", os.path.dirname(os.path.abspath(OUT)), "--import"], check=False)
