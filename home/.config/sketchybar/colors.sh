#!/bin/bash

# The palette, and only the palette. Three are shipped; uncomment the one you
# want and comment out the current one, then restart SketchyBar.
#
# Which palette entry each item uses - clock, calendar, battery, volume, the
# focused workspace - is decided in theme.conf, which is read after this file
# and can also override any entry below. Everything on the bar goes through one
# of the two, so a colour never has to be changed in six places again.

### Sonokai
# export BLACK=0xff181819
# export WHITE=0xffe2e2e3
# export RED=0xfffc5d7c
# export GREEN=0xff9ed072
# export BLUE=0xff76cce0
# export YELLOW=0xffe7c664
# export ORANGE=0xfff39660
# export MAGENTA=0xffb39df3
# export GREY=0xff7f8490
# export TRANSPARENT=0x00000000
# export BG0=0xff2c2e34
# export BG1=0xff363944
# export BG2=0xff414550

# Tokyonight Night
# export BLACK=0xff24283b
# export WHITE=0xffa9b1d6
# export MAGENTA=0xffbb9af7
# export BLUE=0xff7aa2f7
# export CYAN=0xff7dcfff
# export GREEN=0xff9ece6a
# export YELLOW=0xffe0af68
# export ORANGE=0xffff9e64
# export RED=0xfff7768e
# export BAR_COLOR=0xff1a1b26
# export COMMENT=0xff565f89
# export TRANSPARENT=0x00000000
# export BG0=0xff1a1b26
# export BG1=0x603c3e4f
# export BG2=0x60494d64

# General bar colors
# export BAR_COLOR=$BG0
# export BAR_BORDER_COLOR=$BG2
# export BACKGROUND_1=$BG1
# export BACKGROUND_2=$BG2
# export ICON_COLOR=$WHITE # Color of all icons
# export LABEL_COLOR=$WHITE # Color of all labels
# export POPUP_BACKGROUND_COLOR=$BLACK
# export POPUP_BORDER_COLOR=$COMMENT
# export SHADOW_COLOR=$BLACK



# ### Catppuccin
export BLACK=0xff24283b
export WHITE=0xffcad3f5
export RED=0xffed8796
export GREEN=0xffa6da95
export BLUE=0xff8aadf4
export YELLOW=0xffeed49f
export ORANGE=0xfff5a97f
export MAGENTA=0xffc6a0f6
export GREY=0xff939ab7
export TRANSPARENT=0x00000000
export BG0=0xff1e1e2e
export BG1=0x603c3e4f
export BG2=0x60494d64
export COMMENT=0xff565f89
export CYAN=0xff7dcfff

# General bar colors
export BAR_COLOR=$BG0
export BAR_BORDER_COLOR=$BG2
export BACKGROUND_1=$BG1
export BACKGROUND_2=$BG2
export ICON_COLOR=$WHITE # Color of all icons
export LABEL_COLOR=$WHITE # Color of all labels
export POPUP_BACKGROUND_COLOR=$BAR_COLOR
export POPUP_BORDER_COLOR=$WHITE
export SHADOW_COLOR=$BLACK