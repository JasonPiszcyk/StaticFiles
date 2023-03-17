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
import yaml

#===============================================================================
# Global Variables (our Constants)
#===============================================================================
__BASE_DIR = "/Users/jp/GitHub"
__PACK_INDEX_FILE = __BASE_DIR + "/StaticFiles/index.json"
__PACK_SUBDIR_LIST = ["actions"]
__GITHUB_URL_BASE = "https://github.com/JasonPiszcyk/"

# https://github.com/JasonPiszcyk/StackStorm-Nomad.git

#===============================================================================
# Main processing
#===============================================================================
first_time = True

# Create the index file
index_file = open(__PACK_INDEX_FILE, "w")
index_file.write("{\n  \"packs\": {")

# Get a list of directories/repositories
repo_subdir_list = [f.name for f in os.scandir(__BASE_DIR) if f.is_dir()]

# Process each repository witch a pack.yaml file
for subdir_name in repo_subdir_list:
    subdir = __BASE_DIR + "/" + subdir_name
    if os.path.isfile(subdir + "/pack.yaml"):
        # Extract info from the pack.yaml file
        with open(subdir + "/pack.yaml", "r") as file:
            pack_yaml = yaml.safe_load(file)

        # Clean up the commas, in the JSON
        if not first_time:
            index_file.write(",")
        else:
            first_time = False

        index_file.write("\n")
        
        # Create the pack info
        index_file.write("    \"" + pack_yaml['ref'] + "\": {\n")
        index_file.write("      \"name\": \"" + pack_yaml['name'] + "\",\n")
        index_file.write("      \"version\": \"" + pack_yaml['version'] + "\",\n")

        index_file.write("      \"repo_url\": \"" + __GITHUB_URL_BASE + subdir_name + "\"\n")

        # Get a list of all yaml files in subdir list

        # Close out the description
        index_file.write("    }")

# Close the index file
index_file.write("\n  }\n}\n")
index_file.close()
