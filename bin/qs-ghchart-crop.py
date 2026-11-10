#!/usr/bin/env python3
import sys
import os
import re

def main():
    if len(sys.argv) < 8:
        print("Usage: qs-ghchart-crop.py <raw_svg> <out_svg> <empty_c> <lvl1_c> <lvl2_c> <lvl3_c> <lvl4_c> <text_c> [cutoff_x]")
        sys.exit(1)

    raw_file = sys.argv[1]
    out_file = sys.argv[2]
    empty_c = sys.argv[3]
    lvl1_c = sys.argv[4]
    lvl2_c = sys.argv[5]
    lvl3_c = sys.argv[6]
    lvl4_c = sys.argv[7]
    text_c = sys.argv[8]
    # Default cutoff_x = 327 (May to November = ~6 months)
    cutoff_x = float(sys.argv[9]) if len(sys.argv) > 9 else 327.0

    if not os.path.isfile(raw_file):
        sys.exit(0)

    with open(raw_file, 'r', encoding='utf-8') as f:
        s = f.read()

    if not s or '<svg' not in s:
        sys.exit(0)

    shift_dx = cutoff_x - 27.0
    new_w = max(100.0, 663.0 - shift_dx)

    # Color replacements
    s = s.replace('#eeeeee', empty_c)
    s = s.replace('#c6e48b', lvl1_c)
    s = s.replace('#7bc96f', lvl2_c)
    s = s.replace('#239a3b', lvl3_c)
    s = s.replace('#196127', lvl4_c)
    s = s.replace('#767676', text_c)

    # Clean styling and add valid XML declaration and viewBox
    # Update svg width, height and add viewBox
    s = re.sub(
        r'<svg([^>]*)width=\"[0-9.]+\"([^>]*)height=\"[0-9.]+\"',
        f'<svg\\1width="{int(new_w)}"\\2height="104" viewBox="0 0 {int(new_w)} 104"',
        s,
        count=1
    )

    # Filter & shift rects
    def rect_sub(m):
        x = float(m.group(1))
        if x < cutoff_x:
            return ''
        nx = int(x - shift_dx)
        return m.group(0).replace(f'x="{int(x)}"', f'x="{nx}"')

    s = re.sub(r'<rect[^>]*x=\"([0-9.]+)\"[^>]*/>', rect_sub, s)

    # Filter & shift text
    def text_sub(m):
        x = float(m.group(1))
        if x == 0:
            return m.group(0)  # Keep day labels (Mon, Wed, Fri)
        if x < cutoff_x:
            return ''
        nx = int(x - shift_dx)
        return m.group(0).replace(f'x="{int(x)}"', f'x="{nx}"')

    s = re.sub(r'<text[^>]*x=\"([0-9.]+)\"[^>]*>[^<]+</text>', text_sub, s)

    with open(out_file, 'w', encoding='utf-8') as f:
        f.write(s)

if __name__ == '__main__':
    main()
