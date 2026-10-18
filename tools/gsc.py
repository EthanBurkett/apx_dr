"""Small GSC source inspector. This is deliberately not an engine compiler."""
from dataclasses import dataclass
import re


def mask(text, strings=True):
    """Blank comments/string contents while preserving offsets and newlines."""
    pattern = r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"'
    def replace(match):
        value = match.group()
        if value.startswith('"') and not strings:
            return value
        return ''.join('\n' if char == '\n' else ' ' for char in value)
    return re.sub(pattern, replace, text)


@dataclass
class Function:
    name: str
    params: str
    start: int
    body_start: int
    end: int


def functions(text):
    code = mask(text)
    result = []
    depth = 0
    position = 0
    pattern = re.compile(r'(?m)^[ \t]*([A-Za-z_]\w*)[ \t]*\(([^{};]*?)\)\s*\{')
    for match in pattern.finditer(code):
        if match.start() < position:
            continue
        depth += code[position:match.start()].count('{') - code[position:match.start()].count('}')
        if depth != 0:
            continue
        opening = match.end() - 1
        nesting = 1
        end = opening + 1
        while end < len(code) and nesting:
            nesting += (code[end] == '{') - (code[end] == '}')
            end += 1
        if nesting:
            raise ValueError(f'Unclosed function {match[1]}')
        result.append(Function(match[1], text[match.start(2):match.end(2)].strip(),
                               match.start(), opening, end))
        position = end
    return result


def qualify(text, owners, current):
    """Qualify cross-module calls/references, without rewriting comments or strings."""
    code = mask(text)
    edits = []
    for match in re.finditer(r'\b([A-Za-z_]\w*)\s*(?=\()', code):
        name = match[1].lower()
        if name not in owners or owners[name] == current:
            continue
        prefix = code[:match.start()].rstrip()
        if prefix.endswith('::') or prefix.endswith('\\'):
            continue
        edits.append((match.start(), owners[name] + '::'))
    # Local function pointers have no following parentheses.
    for match in re.finditer(r'(?<![\w\\])::([A-Za-z_]\w*)', code):
        name = match[1].lower()
        if name in owners and owners[name] != current:
            edits.append((match.start(), owners[name]))
    for offset, value in sorted(edits, reverse=True):
        text = text[:offset] + value + text[offset:]
    return text
