#!/usr/bin/env python3
'''
Generate the StackStorm Pack Index file from local files

Copyright (C) 2025 Jason Piszcyk
Email: Jason.Piszcyk@gmail.com

All rights reserved.

This software is private and may NOT be copied, distributed, reverse engineered,
decompiled, or modified without the express written permission of the copyright
holder.

The copyright holder makes no warranties, express or implied, about its 
suitability for any particular purpose.
'''
###########################################################################
#
# Imports
#
###########################################################################
# Shared variables, constants, etc

# System Modules
import os
import glob
import yaml
import json
from collections import OrderedDict
import hashlib
import time

# Local app modules

# Imports for python variable type hints


###########################################################################
#
# Module Specific Items
#
###########################################################################
#
# Types
#

#
# Constants
#
BASE_DIR = "/Users/jp/Development"
PACK_INDEX_FILE =  f"{BASE_DIR}/StaticFiles/index.json"
PACK_SUBDIR_LIST = ["actions", "sensors", "rules"]
GITHUB_URL_BASE = "https://github.com/JasonPiszcyk/"

#
# Global Variables
#


###########################################################################
#
# Module
#
###########################################################################


###########################################################################
#
# The main code
#
###########################################################################
'''
Handle case of being run directly rather than imported
'''
if __name__ == "__main__":
    # Create a Dict with the values for the index
    _index_dict = OrderedDict({
        'packs': {},
        'metadata': OrderedDict([
            ('generated_ts', 0),
            ('hash', "")
        ])
    })

    _data_hash = hashlib.md5()

    # Get a list of directories/repositories
    _repo_subdir_list = [f.name for f in os.scandir(BASE_DIR) if f.is_dir()]

    # Process each repository witch a pack.yaml file
    for _subdir_name in _repo_subdir_list:
        _subdir = f"{BASE_DIR}/{_subdir_name}"
        if not os.path.isfile(_subdir + "/pack.yaml"): continue

        # Extract info from the pack.yaml file
        _pack_yaml = {}
        with open(f"{_subdir}/pack.yaml", "r", encoding="utf8") as _file:
            _pack_yaml = yaml.safe_load(_file)

        _data_hash.update(str(_pack_yaml).encode('utf-8'))
        _pack_ref = _pack_yaml['ref']

        # Create the pack info
        _index_dict['packs'][_pack_ref] = { # type: ignore
            'name': _pack_yaml['name'],
            'description': _pack_yaml['description'],
            'version': _pack_yaml['version'],
            'repo_url': f"{GITHUB_URL_BASE}{_subdir_name}",
            'author': _pack_yaml['author'],
            'email': _pack_yaml['email']
        }

        # Go through the sub directories of the pack
        _index_dict['packs'][_pack_ref]['content'] = {} # type: ignore
        for _resdir_name in PACK_SUBDIR_LIST:
            # Get a list of yaml files in this dir
            _resdir = f"{_subdir}/{_resdir_name}"
            _yaml_list = glob.glob(_resdir + "/*.yaml")

            _resource_list = []

            # Process the files
            for _yaml_file in _yaml_list:
                if os.path.isfile(_yaml_file):
                    with open(_yaml_file, "r") as _file:
                        try:
                            _res_yaml = yaml.safe_load(_file)
                        except:
                            _res_yaml = {}
                    
                    if "name" in _res_yaml:
                        _resource_list.append(_res_yaml["name"])
                    elif "class_name" in _res_yaml:
                        _resource_list.append(_res_yaml["class_name"])
                    
            # Add the resource info
            if len(_resource_list) > 0:
                _index_dict['packs'][_pack_ref]['content'][_resdir_name] = { # type: ignore
                        'count': len(_resource_list),
                        'resources': _resource_list
                    } 


    # Generate the timestamp/hash value
    _index_dict['metadata']['generated_ts'] = int(time.time()) # type: ignore
    _index_dict['metadata']['hash'] = _data_hash.hexdigest() # type: ignore

    # Write the index file
    with open(PACK_INDEX_FILE, 'w', encoding="utf8") as index_file:
        json.dump(
            _index_dict,
            index_file,
            indent=4,
            sort_keys=True,
            separators=(',', ': ')
        )
