"""Protect mip payloads and import conflict checks when reducing runtime images."""
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import optimize_content_images as images
import import_content as importer


def mip_image():
    lengths=[];size=2048
    while True:
        lengths.append(max(1,(size+3)//4)**2*16)
        if size==1: break
        size=max(1,size//2)
    header=bytearray(28);header[:6]=b'IWi\x06\x0d\x01'
    struct.pack_into('<3H',header,6,2048,2048,1)
    struct.pack_into('<4I',header,12,*(28+sum(lengths[p:]) for p in range(4)))
    levels=[bytes([index])*length for index,length in enumerate(lengths)]
    return bytes(header)+b''.join(reversed(levels)),levels


class TextureOptimizationTests(unittest.TestCase):
    def test_trim_keeps_smaller_compressed_mips_verbatim(self):
        source,levels=mip_image();result=images.trim(source)
        self.assertEqual(struct.unpack_from('<2H',result,6),(1024,1024))
        self.assertEqual(result[28:],b''.join(reversed(levels[1:])))
        self.assertEqual(struct.unpack_from('<I',result,12)[0],len(result))
        self.assertEqual(images.trim(result),result)

    def test_unsupported_and_malformed_images_are_not_silently_changed(self):
        source,_=mip_image()
        cube=bytearray(source);cube[5]|=4
        self.assertEqual(images.trim(cube),cube)
        with self.assertRaises(ValueError): images.trim(source[:-16])
        self.assertEqual(images.trim(b'not an image'),b'not an image')

    def test_import_reuses_only_matching_original_and_optimized_hashes(self):
        source,_=mip_image();optimized=images.trim(source)
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);assets=root/'assets';stage=root/'stage'
            (assets/'images').mkdir(parents=True);(stage/'pack').mkdir(parents=True)
            prior=assets/'images/test.iwi';prior.write_bytes(optimized)
            incoming=stage/'pack/test.iwi';incoming.write_bytes(source)
            registry=root/'optimization.json'
            registry.write_text(json.dumps({'test.iwi':{'originalSHA256':images.sha(source),'outputSHA256':images.sha(optimized)}}))
            with patch.multiple(importer,ASSETS=assets,GAME=root/'game',STAGE=stage,OPTIMIZATION=registry):
                record={'id':'pack','files':{'images/test.iwi':'test.iwi'}}
                pack=importer.Pack(record);pack.add('images/test.iwi')
                self.assertFalse(pack.selected)
                self.assertEqual(prior.read_bytes(),optimized)
                incoming.write_bytes(source+b'unrelated replacement')
                with self.assertRaisesRegex(ValueError,'Conflicting asset'):
                    importer.Pack(record).add('images/test.iwi')


if __name__=='__main__': unittest.main()
