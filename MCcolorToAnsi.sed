#!/bin/sed -f

# Pipe output from MCBErunCommand.sh through this script to get colored output on terminal.
# e.g.
#      sudo ./MCBErunCommand.sh mcbe@MCBE help 3 | ./MCcolorToAnsi.sed

# These escapes work in my terminals (Ubuntu 20.04) but may not work in all
# Ref: ansi colors http://www.andrewnoske.com/wiki/Bash_-_adding_color#ANSI_Colors_and_Formatting
# Ref: minecraft colors https://minecraft.gamepedia.com/Formatting_codes

# Black
s,§0,\o33[30m,g

# Blue
s,§1,\o33[34m,g

# Green
s,§2,\o33[32m,g

# Aqua / Cyan
s,§3,\o33[36m,g

# Red
s,§4,\o33[31m,g

# Purple / Magenta
s,§5,\o33[35m,g

# Gold / Yellow
s,§6,\o33[33m,g

# Grey
s,§7,\o33[37m,g

# Light Black
s,§8,\o33[90m,g

# Light Blue
s,§9,\o33[94m,g

# Light Green
s,§a,\o33[92m,g

# Light Aqua / Cyan
s,§b,\o33[96m,g

# Light Red
s,§c,\o33[91m,g

# Light Purple / Magenta
s,§d,\o33[95m,g

# Light Gold / Yellow
s,§e,\o33[93m,g

# Light Grey
s,§f,\o33[97m,g

# Reset
s,§r,\o33[m,g

# Always reset at end of line
s,$,\o33[m,g

# Obfuscated - not supported - no equivalent in terminal
# §k 

# Bold - note this is basically the 'light' colors on most terminals
s,§l,\o33[1m,g

# Strikethrough - documented but I haven't seen a terminal where it works
s,§m,\o33[9m,g

# Underlined 
s,§n,\o33[4m,g

# Italic 
s,§o,\o33[3m,g