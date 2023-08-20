#!/usr/bin/env python3
'''
* GenerateStackStormPackIndex.py
*
* Created on 17 Mar 2023
*
* @author: Jason Piszcyk
* 
* Generate the StackStorm Pack Index file from local files
'''

import os
import glob
import yaml
import json
from collections import OrderedDict
import hashlib
import time


#===============================================================================
# Global Variables (our Constants)
#===============================================================================
__BASE_DIR = "/Users/jp/GitHub"
__PACK_INDEX_FILE = __BASE_DIR + "/StaticFiles/index.json"
__PACK_SUBDIR_LIST = ["actions", "sensors", "rules"]
# __GITHUB_URL_BASE = "https://github.com/JasonPiszcyk/"
__GITHUB_URL_BASE = "git@github.com"
__GITHUB_USER = "JasonPiszcyk"


#===============================================================================
# Main processing
#===============================================================================

# Create a Dict with the values for the index
index_dict = OrderedDict({
    'packs': OrderedDict(),
    'metadata': OrderedDict([
        ('generated_ts', None),
        ('hash', None)
    ])
})

data_hash = hashlib.md5()

# Get a list of directories/repositories
repo_subdir_list = [f.name for f in os.scandir(__BASE_DIR) if f.is_dir()]

# Process each repository witch a pack.yaml file
for subdir_name in repo_subdir_list:
    subdir = __BASE_DIR + "/" + subdir_name

    if os.path.isfile(subdir + "/pack.yaml"):
        # Extract info from the pack.yaml file
        with open(subdir + "/pack.yaml", "r", encoding="utf8") as file:
            pack_yaml = yaml.safe_load(file)

        data_hash.update(str(pack_yaml).encode('utf-8'))

        pack_ref = pack_yaml['ref']
        # Create the pack info
        index_dict['packs'][pack_ref] = {
            'name': pack_yaml['name'],
            'description': pack_yaml['description'],
            'version': pack_yaml['version'],
            'repo_url': __GITHUB_URL_BASE + "-" + subdir_name + ":" + __GITHUB_USER + "/" + subdir_name,
            'author': pack_yaml['author'],
            'email': pack_yaml['email']
        }

        # Go through the sub directories of the pack
        index_dict['packs'][pack_ref]['content'] = {}
        for resdir_name in __PACK_SUBDIR_LIST:
            # Get a list of yaml files in this dir
            resdir = subdir + "/" + resdir_name
            yaml_list = glob.glob(resdir + "/*.yaml")

            resource_list = []

            # Process the files
            for yaml_file in yaml_list:
                if os.path.isfile(yaml_file):
                    with open(yaml_file, "r") as file:
                        try:
                            res_yaml = yaml.safe_load(file)
                        except:
                            pass
                    
                    if "name" in res_yaml:
                        resource_list.append(res_yaml["name"])
                    elif "class_name" in res_yaml:
                        resource_list.append(res_yaml["class_name"])
                    
            # Add the resource info
            if len(resource_list) > 0:
                index_dict['packs'][pack_ref]['content'][resdir_name] = {
                        'count': len(resource_list),
                        'resources': resource_list
                    }       


# Generate the timestamp/hash value
index_dict['metadata']['generated_ts'] = int(time.time())
index_dict['metadata']['hash'] = data_hash.hexdigest()

# Write the index file
with open(__PACK_INDEX_FILE, 'w', encoding="utf8") as index_file:
    json.dump(index_dict, index_file, indent=4, sort_keys=True, separators=(',', ': '))

