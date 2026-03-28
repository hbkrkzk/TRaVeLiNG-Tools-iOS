#!/usr/bin/env python3
from PIL import Image, ImageDraw
import os

# Create 1024x1024 high-quality icon
width, height = 1024, 1024
img = Image.new('RGBA', (width, height), '#F3F4F6')
draw = ImageDraw.Draw(img)

scale = 1024 / 108

# Draw T-shaped logo (dark purple for better contrast)
# M 30 30 L 78 30 L 78 40 L 59 40 L 59 80 L 49 80 L 49 40 L 30 40 Z
points_t = [
    (30 * scale, 30 * scale),
    (78 * scale, 30 * scale),
    (78 * scale, 40 * scale),
    (59 * scale, 40 * scale),
    (59 * scale, 80 * scale),
    (49 * scale, 80 * scale),
    (49 * scale, 40 * scale),
    (30 * scale, 40 * scale),
]
draw.polygon(points_t, fill='#2563EB')  # Blue instead of dark purple

# Draw gradient rectangle (manually gradient effect)
# x=65, y=55, width=20, height=20 -> scaled
rect_x1 = 65 * scale
rect_y1 = 55 * scale
rect_x2 = 85 * scale
rect_y2 = 75 * scale

# Create gradient: Indigo #FF6366F1 to Purple #FF8B5CF6
for y in range(int(rect_y1), int(rect_y2)):
    progress = (y - rect_y1) / (rect_y2 - rect_y1)
    
    # Linear interpolation from Indigo to Purple
    r = int(0xFF * (1 - progress * 0.3))  # 255 -> ~178
    g = int(0x63 * (1 - progress * 0.2))  # ~99 -> ~79
    b = int(0xF1 * (1 - progress * 0.1))  # ~241 -> ~217
    
    color = (r, g, b, int(255 * 0.8))  # 0.8 alpha
    draw.line([(rect_x1, y), (rect_x2, y)], fill=color, width=1)

# Save the icon
output_path = '/Users/traveling/Development/TRaVeLiNG-Tools_iOS/icon-1024-new.png'
img.save(output_path, 'PNG')
print(f"Updated high-quality icon: {output_path}")

