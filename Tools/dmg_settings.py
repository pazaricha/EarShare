# dmgbuild settings: app on the left, Applications on the right, arrow background
import os
ROOT = defines["root"]
files = [f"{ROOT}/build/EarShare.app"]
symlinks = {"Applications": "/Applications"}
background = f"{ROOT}/Resources/dmg-background.tiff"
icon_size = 112
text_size = 13
window_rect = ((200, 120), (660, 400))
icon_locations = {"EarShare.app": (165, 215), "Applications": (495, 215)}
show_status_bar = show_tab_view = show_toolbar = show_pathbar = show_sidebar = False
format = "UDZO"
