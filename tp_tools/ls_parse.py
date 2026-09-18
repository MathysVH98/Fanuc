"""Parser for FANUC .LS (ASCII teach-pendant listing) files."""
import re

class Pos:
    __slots__=('num','uf','ut','config','kind','vals')
    def __init__(self,num,uf,ut,config,kind,vals):
        self.num,self.uf,self.ut,self.config,self.kind,self.vals=num,uf,ut,config,kind,vals
    def __repr__(self):
        return f'P[{self.num}] {self.kind} uf={self.uf} ut={self.ut} cfg={self.config!r} {self.vals}'

class LSProgram:
    def __init__(self):
        self.name=None; self.attr={}; self.tcd={}; self.appl_raw=[]
        self.lines=[]      # list of (lineno, text_without_trailing_semicolon)
        self.positions=[]  # list of Pos

def parse(path):
    txt=open(path,encoding='latin-1').read()
    T=txt.splitlines()
    p=LSProgram()
    m=re.match(r'/PROG\s+(\S+)', T[0]); p.name=m.group(1)
    i_attr=T.index('/ATTR')
    i_appl=next((i for i,x in enumerate(T) if x.startswith('/APPL')), None)
    i_mn  =T.index('/MN')
    i_pos =next(i for i,x in enumerate(T) if x.startswith('/POS'))
    i_end =next(i for i,x in enumerate(T) if x.startswith('/END'))

    # ---- /ATTR ----
    in_tcd=False
    for ln in T[i_attr+1:(i_appl if i_appl else i_mn)]:
        s=ln.strip()
        if not s: continue
        if s.startswith('TCD:'):
            in_tcd=True; s=s[4:].strip()
        if in_tcd:
            for k,v in re.findall(r'(\w+)\s*=\s*([^,;]+)', s):
                p.tcd[k]=v.strip()
            if s.endswith(';'): in_tcd=False
            continue
        mm=re.match(r'([A-Z_]+)\s*=\s*(.*?);\s*$', s)
        if mm: p.attr[mm.group(1)]=mm.group(2).strip()

    # ---- /APPL (kept verbatim; semantics handled by meta codec) ----
    if i_appl is not None:
        p.appl_raw=T[i_appl+1:i_mn]

    # ---- /MN ----
    for ln in T[i_mn+1:i_pos]:
        mm=re.match(r'\s*(\d+):\s?(.*?)\s*;\s*$', ln)
        if mm:
            p.lines.append((int(mm.group(1)), mm.group(2)))
        elif ln.strip():
            raise ValueError('unparsed /MN line: %r' % ln)

    # ---- /POS ----
    blob='\n'.join(T[i_pos+1:i_end])
    for m in re.finditer(r'P\[(\d+)\]\{(.*?)\n\};', blob, re.S):
        num=int(m.group(1)); body=m.group(2)
        uf=int(re.search(r'UF\s*:\s*(\d+)',body).group(1))
        ut=int(re.search(r'UT\s*:\s*(\d+)',body).group(1))
        cm=re.search(r"CONFIG\s*:\s*'([^']*)'",body)
        cfg=cm.group(1) if cm else None
        if cfg is None:
            vals=[float(x) for x in re.findall(r'J\d\s*=\s*(-?[\d.]+)\s*deg',body)]
            kind='JOINT'
        else:
            vals=[float(re.search(r'%s\s*=\s*(-?[\d.]+)'%k,body).group(1))
                  for k in ('X','Y','Z','W','P','R')]
            kind='CART'
        assert len(vals)==6, (num,body)
        p.positions.append(Pos(num,uf,ut,cfg,kind,vals))
    return p
