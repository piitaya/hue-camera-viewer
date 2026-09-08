"""Finder layout for the two-item Girafon installer. Used by dmgbuild."""
from pathlib import Path

app = Path(defines["app"]).resolve()
files = [(str(app), "Girafon.app")]
symlinks = {"Applications": "/Applications"}
background = str(Path(defines["background"]).resolve())
icon = str(app / "Contents/Resources/Girafon.icns")
format = "UDZO"
filesystem = "HFS+"
default_view = "icon-view"
include_icon_view_settings = True
include_list_view_settings = False
window_rect = ((240, 180), (660, 420))
icon_locations = {"Girafon.app": (180, 224), "Applications": (480, 224)}
icon_size = 112
text_size = 14
label_pos = "bottom"
arrange_by = None
grid_spacing = 99
scroll_position = (0, 0)
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
