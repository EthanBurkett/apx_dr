"""Exercise every page/cell/frame of the actual rotation HLSL on hidden D3D9.

Windows only; uses the same compiler/device helpers as weapon previews. Synthetic
frame colors make wrong sampler bindings, page coordinates and tint observable.
No game process, player profile or visible window is used.
"""
import ctypes as C
import struct
from PIL import Image, ImageDraw
from preview_weapon_shader import (P,U,I,F,Parameters,LockRect,call,create,
                                   release,shader,texture)


def frame_color(cell,frame):
    return (16+cell*12,40+frame*6,51+(cell+frame)%10*13,128+(cell+frame)%60)


def main():
    user=C.WinDLL('user32');user.CreateWindowExW.restype=P
    user.CreateWindowExW.argtypes=[U,C.c_wchar_p,C.c_wchar_p,U,I,I,I,I,P,P,P,P]
    window=user.CreateWindowExW(0,'STATIC','ApX page test',0x80000000,0,0,1,1,None,None,None,None)
    if not window:raise RuntimeError('Cannot create hidden GPU test window')
    objects=[]
    try:
        library=C.WinDLL('d3d9');library.Direct3DCreate9.argtypes=[U];library.Direct3DCreate9.restype=P
        d3d=library.Direct3DCreate9(32);objects.append(d3d);device=P()
        pp=Parameters(32,32,0,1,0,0,1,window,1,0,0,0,0,0x80000000)
        call(d3d,16,[U,U,P,U,C.POINTER(Parameters),C.POINTER(P)],0,1,window,0x20,C.byref(pp),C.byref(device))
        objects.append(device)
        target=create(device,28,[U,U,U,U,U,I],32,32,21,0,0,0);objects.append(target)
        readback=create(device,36,[U,U,U,U],32,32,21,2);objects.append(readback)
        call(device,37,[U,P],0,target)
        call(device,89,[U],0x244)  # XYZRHW, diffuse, two float2 texture coordinates
        for state,value in ((7,0),(14,0),(22,1),(27,0),(168,15)):
            call(device,57,[U,U],state,value)
        for stage in range(4):
            for state,value in ((1,3),(2,3),(5,1),(6,1),(7,0)):
                call(device,69,[U,U,U],stage,state,value)
        checks=0
        for group,columns,rows in (('tall',8,4),('wide',4,8)):
            pixel=shader(device,'ps','apx_turntable_'+group);objects.append(pixel)
            pages=[Image.new('RGBA',(128,128)) for _ in range(4)]
            for cell in range(16):
                x,y=cell%4,cell//4;page=x//2+2*(y//2)
                x=(x%2)*64;y=(y%2)*64
                draw=ImageDraw.Draw(pages[page])
                for frame in range(32):
                    a=x+(frame%columns)*64//columns;b=y+(frame//columns)*64//rows
                    draw.rectangle((a,b,a+64//columns-1,b+64//rows-1),fill=frame_color(cell,frame))
            textures=[texture(device,image) for image in pages];objects.extend(textures)
            for stage,obj in enumerate(textures):call(device,65,[U,P],stage,obj)
            call(device,107,[P],pixel)
            for cell in range(16):
                red=round((cell+.5)/16*255);color=(255<<24)|(red<<16)|(255<<8)|255
                for frame in range(32):
                    quad=b''.join(struct.pack('<4fI4f',x,y,0,1,color,u,v,frame,0)
                                  for x,y,u,v in ((-.5,-.5,0,0),(31.5,-.5,1,0),(-.5,31.5,0,1),(31.5,31.5,1,1)))
                    buffer=C.create_string_buffer(quad)
                    call(device,43,[U,P,U,U,F,U],0,None,1,0,1,0)
                    call(device,41,[]);call(device,83,[U,U,P,U],5,2,buffer,36);call(device,42,[])
                    call(device,32,[P,P],target,readback)
                    rect=LockRect();call(readback,13,[C.POINTER(LockRect),P,U],C.byref(rect),None,0x10)
                    bgra=C.string_at(rect.bits+16*rect.pitch+16*4,4)
                    call(readback,14,[])
                    actual=(bgra[2],bgra[1],bgra[0],bgra[3]);expected=frame_color(cell,frame)
                    if any(abs(a-b)>1 for a,b in zip(actual,expected)):
                        raise AssertionError(f'{group} cell {cell}, frame {frame}: {actual} != {expected}')
                    checks+=1
        print(f'PASS: {checks} native GPU page/cell/frame selections; RGB and alpha preserved.')
    finally:
        for obj in reversed(objects):release(obj)
        user.DestroyWindow.argtypes=[P];user.DestroyWindow(window)


if __name__=='__main__':main()
