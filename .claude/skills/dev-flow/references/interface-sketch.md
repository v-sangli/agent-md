# A worked interface sketch

What a sketch looks like at the interface checkpoint (dev-flow step 5). The example is
Python; the same content carries to any language.

Request: "Load tabular files into memory. CSV now; a second format is expected."

## Variation axes

- **File format: generic.** One reader exists today, a second is expected.
- **Where the file is: fixed.** Local paths only. No seam is built for it.

## The data that crosses

```python
@dataclass(frozen=True)
class LoadRequest:
    path: Path
    columns: tuple[str, ...]          # empty means all columns

    def check(self) -> None: ...      # raises on a missing file or a repeated column


@dataclass(frozen=True)
class CsvOptions:
    delimiter: str
    has_header: bool


@dataclass(frozen=True)
class Table:
    columns: tuple[str, ...]
    rows: tuple[tuple[object, ...], ...]
```

## The objects

```python
class CsvReader:
    """Owns everything that knows the CSV format."""

    def __init__(self, options: CsvOptions) -> None: ...
    def read(self, path: Path, columns: tuple[str, ...]) -> Table: ...


class Loader:
    """The entry layer. Calls request.check() once, then trusts."""

    def __init__(self, reader: CsvReader) -> None: ...
    def load(self, request: LoadRequest) -> Table: ...
```

The seam at the file-format axis is the one call `reader.read(path, columns) -> Table`.
`Loader` uses nothing else of the reader. There is one concrete reader behind it, and no
base class, registry or format switch, because a second format is not real yet.

## Directory layout

```text
tabular/
  core/
    table.py        Table
  loading/
    loader.py       Loader
    request.py      LoadRequest and its checks
  readers/
    csv.py          CsvReader, CsvOptions
tests/
  loading/
  readers/
```

## Adding variant N+1

Adding a Parquet reader, once it is real:

- **Touches:** `readers/parquet.py` (new, with the same `read` signature);
  `readers/__init__.py` (a `TableReader` protocol is declared now, because there are two
  readers); `loading/loader.py` (the reader's type becomes `TableReader`); the place that
  constructs the `Loader`.
- **Does not touch:** `core/table.py`, `loading/request.py`, `readers/csv.py`, or any test
  of the CSV path.

## What the user decides here

- The boundary: what `Loader` may know about a reader.
- The names, the fields and their types.
- The layout.
- Which axes are generic and which are fixed.

The sketch leaves out bodies, private helpers and tests. Those belong to the plan.
