import json
import os

def test_community_script_json_file():
    valid_shells = ["powershell", "python", "cmd"]

    with open("community_scripts.json") as f:
        info = json.load(f)

    guids = []
    for script in info:
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

        assert "guid" in script.keys()
        guids.append(script["guid"])

    # check guids are unique
    assert len(guids) == len(set(guids))

def test_community_script_has_jsonfile_entry():
    with open(os.path.join("community_scripts.json")) as f:
        info = json.load(f)

    filenames = [i["filename"] for i in info]

    with os.scandir("scripts") as it:
        for f in it:
            if not f.name.startswith(".") and f.is_file():
                assert f.name in filenames


def test_script_filenames_do_not_contain_spaces():
    with open(
        os.path.join("community_scripts.json")
    ) as f:
        info = json.load(f)
        for script in info:
            assert " " not in script["filename"]