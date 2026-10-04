# Agenda

Agenda est l'agenda de [Covalence](https://github.com/melvincouwez-alt/covalence) pour elementary OS : les agendas de votre compte iCloud et ceux de ce PC, dans une fenêtre elementary. Il passe par Evolution Data Server, qui synchronise les agendas iCloud en CalDAV. Les changements arrivent donc sur l'iPhone et sur iCloud.com.

Trois dispositions, au choix dans la barre d'en-tête :

- **Mois**, avec le panneau du jour et ce qui arrive ensuite ;
- **Semaine**, sur une grille horaire ;
- **Fil**, la liste des jours avec un ajout rapide en français (« demain 14h dentiste »).

Agenda ouvre aussi les fichiers `.ics` pour en ajouter les évènements à un agenda.

## Installer

Le paquet `agenda_<version>_amd64.deb` est publié dans les [versions de ce dépôt](https://github.com/melvincouwez-alt/agenda/releases). Covalence l'installe depuis son onglet « Services Apple ». Pour installer le paquet à la main, téléchargez-le puis :

```sh
sudo apt install ./agenda_*_amd64.deb
```

Le compte iCloud s'ajoute dans Réglages système › Comptes en ligne, ou depuis Covalence.

## Construire

Dépendances : `valac`, `meson`, `libgtk-4-dev`, `libgranite-7-dev`, `libgee-0.8-dev`, `libecal2.0-dev`, `libedataserver1.2-dev`, `libical-dev`.

```sh
meson setup build --prefix=/usr
ninja -C build
packaging/build-deb.sh   # donne dist/agenda_<version>_amd64.deb
```

## Crédits

- **Evolution Data Server** ([GNOME/evolution-data-server](https://gitlab.gnome.org/GNOME/evolution-data-server), LGPL-2.1-or-later) pour les agendas et la synchronisation CalDAV, et **libical** ([libical/libical](https://github.com/libical/libical), LGPL-2.1-or-later ou MPL-2.0) pour les évènements.
- **GTK** (LGPL-2.1-or-later), **Granite** ([elementary/granite](https://github.com/elementary/granite), LGPL-3.0-or-later), **libgee** (LGPL-2.1-or-later) et **Vala** (LGPL-2.1-or-later).
- **Inter**, de Rasmus Andersson ([rsms/inter](https://github.com/rsms/inter), SIL Open Font License 1.1) : le texte de l'icône est dessiné en contours à partir d'Inter Display.

## Mentions légales

Agenda est un logiciel libre et indépendant. Il n'est ni affilié à Apple Inc. ni approuvé par Apple Inc., ni par elementary, Inc. Apple, iPhone et iCloud sont des marques d'Apple Inc., déposées aux États-Unis et dans d'autres pays. elementary est une marque d'elementary, Inc. Ces noms ne servent qu'à décrire la compatibilité.

## Licence

Agenda est distribué sous licence [GNU GPL, version 3 ou ultérieure](LICENSE). © 2026 melvincouwez-alt.
