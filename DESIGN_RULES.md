# 🎨 Règles de Design Spécifiques — Boardly (iOS · Pine Teal)

> Client iOS natif pour Planka (kanban). Source de vérité pixel : `Boardly App.dc.html`.
> Gabarit de référence : écran **390 × 844** (barre d'état 54, encoche 118 × 33, home indicator 134 × 5).

## Marges & espacements
- Pas de grille 8pt stricte. Échelle de référence :
  - Padding écran latéral : **18–20pt**.
  - Padding interne carte : **14–16pt**.
  - Gap entre items de liste : **9–12pt**.
  - Gap entre actions/chips : **6–10pt**.

## Typographie
- **UI** : Manrope — poids 400 / 500 / 600 / 700 / 800.
- **Labels & captions** : JetBrains Mono — 400 / 500, `text-transform: uppercase`, `letter-spacing` .1–.14em, tailles **10.5–12px**.
- Échelle :
  - Titre écran : **Manrope ExtraBold (800) 32px**.
  - Titre carte (vue détail) : **ExtraBold 23px**, letter-spacing −0.02em.
  - Titre de sheet : **ExtraBold 17px**.
  - Titre de section : **Bold (700) 13px**.
  - Corps : **Regular 14–16px**.
  - Méta / secondaire : **11.5–12.5px**.
- En natif iOS : équivalents système acceptés si Manrope/JetBrains Mono indisponibles.

## Couleurs
| Rôle | Hex |
|---|---|
| Accent (Pine Teal) — boutons, liens, sélections | `#1F7A6B` (light) / `#4FB3A1` (dark) |
| Teinte accent (fonds légers) | `#E2EFEC` |
| Highlight ambre — **icône/marketing uniquement, jamais dans l'UI** | `#E8A23B` |
| Fond écran | `#F4F2EE` |
| Surface / carte | `#FFFFFF` |
| Texte primaire | `#1d1f24` |
| Texte secondaire | `#55524c` |
| Texte tertiaire | `#76726b` |
| Texte muted | `#9a968d` / `#a8a49c` |
| Bordures | `#E8E5DF` / `#EBE7DF` |
| Hairline interne | `#F4F1EB` |
| Remplissage neutre (chips / track) | `#ECEAE4` |
| Case vide / anneau | `#D4D0C8` |
| Chevron | `#c9c5bd` |
| Grabber | `#cfcbc2` |
| Destructif | `#B0413E` |
| Overlay derrière sheet | `#1d1f24` @ 55% |

### Palette labels & avatars (7 teintes sobres)
`Design #B05C72` · `Priorité #C0823E` · `Développement #1F7A6B` · `Recherche #3E6E94` · `QA #6F8B57` · `Docs #7C6597` · `Bloqué #B0413E`
- Avatars : initiales sur pastille de couleur (MD `#B05C72`, PL `#C0823E`, JK `#3E6E94`, EM `#6F8B57`).

## Icônes
- Style trait **2px** (Lucide/Feather) → utiliser **SF Symbols** en natif iOS (équivalents directs).
- Tuile icône teintée : fond `#E2EFEC`, **30pt**, radius **9**.

## Rayons (border-radius)
- Cartes : **14** · Inputs : **12–13** · Boutons : **14–15** · Chips : **11**.
- Pastilles label : **7–9** · Case sous-tâche : **7** · Avatars : **50%**.
- Bottom-sheet (coins hauts) : **26** · Panneau contenu vue détail (coins hauts) : **22**.

## Ombres
- Carte : `0 1px 3px rgba(0,0,0,.06)`.
- Sheet : `0 -10px 40px rgba(0,0,0,.3)`.

## Boutons & contrôles
- Bouton d'envoi rond accent : **38pt**.
- Boutons ronds translucides sur cover : blanc 92% + ombre douce.
- Toggle/interrupteur : **46×28**, pastille blanche 22, ON = accent.
- Check de sélection : pastille accent **24pt** + check blanc ; non coché = anneau `#D4D0C8`.
- Pastille « + Label » : texte `#9a968d`, `border: 1px dashed #d4d0c8`, radius 7.
- **Cibles tactiles ≥ 44pt partout.**

## Modales (bottom-sheets)
- Fond `#F4F2EE`, coins hauts **26**, ombre sheet, grabber `#cfcbc2` centré.
- Header : « Annuler » (muted) / Titre (17/800) / « OK » ou « Enregistrer » (accent, 700).
- Présentation modale iOS : détentes, swipe-to-dismiss ; « Annuler » ferme sans appliquer.
- Transitions : présentation/dismiss standard iOS ; en-tête collant ~**200ms ease**.

## App icon
- Default : fond `#1B7567` · Dark : `#0E2A26` · Tinted : teinte système.
- Structure Icon Composer : couche background + couche glyphe transparente.
