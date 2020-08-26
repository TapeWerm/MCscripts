#!/bin/sed -f

# Pipe output from Minecraft Java Edition or Bedrock Edition server to this script for color codes on terminal
# Formatting may not work on your terminal

# Example: systemctl status mcbe@MCBE | ./MCcolor.sed

# Minecraft colors: https://minecraft.gamepedia.com/Formatting_codes
# ANSI colors:      https://en.wikipedia.org/wiki/ANSI_escape_code

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

# Gray
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

# Light Gray
s,§f,\o33[97m,g

# Reset
s,§r,\o33[m,g

# Always reset at end of line
s,$,\o33[m,g

# Bold (note this is basically the "light" colors on most terminals)
s,§l,\o33[1m,g

# Strikethrough
s,§m,\o33[9m,g

# Underline
s,§n,\o33[4m,g

# Italic
s,§o,\o33[3m,g
