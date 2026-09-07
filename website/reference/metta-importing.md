# `metta.importing`

Source: `extensions/python/metta/importing.py`.

> A `.metta` file is a Python module. `install()` puts a
> `sys.meta_path` finder and its loader in place, so `import lib_list` finds
> `lib_list.metta` on the search path, loads it into a space through the
> engine's own `import!`, and answers a module whose attributes are the heads
> that file declares. `importlib.reload(lib_list)` is that same `import!` under
> Python's word: the digest reload withdraws the file's atoms and definitions
> and replaces them, and the module's attributes answer the new bodies.

The entries below reproduce the source signatures and docstrings.

## `Module`

```python
class Module(types.ModuleType):
```

> The module a `.metta` file becomes.
>
> Its attributes are the heads the file declares, each the `_EngineFunction`
> the loading space's own `fn` namespace answers, so `lib_list.length` and
> `m.fn.length` are one object and calling one is calling the other. A name
> the file does not declare falls through to that namespace too, under
> Python's underscore-to-hyphen map: `rules.car_atom` reaches `car-atom`
> whether or not this file wrote it, because the module reads a live space
> rather than a snapshot of one. `__all__` stays the file's own heads, which
> is what `from rules import *` takes and what `dir()` lists.
>
> No `__slots__`: a module IS its `__dict__`, which is where the heads go
> and where `sys.modules` and every tool reading `vars(module)` look.

## `Loader`

```python
class Loader(importlib.abc.Loader):
```

> Loads one `.metta` file into one space, and populates its module.
>
> The load is `!(import! <space> <absolute path>)` and nothing else, so the
> module and `m += lib.x` and a `!(import! ...)` inside another file all go
> through the one loader with the one lifecycle: a file already loaded and
> unchanged is skipped, an edited one replaces what it put in every space
> holding it, and a load that raises leaves the previous definitions
> standing.

### `Loader.create_module`

```python
def create_module(self, spec: importlib.machinery.ModuleSpec) -> Module:
```

> Answer the module class that reads its space, not a plain one.

### `Loader.exec_module`

```python
def exec_module(self, module: types.ModuleType) -> None:
```

> Load the file into the space, then say what the file declares.
>
> A reload arrives here with the module that was loaded before, so the
> names the previous load exported are dropped first: a head the edit
> removed must leave the module the way it left the space.

### `Loader.get_source`

```python
def get_source(self, fullname: str) -> str:
```

> The file's own text, which is what a traceback and `inspect` read.

## `Finder`

```python
class Finder(importlib.abc.MetaPathFinder):
```

> Resolves an import name to a `.metta` file, for one space.
>
> The finder is APPENDED to `sys.meta_path`, so Python's own finders answer
> first and a name with both a `.py` and a `.metta` on the path is Python's.
> Its search is `path`, then `sys.path` read live, then the directory a
> package advertises for that exact name under `metta.libraries`.
>
> One finder names one space for its whole life. `sys.modules` is
> process-wide and answers a second `import lib_list` from its cache without
> consulting any finder, so a module could not belong to whichever space
> happened to be current; a second space loads the same file with
> `m += lib(S["path/to/file"])`, or through a finder of its own after this
> one is uninstalled.

### `Finder.modules`

```python
def modules(self) -> dict[str, types.ModuleType]:
```

> The modules in `sys.modules` this finder loaded, by name.
>
> Derived rather than recorded, so it cannot drift from what the import
> system actually holds: a module names its loader and a loader names
> its finder.

### `Finder.find_spec`

```python
def find_spec(
    self,
    fullname: str,
    path: Sequence[str] | None = None,
    target: types.ModuleType | None = None,
) -> importlib.machinery.ModuleSpec | None:
```

> The spec for a `.metta` file with this name, or None to defer.
>
> `path` is the parent package's `__path__` for a submodule, which is
> the only place a submodule may come from: a `.metta` file has no
> `__path__` of its own, so `import rules.part` reaches a file only when
> `rules` is a Python package shipping one.

### `Finder.uninstall`

```python
def uninstall(self) -> None:
```

> Take this finder off `sys.meta_path` and forget what it loaded.
>
> The `sys.modules` entries go with it, because a module left behind
> would answer a later `import` from a finder that is no longer there
> and would fail `importlib.reload` with a spec nobody can find. A
> reference already held goes on working: its heads read a space, and
> the space is still there.

## `install`

```python
def install(space: Any = None, *, path: Any = None) -> Finder:
```

> Make `.metta` files importable, and answer the finder that does it.
>
>     with metta.importing.install(m):
>         import lib_list                  # loads lib_list.metta into m
>
>     finder = metta.importing.install()   # the ambient space, until uninstalled
>
> `space` is the space each imported file loads into, a context or a space,
> and defaults to the ambient one, resolved now rather than per import so
> the finder names one space for its whole life. `path` names directories
> searched BEFORE `sys.path`, the way `python script.py` puts the script's
> directory at the front without `sys.path` itself changing; one directory
> may be given bare, so `path="rules"` is `path=["rules"]`. The longhand of
> the whole door is `m += lib(S["rules/lib_list.metta"])`, which performs
> the same `import!` and answers no module.
>
> The finder is appended, so Python's own finders answer first. It is a
> context manager because a hook is process-wide: `uninstall()` is the
> explicit spelling and the `with` block is the one that cannot be
> forgotten.

## `installed`

```python
def installed() -> tuple[Finder, ...]:
```

> Every finder this door has installed, in the order imports ask them.
>
> The list is `sys.meta_path` filtered, not a registry kept beside it, so a
> finder removed by hand is gone from here too.
