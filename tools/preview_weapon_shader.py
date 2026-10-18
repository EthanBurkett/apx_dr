"""Render the actual compiled CoD4 M9 shaders on a hidden D3D9 device."""
import ctypes as C
from pathlib import Path
import struct,math,json,io,zipfile,sys,argparse,os
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
U=C.c_uint;I=C.c_int;P=C.c_void_p;F=C.c_float
W,H=2048,1024

def call(obj,index,types,*args):
    table=C.cast(obj,C.POINTER(C.POINTER(P))).contents
    function=C.WINFUNCTYPE(C.c_long,P,*types)(table[index])
    result=function(obj,*args)
    if result<0:raise RuntimeError(f'D3D9 method {index}: HRESULT {result&0xffffffff:08x}')
    return result

def create(obj,index,types,*args):
    result=P();call(obj,index,[*types,C.POINTER(P),P],*args,C.byref(result),None);return result

def release(obj):
    if obj:call(obj,2,[])

class Parameters(C.Structure):
    _fields_=[('width',U),('height',U),('format',U),('count',U),('multisample',U),
              ('quality',U),('swap',U),('window',P),('windowed',I),('autoDepth',I),
              ('depthFormat',U),('flags',U),('refresh',U),('interval',U)]
class LockRect(C.Structure):
    _fields_=[('pitch',I),('bits',P)]
class LockBox(C.Structure):
    _fields_=[('row',I),('slice',I),('bits',P)]
class Element(C.Structure):
    _fields_=[('stream',C.c_ushort),('offset',C.c_ushort),('type',C.c_ubyte),
              ('method',C.c_ubyte),('usage',C.c_ubyte),('index',C.c_ubyte)]

def constant(device,index,register,values):
    data=(F*len(values))(*values)
    call(device,index,[U,P,U],register,data,len(values)//4)

def shader(device,stage,name):
    # Match the normal builder's compiler, entry point, profile and optimization
    # flags. Authoring therefore previews current HLSL, not a stale cached binary.
    path=ROOT/f'src/shaders/{stage}_3_0_{name}.hlsl'
    source=path.read_bytes();code=P();errors=P()
    compiler=C.WinDLL('d3dcompiler_47').D3DCompile
    compiler.argtypes=[P,C.c_size_t,C.c_char_p,P,P,C.c_char_p,C.c_char_p,U,U,C.POINTER(P),C.POINTER(P)]
    compiler.restype=C.c_long
    result=compiler(source,len(source),str(path).encode(),None,None,
                    (stage+'_main').encode(),(stage+'_3_0').encode(),1<<15,0,C.byref(code),C.byref(errors))
    def contents(blob):
        table=C.cast(blob,C.POINTER(C.POINTER(P))).contents
        pointer=C.WINFUNCTYPE(P,P)(table[3])(blob)
        size=C.WINFUNCTYPE(C.c_size_t,P)(table[4])(blob)
        return C.string_at(pointer,size)
    if result<0:
        message=contents(errors).decode(errors='replace') if errors else 'HLSL compile failed'
        release(errors);release(code);raise RuntimeError(message)
    buffer=C.create_string_buffer(contents(code));output=P()
    try:call(device,91 if stage=='vs' else 106,[P,C.POINTER(P)],buffer,C.byref(output))
    finally:release(errors);release(code)
    return output

def iwi_image(data):
    fmt=data[4];w,h=struct.unpack_from('<2H',data,6)
    if fmt==1:return Image.frombytes('RGBA',(w,h),data[-w*h*4:],'raw','BGRA')
    code={11:b'DXT1',12:b'DXT3',13:b'DXT5'}[fmt]
    size=((w+3)//4)*((h+3)//4)*(8 if fmt==11 else 16)
    header=struct.pack('<31I',124,0x81007,h,w,size,0,1,*([0]*11),32,4,
                       struct.unpack('<I',code)[0],0,0,0,0,0,0x1000,0,0,0,0)
    return Image.open(io.BytesIO(b'DDS '+header+data[-size:])).convert('RGBA')

def stock_image(name):
    for archive_path in sorted((ROOT.parent.parent/'main').glob('*.iwd')):
        with zipfile.ZipFile(archive_path) as archive:
            path='images/'+name+'.iwi'
            if path in archive.namelist():return iwi_image(archive.read(path))
    raise FileNotFoundError(name)

def texture(device,image):
    image=image.convert('RGBA')
    obj=create(device,23,[U,U,U,U,U,U],image.width,image.height,1,0,21,1)
    rect=LockRect();call(obj,19,[U,C.POINTER(LockRect),P,U],0,C.byref(rect),None,0)
    data=image.tobytes('raw','BGRA');row=image.width*4
    for y in range(image.height):C.memmove(rect.bits+y*rect.pitch,data[y*row:(y+1)*row],row)
    call(obj,20,[U],0);return obj

def cube_texture(device):
    obj=create(device,25,[U,U,U,U,U],16,1,0,21,1)
    for face in range(6):
        image=Image.new('RGBA',(16,16));pixels=[]
        for y in range(16):
            for x in range(16):
                shine=max(0,1-abs(y-5)/4)*max(0,1-abs(x-8)/12)
                colors=((35,60,100),(70,40,110),(140,170,220),(15,20,35),(45,70,105),(90,100,120))[face]
                pixels.append(tuple(min(255,int(c*(.65+shine*.7))) for c in colors)+(255,))
        image.putdata(pixels)
        rect=LockRect();call(obj,19,[U,U,C.POINTER(LockRect),P,U],face,0,C.byref(rect),None,0)
        data=image.tobytes('raw','BGRA')
        for y in range(16):C.memmove(rect.bits+y*rect.pitch,data[y*64:(y+1)*64],64)
        call(obj,20,[U,U],face,0)
    return obj

def volume_texture(device):
    obj=create(device,24,[U,U,U,U,U,U,U],1,1,1,1,0,21,1)
    box=LockBox();call(obj,19,[U,C.POINTER(LockBox),P,U],0,C.byref(box),None,0)
    C.memmove(box.bits,bytes((145,128,118,255)),4);call(obj,20,[U],0);return obj

def normalize(v):
    d=math.sqrt(sum(c*c for c in v));return [c/d for c in v]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def multiply(a,b):
    return [[sum(a[r][k]*b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]
def transpose_values(m):return [m[r][c] for c in range(4) for r in range(4)]

def render(args):
    user=C.WinDLL('user32');user.CreateWindowExW.restype=P
    user.CreateWindowExW.argtypes=[U,C.c_wchar_p,C.c_wchar_p,U,I,I,I,I,P,P,P,P]
    window=user.CreateWindowExW(0,'STATIC','ApX shader preview',0x80000000,0,0,1,1,None,None,None,None)
    if not window:raise RuntimeError('Cannot create hidden render window')
    library=C.WinDLL('d3d9');library.Direct3DCreate9.argtypes=[U];library.Direct3DCreate9.restype=P
    d3d=library.Direct3DCreate9(32);device=P()
    pp=Parameters(W,H,0,1,0,0,1,window,1,0,0,0,0,0x80000000)
    call(d3d,16,[U,U,P,U,C.POINTER(Parameters),C.POINTER(P)],0,1,window,0x20,C.byref(pp),C.byref(device))
    target=create(device,28,[U,U,U,U,U,I],W,H,21,0,0,0)
    depth=create(device,29,[U,U,U,U,U,I],W,H,75,0,0,1)
    call(device,37,[U,P],0,target);call(device,39,[P],depth)
    elements=(Element*5)(Element(0,0,2,0,0,0),Element(0,12,4,0,10,0),
        Element(0,16,5,0,5,0),Element(0,20,5,0,3,0),Element(255,0,17,0,0,0))
    declaration=P();call(device,86,[P,C.POINTER(P)],elements,C.byref(declaration));call(device,87,[P],declaration)
    vertex=shader(device,'vs','apx_rift_weapon')
    body=shader(device,'ps','apx_rift_body');corona=shader(device,'ps','apx_rift_corona')
    call(device,92,[P],vertex)
    textures={0:texture(device,stock_image('weapon_beretta_c')),1:cube_texture(device),
        2:texture(device,Image.open(ROOT/'art/weapons/beretta-rift/camo-fields.png')),
        4:volume_texture(device),
        5:texture(device,stock_image('~weapon_beretta_s-r-17g-17b-1~41155d1b'))}
    for slot,obj in textures.items():
        call(device,65,[U,P],slot,obj)
        for state,value in ((1,1),(2,1),(3,1),(5,2),(6,2),(7,0)):
            call(device,69,[U,U,U],slot,state,value)
    meshes=json.loads(args.mesh.read_text())
    encoded=bytearray()
    for row in meshes:
        position=row[:3];normal=row[3:6];u,v=row[6:8]
        encoded.extend(struct.pack('<3fI',*position,0xffffffff))
        encoded.extend(struct.pack('<ee',v,u))
        encoded.extend(bytes([max(0,min(255,round((n+1)*127))) for n in normal]+[63]))
    stream=C.create_string_buffer(bytes(encoded))
    lo=[min(v[a] for v in meshes) for a in range(3)];hi=[max(v[a] for v in meshes) for a in range(3)]
    center=[(a+b)/2 for a,b in zip(lo,hi)];scale=1/max(b-a for a,b in zip(lo,hi))
    def camera(angle):
        cosine,sine=math.cos(angle),math.sin(angle)
        eye=[.45*cosine+1.7*sine,.45*sine-1.7*cosine,.48]
        z=normalize([-v for v in eye]);x=normalize(cross([0,0,1],z));y=cross(z,x)
        view=[[x[0],y[0],z[0],0],[x[1],y[1],z[1],0],[x[2],y[2],z[2],0],[0,0,0,1]]
        focal=1/math.tan(math.radians(40 if args.turntable else 24)/2);near=.01;far=100
        projection=[[focal/(W/H),0,0,0],[0,focal,0,0],[0,0,far/(far-near),1],[0,0,-near*far/(far-near),0]]
        world=[[scale,0,0,0],[0,scale,0,0],[0,0,scale,0],[-center[a]*scale-eye[a] for a in range(3)]+[1]]
        constant(device,94,0,transpose_values(multiply(view,projection)))
        constant(device,94,4,transpose_values(world))
    constant(device,94,8,[.5,.5,.5,0])
    constant(device,94,21,[0,0,0,0])
    constant(device,109,0,[0,0,0,0]);constant(device,109,5,[0,0,0,0]);constant(device,109,6,[.8,2,1,.625])
    readback=create(device,36,[U,U,U,U],W,H,21,2)
    out=args.frames_directory;out.mkdir(parents=True,exist_ok=True)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    count=32 if args.turntable else args.frames
    for frame in range(count):
        camera(-math.tau*frame/count if args.turntable else 0.0)
        time=args.start_time if args.turntable else frame/args.fps+args.start_time
        constant(device,94,22,[time,time,time,time])
        call(device,43,[U,P,U,U,F,U],0,None,3,0,1.0,0)
        for state,value in ((7,1),(14,1),(23,4),(22,1),(27,0),(168,15)):
            call(device,57,[U,U],state,value)
        call(device,41,[])
        call(device,107,[P],body);call(device,83,[U,U,P,U],4,len(meshes)//3,stream,24)
        call(device,57,[U,U],14,0);call(device,57,[U,U],27,1)
        call(device,57,[U,U],19,2);call(device,57,[U,U],20,2)
        call(device,107,[P],corona);call(device,83,[U,U,P,U],4,len(meshes)//3,stream,24)
        call(device,42,[]);call(device,32,[P,P],target,readback)
        rect=LockRect();call(readback,13,[C.POINTER(LockRect),P,U],C.byref(rect),None,0x10)
        data=b''.join(C.string_at(rect.bits+y*rect.pitch,W*4) for y in range(H))
        call(readback,14,[])
        image=Image.frombytes('RGBA',(W,H),data,'raw','BGRA').resize((args.width,args.width//2),Image.Resampling.LANCZOS)
        image.save(out/(str(frame)+'.png'))
        if frame==0:image.save(args.output)
    print('Rendered',count,'frames through the actual compiled D3D9 shaders.')
    for obj in [readback,*textures.values(),body,corona,vertex,declaration,depth,target,device,d3d]:release(obj)
    user.DestroyWindow.argtypes=[P];user.DestroyWindow(window)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mesh',type=Path,default=ROOT/'build/shader-lab/m9-mesh.json')
    parser.add_argument('--output',type=Path,default=ROOT/'build/shader-lab/rift-preview.png')
    parser.add_argument('--frames-directory',type=Path,default=ROOT/'build/shader-lab/frames')
    parser.add_argument('--frames',type=int,default=1)
    parser.add_argument('--width',type=int,default=1024)
    parser.add_argument('--fps',type=float,default=24.0)
    parser.add_argument('--start-time',type=float,default=3.0)
    parser.add_argument('--turntable',action='store_true',help='32 fixed-time camera angles for the catalog.')
    args=parser.parse_args()
    if os.name!='nt':parser.error('The shader preview requires Windows Direct3D 9.')
    if not 1<=args.frames<=240 or not 1<=args.fps<=60:parser.error('frames must be 1..240 and fps 1..60')
    if args.width<128 or args.width>2048 or args.width%2:parser.error('width must be an even value in 128..2048')
    render(args)

if __name__=='__main__':main()
