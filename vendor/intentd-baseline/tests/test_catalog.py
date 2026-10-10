from pathlib import Path

import pytest

from intentd.catalog import CatalogError, load_catalog


def test_bundled_catalog_loads_and_indexes_by_id():
    catalog = load_catalog()
    assert catalog["firefox"].attr == "firefox"
    assert catalog["obsidian"].unfree is True


def test_duplicate_ids_rejected(tmp_path: Path):
    bad = tmp_path / "apps.json"
    bad.write_text(
        '[{"id": "a", "name": "A", "attr": "a", "summary": "x"},'
        ' {"id": "a", "name": "A2", "attr": "a2", "summary": "y"}]'
    )
    with pytest.raises(CatalogError, match="duplicate"):
        load_catalog(bad)


def test_malformed_entry_rejected(tmp_path: Path):
    bad = tmp_path / "apps.json"
    bad.write_text('[{"id": "a", "name": "A", "attr": "a", "summary": "x", "evil": true}]')
    with pytest.raises(CatalogError):
        load_catalog(bad)


def test_missing_catalog_file_raises_catalog_error(tmp_path: Path):
    with pytest.raises(CatalogError):
        load_catalog(tmp_path / "nope.json")


def test_non_list_catalog_root_rejected(tmp_path: Path):
    bad = tmp_path / "apps.json"
    bad.write_text("1")
    with pytest.raises(CatalogError):
        load_catalog(bad)
