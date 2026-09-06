#!/usr/bin/env python3
"""Prepara a captura do paywall para o App Store Connect.

    python3 app-store/preparar-print-da-compra.py <captura.png>

O App Store Connect **recusa imagem com canal alfa**, e toda captura de
simulador sai em RGBA. É por isso que um print que parece perfeito é rejeitado
sem explicação útil — o problema não está no que a imagem mostra, está no que
ela carrega.

Comparação que fecha o diagnóstico:

    print recusado : 8-bit RGBA, hasAlpha=yes
    print do Bilhete que a Apple aceitou : 8-bit RGB, hasAlpha=no

O script achata o alfa sobre o fundo do próprio app (#061620), converte para RGB
puro em sRGB e normaliza para 1242 × 2688 — o mesmo tamanho do print aceito do
Bilhete. O redimensionamento é "encaixar e preencher": nada é cortado, e a
sobra é preenchida com a cor de fundo do app, que é invisível na tela escura.
"""
import sys
from pathlib import Path

from PIL import Image

# Fundo do app no tema escuro (token BackgroundPrimary, variante escura).
FUNDO = (0x06, 0x16, 0x20)

# O mesmo tamanho do print do Bilhete que a Apple aceitou.
ALVO = (1242, 2688)

DESTINO = Path("app-store/in-app/review-screenshot-com.dablab.vounadar.completo.png")


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2

    origem = Path(argv[1])
    if not origem.exists():
        print(f"não achei {origem}")
        return 1

    img = Image.open(origem)
    print(f"entrada: {img.width} × {img.height}, modo {img.mode}")

    # Achata o alfa sobre o fundo do app. Composite, e não simples descarte do
    # canal: pixel semitransparente descartado vira borda suja.
    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGBA")
        fundo = Image.new("RGB", img.size, FUNDO)
        fundo.paste(img, mask=img.split()[-1])
        img = fundo
    else:
        img = img.convert("RGB")

    # Encaixa dentro do alvo sem cortar nada, e preenche a sobra.
    escala = min(ALVO[0] / img.width, ALVO[1] / img.height)
    novo = (round(img.width * escala), round(img.height * escala))
    img = img.resize(novo, Image.LANCZOS)

    peca = Image.new("RGB", ALVO, FUNDO)
    peca.paste(img, ((ALVO[0] - novo[0]) // 2, (ALVO[1] - novo[1]) // 2))

    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    peca.save(DESTINO, "PNG", optimize=True)

    print(f"saída  : {peca.width} × {peca.height}, modo {peca.mode}, sem alfa")
    print(f"gravado: {DESTINO}")
    print()
    print("confira antes de subir:")
    print(f'  sips -g pixelWidth -g pixelHeight -g hasAlpha "{DESTINO}"')
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
