import json
import os
import pytest


def _check_for_duplicate_keys(items):
    tmp = {}
    for k, v in items:
        if k in tmp:
            raise ValueError(f"Duplicated key detected: {k}")
        else:
            tmp[k] = v
    return tmp


def _load_scripts():
    with open("community_scripts.json") as f:
        return json.load(f, object_pairs_hook=_check_for_duplicate_keys)


@pytest.mark.parametrize(
    "script",
    _load_scripts(),
    ids=lambda script: script["filename"]
)
def test_community_script_json_file(script):
    valid_shells = ["powershell", "python", "cmd", "shell"]
    valid_os = ["windows", "linux", "darwin"]

    fn: str = script["filename"]
    assert os.path.exists(os.path.join("scripts", fn))
    assert script["filename"]
    assert script["name"]
    assert script["description"]
    assert script["shell"]
    assert script["shell"] in valid_shells

    if fn.endswith(".ps1"):
        assert script["shell"] == "powershell"
    elif fn.endswith(".bat"):
        assert script["shell"] == "cmd"
    elif fn.endswith(".py"):
        assert script["shell"] == "python"

    if "args" in script.keys():
        assert isinstance(script["args"], list)

    # allows strings as long as they can be type casted to int
    if "default_timeout" in script.keys():
        assert isinstance(int(script["default_timeout"]), int)

    # check supported platforms
    if "supported_platforms" in script.keys():
        assert isinstance(script["supported_platforms"], list)
        for i in script["supported_platforms"]:
            assert i in valid_os

    assert "guid" in script.keys()


def test_guids_are_unique():
    """Test that all script GUIDs are unique"""
    scripts = _load_scripts()
    guids = [script["guid"] for script in scripts]
    assert len(guids) == len(set(guids))


def _get_script_files():
    """Get all script files from the scripts directory"""
    files = []
    with os.scandir("scripts") as it:
        for f in it:
            if not f.name.startswith(".") and f.is_file():
                files.append(f.name)
    return files


@pytest.mark.parametrize(
    "filename",
    _get_script_files(),
    ids=lambda filename: filename
)
def test_community_script_has_jsonfile_entry(filename):
    with open(os.path.join("community_scripts.json")) as f:
        info = json.load(f)

    filenames = [i["filename"] for i in info]
    assert filename in filenames


@pytest.mark.parametrize(
    "script",
    _load_scripts(),
    ids=lambda script: script["filename"]
)
def test_script_filenames_do_not_contain_spaces(script):
    assert " " not in script["filename"]
