#!/usr/bin/env python3
"""Mede os campos da ficha da App Store contra os limites reais da Apple.

Lê os blocos de código de `app-store-connect-vou-nadar.md` e confere cada um.
Rode antes de colar qualquer coisa no App Store Connect — errar limite lá é
descobrir na hora de salvar, com o texto já cortado.

Keywords é o único campo medido em BYTES, não em caracteres: letra acentuada
custa dois, e é por isso que ele vai sem acento.
"""
import re
import sys

DOC = "app-store/app-store-connect-vou-nadar.md"

# (rótulo, limite, unidade, âncora no documento)
CAMPOS = [
    ("Nome", 30, "chars", None),
    ("Subtítulo", 30, "chars", None),
    ("Texto promocional", 170, "chars", "### Texto promocional"),
    ("Descrição", 4000, "chars", "### Descrição"),
    ("Keywords", 100, "bytes", "### Keywords"),
    ("Novidades desta versão", 4000, "chars", "### Novidades desta versão"),
    ("IAP display name", 30, "chars", None),
    ("IAP descrição", 45, "chars", "**Descrição (pt-BR):**"),
    ("Notas de revisão (IAP)", 4000, "chars", "**Review notes do produto:**"),
    ("Notas de revisão (app)", 4000, "chars", "### Notes"),
]

# Campos curtos que vivem em tabela, não em bloco de código.
DA_TABELA = {
    "Nome": "Vou Nadar",
    "Subtítulo": "Treino de piscina no seu pulso",
    "IAP display name": "Vou Nadar completo",
}


def bloco(texto, ancora):
    """O primeiro bloco ``` depois da âncora."""
    i = texto.index(ancora)
    j = texto.index("```", i)
    k = texto.index("```", j + 3)
    return texto[j + 3:k].strip()


def main():
    try:
        doc = open(DOC, encoding="utf-8").read()
    except FileNotFoundError:
        print(f"não achei {DOC} — rode da raiz do repositório")
        return 1

    falhou = False
    for rotulo, limite, unidade, ancora in CAMPOS:
        valor = DA_TABELA[rotulo] if ancora is None else bloco(doc, ancora)
        tamanho = len(valor.encode("utf-8")) if unidade == "bytes" else len(valor)
        ok = tamanho <= limite
        falhou |= not ok
        print(f"{rotulo}: {tamanho}/{limite} {unidade} [{'OK' if ok else 'ESTOUROU'}]")
    return 1 if falhou else 0


if __name__ == "__main__":
    sys.exit(main())
