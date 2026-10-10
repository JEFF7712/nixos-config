import hashlib
import json
from importlib import resources
from pathlib import Path

import pydantic

from intentd.schema import CatalogApp


class CatalogError(Exception):
    pass


def digest_catalog(catalog: dict[str, CatalogApp]) -> str:
    canonical = json.dumps(
        {app_id: catalog[app_id].model_dump(mode="json") for app_id in sorted(catalog)},
        sort_keys=True,
        separators=(",", ":"),
    ).encode()
    return hashlib.sha256(canonical).hexdigest()


def load_catalog(path: Path | None = None) -> dict[str, CatalogApp]:
    try:
        if path is None:
            raw = resources.files("intentd").joinpath("catalog_data/apps.json").read_text()
        else:
            raw = path.read_text()
        entries = [CatalogApp.model_validate(e) for e in json.loads(raw)]
    except (OSError, json.JSONDecodeError, pydantic.ValidationError, TypeError) as exc:
        raise CatalogError(f"invalid catalog: {exc}") from exc
    catalog: dict[str, CatalogApp] = {}
    for app in entries:
        if app.id in catalog:
            raise CatalogError(f"duplicate catalog id: {app.id}")
        catalog[app.id] = app
    return catalog
