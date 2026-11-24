# Mesa 3D

Mesa de RPG em 3D feita no Godot 4: o mestre controla tudo numa tela e os jogadores assistem por uma
segunda janela (câmera dos jogadores), com névoa de guerra, luzes, efeitos, planos de câmera e portas
que abrem com um clique.

## Rodar

```bash
godot --path . -- --mesa cenarios/capela_mesa.json
```

Os cenários são gerados por scripts do Blender em `cenarios/` (ex.: `blender -b -P cenarios/capela.py -- cenarios`).
Os modelos baixados (Poly Haven, CC0) não estão no repositório.

## Testes

```bash
godot --path . -- --foto teste/teste.glb
godot --path . -- --mesa cenarios/capela_mesa.json --fotos
```
