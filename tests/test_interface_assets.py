"""Rectangular IWI/material integration checks, independent of menu behavior."""
import io
from pathlib import Path
import struct
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


class InterfaceAssets(unittest.TestCase):
    def test_rectangular_button_textures_decode_with_full_mip_chain(self):
        for state in ('idle', 'hover', 'pressed', 'disabled'):
            with self.subTest(state=state):
                name = 'apx_button_'+state
                iwi = (ROOT/'assets/images'/f'{name}.iwi').read_bytes()
                self.assertEqual(iwi[:6], b'IWi\x06\x0d\x01')
                self.assertEqual(struct.unpack_from('<3H',iwi,6), (512,64,1))
                # DXT5 has a 16-byte block for each 4x4 texel region, even at 1px.
                dims = [(max(1,512>>i),max(1,64>>i)) for i in range(10)]
                sizes = [((w+3)//4)*((h+3)//4)*16 for w,h in dims]
                self.assertEqual(len(iwi),28+sum(sizes))
                self.assertEqual(struct.unpack_from('<4I',iwi,12),tuple(28+sum(sizes[i:]) for i in range(4)))
                # Decode the actual engine level-zero payload with Pillow's DDS
                # decoder to catch a malformed block layout, not just a header.
                original = Image.open(ROOT/'art/ui/buttons'/f'{name}.png').convert('RGBA')
                container = io.BytesIO()
                original.save(container,format='DDS',pixel_format='DXT5')
                decoded = Image.open(io.BytesIO(container.getvalue()[:128]+iwi[-sizes[0]:])).convert('RGBA')
                self.assertEqual(decoded.size,(512,64))
                self.assertEqual(decoded.getpixel((0,0))[3],0)
                self.assertGreater(decoded.getpixel((256,32))[3],240)
                self.assertLess(sum(abs(a-b) for a,b in zip(original.getpixel((256,32)),decoded.getpixel((256,32)))),20)
                material = (ROOT/'assets/materials'/name).read_bytes()
                self.assertEqual(struct.unpack_from('<2H',material,24),(512,64))
                texture_offset = struct.unpack_from('<I',material,72)[0]
                self.assertEqual(material[texture_offset:].split(b'\0')[0],name.encode())


if __name__ == '__main__':
    unittest.main()
