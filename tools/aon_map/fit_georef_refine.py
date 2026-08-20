import numpy as np
from PIL import Image
W,H=4678,3307
S,DX,DY = 1.0250, -252, -74     # seed: AON_render -> MQ frame

def edges(im):
    a=np.asarray(im.convert("L"),np.float32)/255.
    gy,gx=np.gradient(a); return np.hypot(gx,gy)

mq_im = Image.open("/Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/maps/mq-campus.png").convert("RGBA")
mq_im = Image.alpha_composite(Image.new("RGBA",mq_im.size,(255,255,255,255)),mq_im)
E_mq  = edges(mq_im)
E_w   = edges(Image.open("aon_warped.png"))

def ncc(tpl,img,x0,y0,rad):
    th,tw=tpl.shape; t=tpl-tpl.mean(); tn=np.linalg.norm(t)
    if tn<1e-6: return None
    best=(-2,0,0)
    for y in range(max(0,y0-rad),min(img.shape[0]-th,y0+rad)+1):
        for x in range(max(0,x0-rad),min(img.shape[1]-tw,x0+rad)+1):
            w=img[y:y+th,x:x+tw]; w=w-w.mean(); wn=np.linalg.norm(w)
            if wn<1e-6: continue
            c=float((t*w).sum()/(tn*wn))
            if c>best[0]: best=(c,x,y)
    return best

T=180; RAD=45
src=[]; dst=[]; scores=[]
for fx in np.arange(0.16,0.95,0.055):
    for fy in np.arange(0.10,0.95,0.075):
        x0,y0=int(fx*W),int(fy*H)
        if x0+T>W or y0+T>H: continue
        tpl=E_w[y0:y0+T,x0:x0+T]
        if tpl.std()<0.012: continue
        b=ncc(tpl,E_mq,x0,y0,RAD)
        if b is None: continue
        c,mx,my=b
        if c<0.55: continue
        # centre of patch in warped frame -> back to ORIGINAL aon render coords
        wx,wy = x0+T/2, y0+T/2
        ax,ay = (wx-DX)/S, (wy-DY)/S
        src.append((ax,ay)); dst.append((mx+T/2, my+T/2)); scores.append(c)

src=np.array(src); dst=np.array(dst); scores=np.array(scores)
print(f"{len(src)} confident correspondences (ncc>=0.55), mean ncc={scores.mean():.3f}")

def fit(src,dst):
    A=np.zeros((2*len(src),6)); b=np.zeros(2*len(src))
    for i,(x,y) in enumerate(src):
        A[2*i]  =[x,y,1,0,0,0]; b[2*i]  =dst[i,0]
        A[2*i+1]=[0,0,0,x,y,1]; b[2*i+1]=dst[i,1]
    p,*_=np.linalg.lstsq(A,b,rcond=None); return p

def resid(p,src,dst):
    px=p[0]*src[:,0]+p[1]*src[:,1]+p[2]; py=p[3]*src[:,0]+p[4]*src[:,1]+p[5]
    return np.hypot(px-dst[:,0],py-dst[:,1])

p=fit(src,dst); r=resid(p,src,dst)
# robust: drop worst 20%
for _ in range(3):
    keep=r<=np.percentile(r,80)
    p=fit(src[keep],dst[keep]); r_all=resid(p,src,dst); r=r_all
    src_k,dst_k=src[keep],dst[keep]
rk=resid(p,src_k,dst_k)
print(f"\nrobust affine on {len(src_k)} inliers")
print(f"  residual px: mean={rk.mean():.2f} median={np.median(rk):.2f} p95={np.percentile(rk,95):.2f} max={rk.max():.2f}")
print(f"  a=[{p[0]:.6f}, {p[1]:.6f}, {p[2]:.4f}]")
print(f"  b=[{p[3]:.6f}, {p[4]:.6f}, {p[5]:.4f}]")
sx=np.hypot(p[0],p[3]); sy=np.hypot(p[1],p[4])
rot=np.degrees(np.arctan2(p[3],p[0])); shear=np.degrees(np.arctan2(-p[1],p[4]))-rot
print(f"  => scale x={sx:.5f} y={sy:.5f}   rotation={rot:.4f}deg  shear={shear:.4f}deg")
np.save("affine.npy",p)
