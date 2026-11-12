"""Small JSONC reader/editor retaining text outside the values being changed.

Settings permit comments and trailing commas. Parse their structure rather than
stripping text with regexes, so strings, nested keys, and comments stay intact.
"""
import json
from dataclasses import dataclass, field


@dataclass
class _Value:
    start: int
    end: int
    value: object
    members: dict = field(default_factory=dict)


class _Parser:
    def __init__(self, text):
        self.text = text
        self.pos = 0
        self.decoder = json.JSONDecoder(parse_constant=self.invalid_constant)

    @staticmethod
    def invalid_constant(value):
        raise ValueError("Invalid JSON constant: " + value)

    def space(self):
        while self.pos < len(self.text):
            if self.text[self.pos].isspace():
                self.pos += 1
            elif self.text.startswith("//", self.pos):
                end = self.text.find("\n", self.pos + 2)
                self.pos = len(self.text) if end < 0 else end + 1
            elif self.text.startswith("/*", self.pos):
                end = self.text.find("*/", self.pos + 2)
                if end < 0:
                    raise ValueError("Unterminated JSONC comment")
                self.pos = end + 2
            else:
                break

    def take(self, wanted):
        self.space()
        if not self.text.startswith(wanted, self.pos):
            raise ValueError(f"Expected {wanted!r} at character {self.pos}")
        self.pos += len(wanted)

    def value(self):
        self.space()
        start = self.pos
        if start == len(self.text):
            raise ValueError("Missing JSONC value")
        opening = self.text[start]
        if opening in "{[":
            self.pos += 1
            closing = "}" if opening == "{" else "]"
            result = {} if opening == "{" else []
            members = {}
            self.space()
            if not self.text.startswith(closing, self.pos):
                while True:
                    if opening == "{":
                        self.space()
                        key, end = self.decoder.raw_decode(self.text, self.pos)
                        if not isinstance(key, str):
                            raise ValueError("JSONC object keys must be strings")
                        self.pos = end
                        self.take(":")
                        child = self.value()
                        result[key] = child.value
                        members[key] = child
                    else:
                        result.append(self.value().value)
                    self.space()
                    if self.text.startswith(closing, self.pos):
                        break
                    self.take(",")
                    self.space()
                    if self.text.startswith(closing, self.pos):
                        break  # JSONC permits a trailing comma.
            self.take(closing)
            return _Value(start, self.pos, result, members)
        result, self.pos = self.decoder.raw_decode(self.text, self.pos)
        return _Value(start, self.pos, result)

    def document(self):
        result = self.value()
        self.space()
        if self.pos != len(self.text):
            raise ValueError(f"Unexpected content at character {self.pos}")
        return result


def loads(text):
    return _Parser(text).document().value


def set_property(text, path, value):
    """Set an object property at path, retaining unrelated source bytes.

    Missing/non-object parent values become objects. The full document must be
    valid before any edit is returned; callers can leave malformed files alone.
    """
    if not path:
        raise ValueError("An object property path is required")
    root = _Parser(text).document()
    if not isinstance(root.value, dict):
        raise ValueError("Settings must contain a JSONC object")

    def edit(node, remaining):
        key, *rest = remaining
        child = node.members.get(key)
        if rest and child is not None and isinstance(child.value, dict):
            return edit(child, rest)
        replacement = value
        for part in reversed(rest):
            replacement = {part: replacement}
        encoded = json.dumps(replacement, ensure_ascii=False, indent=2)
        if child is not None:
            return text[:child.start] + encoded + text[child.end:]
        # Insert before the first property, retaining even leading comments.
        addition = "\n  " + json.dumps(key) + ": " + encoded
        addition += "," if node.members else "\n"
        return text[:node.start + 1] + addition + text[node.start + 1:]

    return edit(root, list(path))
