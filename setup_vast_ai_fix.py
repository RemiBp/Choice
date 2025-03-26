#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Correction pour setup_vast_ai.py

Ce fichier contient les versions corrigées des fonctions print_header et print_step
qui causent des erreurs de linting dans setup_vast_ai.py.

Instructions d'application:
1. Connectez-vous à votre instance vast.ai
2. Ouvrez setup_vast_ai.py dans un éditeur
3. Localisez les fonctions print_header et print_step (lignes ~368-376)
4. Remplacez-les par les versions ci-dessous
5. Sauvegardez le fichier
"""

# Versions corrigées des fonctions
# Copiez ces définitions exactement comme elles sont

def print_header(message):
    """Affiche un en-tête avec formatage"""
    print(f"\n{BOLD}{BLUE}{'=' * 80}{RESET}")
    print(f"{BOLD}{BLUE}{'=' * 30} {message} {'=' * 30}{RESET}")
    print(f"{BOLD}{BLUE}{'=' * 80}{RESET}\n")

def print_step(message):
    """Affiche un message d'étape avec formatage"""
    print(f"\n{BOLD}{GREEN}===> {message}{RESET}")

# Les autres fonctions qui utilisent des f-strings avec des backslashes devraient
# également être corrigées. Par exemple, changez:
# f.write(f"\{'=' * 50}\")
# en:
# f.write(f"{'=' * 50}\n")

# Cette correction fonctionne en remplaçant:
# 1. Les séquences d'échappement de fin de ligne "\\" par de vraies séquences d'échappement "\n" 
# 2. Les sauts de ligne avec continuation "\\\n" par des "\n" bien formés

print("Ce fichier contient les versions corrigées des fonctions print_header et print_step")
print("pour résoudre les erreurs de linting dans setup_vast_ai.py")