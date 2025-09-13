#!/usr/bin/env python3
import sys, re, pathlib, shutil

# Map by extension to comment syntax
LINE = {
  '.gnu':'#', '.gp':'#', '.gpl':'#', '.py':'#', '.sh':'#', '.bash':'#',
  '.mdp':';','.top':';','.itp':';','.ndx':';','.slurm':'#','.sbatch':'#',
  '.dat':None,'.csv':None,'.xvg':'@', '.in':None,'.r':'#','.R':'#',
}
BLOCK = {'.c':'/* */','.cpp':'/* */','.h':'/* */','.js':'/* */'}

def strip_lines(text, marker):
    out = []
    for line in text.splitlines():
        if marker is None:
            out.append(line)
        else:
            # keep shebangs
            if line.startswith('#!'): out.append(line); continue
            # drop full-line comments and trailing comments
            s=line
            if s.strip().startswith(marker): continue
            if marker in s:
                # careful: allow URLs in CSV, so only use for codey types
                s = s.split(marker,1)[0]
            out.append(s.rstrip())
    return '\n'.join(out) + '\n'

def strip_blocks(text, start='/*', end='*/'):
    return re.sub(re.compile(r'/\*.*?\*/', re.S), '', text)

def process_file(p):
    ext = p.suffix.lower()
    raw = p.read_text(errors='ignore')
    out = raw
    if ext in LINE and LINE[ext] is not None:
        out = strip_lines(out, LINE[ext])
    if ext in BLOCK:
        out = strip_blocks(out)
    # save original beside destination as .orig once
    orig = p.with_suffix(p.suffix + '.orig')
    if not orig.exists():
        shutil.copy2(p, orig)
    p.write_text(out)

if __name__ == '__main__':
    for arg in sys.argv[1:]:
        p = pathlib.Path(arg)
        if p.is_file(): process_file(p)

