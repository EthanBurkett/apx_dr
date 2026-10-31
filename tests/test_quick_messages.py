"""Quick-message panels stay compact and preserve native keyboard payloads."""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]


class QuickMessages(unittest.TestCase):
    def test_every_b_menu_page_stays_within_the_left_overlay(self):
        sources=[(ROOT/'src/ui_mp/wm_quickmessage.menu').read_text(),
                 (ROOT/'src/ui_mp/scriptmenus/quickstuff.menu').read_text()]
        pages={}
        for source in sources:
            for block in re.split(r'\bmenuDef\s*\{',source)[1:]:
                name=re.search(r'name "([^"]+)"',block)[1];pages[name]=block
                self.assertIn('fullScreen 0',block)
                self.assertNotIn('nav_',block)
                self.assertNotIn('APX_LOGO',block)
                for rect in re.findall(r'APX_UI_RECT\((\d+),(\d+),(\d+),(\d+),',block):
                    x,y,w,h=map(int,rect)
                    self.assertLessEqual(x+w,228,name)
                    self.assertLessEqual(y+h,424,name)
                    self.assertLessEqual(w*h,640*480*.22,name)
                self.assertRegex(block,r'onEsc \{ close self;')
        self.assertEqual(set(pages),{'quickmessage','quickcommands','quickstatements','quickresponses','quickstuff'})
        for name,count in [('quickcommands',8),('quickstatements',7),('quickresponses',6)]:
            block=pages[name]
            for number in range(1,count+1):
                payload=f'scriptMenuResponse "ui:{name}:{number}"; close self;'
                self.assertEqual(block.count(payload),2)
                self.assertIn(f'execKey "{number}" {{ {payload} }}',block)
            self.assertIn('onEsc { close self; open quickmessage;',block)
        self.assertIn('onEsc { close self; }',pages['quickmessage'])


if __name__=='__main__':unittest.main()
