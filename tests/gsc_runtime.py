"""Scalar GSC test interpreter for pure decision functions, not a CoD4x emulator.

Executes the actual source statements used by selection, bounds and rotation
tests. Engine calls are explicit test doubles. Unsupported syntax fails loudly.
"""
import ast
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from gsc import functions, mask


class Flow(Exception):
    def __init__(self, kind, value=None):
        self.kind, self.value = kind, value


class Array(dict):
    def __getitem__(self, key):
        return self.get(key)


class Parser:
    precedence = {'=': 1, '+=': 1, '-=': 1, '||': 2, '&&': 3, '==': 4,
                  '!=': 4, '<': 5, '>': 5, '<=': 5, '>=': 5,
                  '+': 6, '-': 6, '*': 7, '/': 7, '%': 7}

    def __init__(self, text):
        self.tokens = re.findall(r'"(?:\\.|[^"\\])*"|\d+(?:\.\d+)?|[A-Za-z_][\w\\]*(?:::\w+)?|\+\+|--|\+=|-=|==|!=|<=|>=|&&|\|\||[^\s]', mask(text, strings=False))
        self.index = 0

    def peek(self):
        return self.tokens[self.index] if self.index < len(self.tokens) else ''

    def take(self, expected=None):
        value = self.peek()
        if not value or (expected is not None and value != expected):
            raise ValueError(f'Expected {expected}, got {value} near {self.tokens[max(0,self.index-5):self.index+5]}')
        self.index += 1
        return value

    def statement(self):
        token = self.peek()
        if token == '{':
            self.take(); statements = []
            while self.peek() != '}': statements.append(self.statement())
            self.take('}')
            return ('block', statements)
        if token == 'if':
            self.take(); self.take('('); condition = self.expression(); self.take(')')
            yes = self.statement(); no = ('block', [])
            if self.peek() == 'else': self.take(); no = self.statement()
            return ('if', condition, yes, no)
        if token == 'for':
            self.take(); self.take('('); init = self.expression(); self.take(';')
            condition = self.expression(); self.take(';'); step = self.expression(); self.take(')')
            return ('for', init, condition, step, self.statement())
        if token == 'while':
            self.take(); self.take('('); condition = self.expression(); self.take(')')
            return ('while', condition, self.statement())
        if token in ('return', 'continue', 'break'):
            self.take(); value = self.expression() if token == 'return' and self.peek() != ';' else ('literal', None)
            self.take(';')
            return (token, value)
        if token == ';': self.take(); return ('block', [])
        value = self.expression(); self.take(';')
        return ('expr', value)

    def arguments(self):
        self.take('('); args = []
        while self.peek() != ')':
            args.append(self.expression())
            if self.peek() != ',': break
            self.take(',')
        self.take(')')
        return args

    def expression(self, minimum=0):
        token = self.take()
        if token in ('!', '-', '+'): left = ('unary', token, self.expression(9))
        elif token == '(':
            left = self.expression()
            if self.peek() == ',':
                items = [left]
                while self.peek() == ',': self.take(','); items.append(self.expression())
                left = ('tuple', items)
            self.take(')')
        elif token == '[':
            self.take(']'); left = ('array',)
        elif token.startswith('"'): left = ('literal', ast.literal_eval(token))
        elif token[0].isdigit(): left = ('literal', float(token) if '.' in token else int(token))
        elif token in ('true', 'false', 'undefined'): left = ('literal', {'true': True, 'false': False, 'undefined': None}[token])
        else: left = ('variable', token)
        while self.peek():
            token = self.peek()
            if token == '.':
                self.take(); left = ('member', left, ('literal', self.take())); continue
            if token == '[':
                self.take(); key = self.expression(); self.take(']'); left = ('member', left, key); continue
            if token == '(':
                left = ('call', left, self.arguments()); continue
            if token in ('++', '--'):
                self.take(); left = ('increment', left, 1 if token == '++' else -1); continue
            if re.fullmatch(r'[A-Za-z_][\w\\]*(?:::\w+)?', token) and self.index + 1 < len(self.tokens) and self.tokens[self.index + 1] == '(':
                self.take(); left = ('method', left, token, self.arguments()); continue
            priority = self.precedence.get(token, -1)
            if priority < minimum: break
            self.take(); right = self.expression(priority if token in ('=', '+=', '-=') else priority + 1)
            left = ('assign' if token in ('=', '+=', '-=') else 'binary', token, left, right)
        return left


class Runtime:
    def __init__(self, globals=None, natives=None):
        self.globals = globals or {}
        self.natives = {'isDefined': lambda value: value is not None, 'int': int, 'float': float,
                        'isString': lambda value: isinstance(value, str), 'strTok': lambda value, separator: [part for part in value.split(separator) if part],
                        'randomInt': lambda size: 0, 'getEntityNumber': lambda self: self['number'],
                        'getStat': lambda self, number: self.get('stats', {}).get(number, 0),
                        'isPlayer': lambda value: isinstance(value, dict) and value.get('is_player', False),
                        **(natives or {})}
        self.definitions = {}
        self.steps = 0

    def load(self, path, names):
        text = Path(path).read_text(encoding='cp1252')
        for fn in functions(text):
            if fn.name in names:
                self.definitions[fn.name] = ([param.strip() for param in fn.params.split(',') if param.strip()],
                                            Parser(text[fn.body_start:fn.end]).statement())

    def call(self, name, *arguments, receiver=None):
        self.steps += 1
        if self.steps > 100000: raise RuntimeError('GSC decision function exceeded test execution budget')
        # Engine function names are case-insensitive.
        name = next((key for key in [*self.natives, *self.definitions] if key.lower() == name.lower()), name)
        if name in self.natives:
            return self.natives[name](*(([receiver] if receiver is not None else []) + list(arguments)))
        parameters, body = self.definitions[name]
        environment = {**self.globals, 'self': receiver, **dict(zip(parameters, arguments))}
        try: self.run(body, environment)
        except Flow as flow:
            if flow.kind == 'return': return flow.value
            raise

    def get(self, obj, key):
        if key == 'size': return len(obj)
        if isinstance(obj, dict): return obj.get(key)
        if isinstance(obj, (list, tuple)) and (key < 0 or key >= len(obj)): return None
        return obj[key]

    def reference(self, node, env):
        if node[0] == 'variable': return env, node[1]
        if node[0] == 'member':
            obj=self.evaluate(node[1], env)
            # GSC creates nested arrays when assigning array[id][field].
            if obj is None:
                parent,key=self.reference(node[1], env)
                obj=Array();parent[key]=obj
            return obj, self.evaluate(node[2], env)
        raise ValueError(f'Not assignable: {node}')

    def evaluate(self, node, env):
        kind = node[0]
        if kind == 'literal': return node[1]
        if kind == 'array': return Array()
        if kind == 'tuple': return tuple(self.evaluate(item, env) for item in node[1])
        if kind == 'variable': return env.get(node[1])
        if kind == 'member': return self.get(self.evaluate(node[1], env), self.evaluate(node[2], env))
        if kind == 'call':
            if node[1][0] != 'variable': raise ValueError('Only named GSC calls are supported')
            return self.call(node[1][1], *[self.evaluate(arg, env) for arg in node[2]], receiver=env.get('self')) if node[1][1] in self.definitions else self.call(node[1][1], *[self.evaluate(arg, env) for arg in node[2]])
        if kind == 'method': return self.call(node[2], *[self.evaluate(arg, env) for arg in node[3]], receiver=self.evaluate(node[1], env))
        if kind == 'unary':
            value = self.evaluate(node[2], env)
            return not value if node[1] == '!' else -value if node[1] == '-' else value
        if kind == 'binary':
            operator = node[1]; left = self.evaluate(node[2], env)
            if operator == '&&': return bool(left) and bool(self.evaluate(node[3], env))
            if operator == '||': return bool(left) or bool(self.evaluate(node[3], env))
            right = self.evaluate(node[3], env)
            return {'==': lambda: left == right, '!=': lambda: left != right,
                    '<': lambda: left < right, '>': lambda: left > right,
                    '<=': lambda: left <= right, '>=': lambda: left >= right,
                    '+': lambda: str(left) + str(right) if isinstance(left, str) or isinstance(right, str) else left + right,
                    '-': lambda: left - right,
                    '*': lambda: left * right, '/': lambda: left / right,
                    '%': lambda: left % right}[operator]()
        if kind == 'assign':
            obj, key = self.reference(node[2], env); value = self.evaluate(node[3], env)
            if node[1] == '+=': value = self.get(obj, key) + value
            if node[1] == '-=': value = self.get(obj, key) - value
            obj[key] = value
            return value
        if kind == 'increment':
            obj, key = self.reference(node[1], env); previous = self.get(obj, key); obj[key] = previous + node[2]
            return previous
        raise ValueError(f'Unsupported GSC expression: {node}')

    def run(self, node, env):
        self.steps += 1
        if self.steps > 100000: raise RuntimeError('GSC decision function exceeded test execution budget')
        kind = node[0]
        if kind == 'block':
            for statement in node[1]: self.run(statement, env)
        elif kind == 'expr': self.evaluate(node[1], env)
        elif kind == 'if': self.run(node[2] if self.evaluate(node[1], env) else node[3], env)
        elif kind in ('return', 'continue', 'break'): raise Flow(kind, self.evaluate(node[1], env))
        elif kind in ('for', 'while'):
            if kind == 'for': self.evaluate(node[1], env)
            condition, body = (node[2], node[4]) if kind == 'for' else (node[1], node[2])
            while self.evaluate(condition, env):
                try: self.run(body, env)
                except Flow as flow:
                    if flow.kind == 'break': break
                    if flow.kind != 'continue': raise
                if kind == 'for': self.evaluate(node[3], env)
        else: raise ValueError(f'Unsupported GSC statement: {node}')
