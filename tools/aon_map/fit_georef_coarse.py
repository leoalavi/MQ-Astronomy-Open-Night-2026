import numpy as np
from PIL import Image

MQ  = "/Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/maps/mq-campus.png"
AON = "aon_hi-1.png"
W,H = 4678,3307

def edge_img(path, size):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, (255,255,255,255))
    im = Image.alpha_composite(bg, im).convert("L").resize(size, Image.LANCZOS)
    a = np.asarray(im, np.float32)/255.
    gy,gx = np.gradient(a)
    return np.hypot(gx,gy)

def xcorr_peak(a, b):
    """best translation of b within a (both same shape, zero-padded)."""
    A = np.fft.rfft2(a); B = np.fft.rfft2(b)
    c = np.fft.irfft2(A*np.conj(B), s=a.shape)
    idx = np.unravel_index(np.argmax(c), c.shape)
    dy, dx = idx
    if dy > a.shape[0]//2: dy -= a.shape[0]
    if dx > a.shape[1]//2: dx -= a.shape[1]
    return float(c[idx]), dx, dy

def run(f, srange):
    w,h = W//f, H//f
    P = (h*2, w*2)                      # pad to avoid wraparound
    mq  = edge_img(MQ,  (w,h))
    aon_full = Image.open(AON).convert("L")
    best=None
    for s in srange:
        sw,sh = int(round(w*s)), int(round(h*s))
        a = aon_full.resize((sw,sh), Image.LANCZOS)
        aa = np.asarray(a,np.float32)/255.
        gy,gx = np.gradient(aa); ae = np.hypot(gx,gy)
        pa = np.zeros(P,np.float32); pm = np.zeros(P,np.float32)
        pa[:min(sh,P[0]),:min(sw,P[1])] = ae[:P[0],:P[1]]
        pm[:h,:w] = mq
        pa -= pa.mean(); pm -= pm.mean()
        pa /= (np.linalg.norm(pa)+1e-9); pm /= (np.linalg.norm(pm)+1e-9)
        sc,dx,dy = xcorr_peak(pm, pa)
        if best is None or sc>best[0]: best=(sc,s,dx,dy)
    return best

coarse = run(8, np.arange(0.80,1.31,0.02))
print("coarse f=8:", f"score={coarse[0]:.4f} scale={coarse[1]:.3f} dx={coarse[2]} dy={coarse[3]}")
s0 = coarse[1]
fine = run(4, np.arange(s0-0.04, s0+0.041, 0.005))
print("fine  f=4:", f"score={fine[0]:.4f} scale={fine[1]:.4f} dx={fine[2]} dy={fine[3]}")
s1 = fine[1]
finer = run(2, np.arange(s1-0.008, s1+0.0081, 0.002))
print("finer f=2:", f"score={finer[0]:.4f} scale={finer[1]:.4f} dx={finer[2]} dy={finer[3]}")
s,dx,dy = finer[1], finer[2]*2, finer[3]*2
print(f"\n=> AON(full 4680x3310 render) scaled by {s:.4f} then translated ({dx:+d},{dy:+d}) lands on MQ 4678x3307 space")
