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

# Create the index file
index_file = open(__PACK_INDEX_FILE, "w")
index_file.write("{\n  \"packs\": {")

# Get a list of directories/repositories
repo_subdir_list = [f.name for f in os.scandir(__BASE_DIR) if f.is_dir()]

# Process each repository witch a pack.yaml file
for subdir_name in repo_subdir_list:
    subdir = __BASE_DIR + "/" + subdir_name

    pack_comma = ""
    if os.path.isfile(subdir + "/pack.yaml"):
        # Extract info from the pack.yaml file
        with open(subdir + "/pack.yaml", "r") as file:
            pack_yaml = yaml.safe_load(file)

        index_file.write(pack_comma +"\n")
        pack_comma = ","
        
        # Create the pack info
        index_file.write("    \"" + pack_yaml['ref'] + "\": {\n")
        index_file.write("      \"name\": \"" + pack_yaml['name'] + "\",\n")
        index_file.write("      \"description\": \"" + pack_yaml['description'] + "\",\n")
        index_file.write("      \"version\": \"" + pack_yaml['version'] + "\",\n")
        index_file.write("      \"author\": \"" + pack_yaml['author'] + "\",\n")
        index_file.write("      \"email\": \"" + pack_yaml['email'] + "\",\n")

        # Add some info on content
        index_file.write("      \"content\": {")

        # Go through the directories
        res_comma = ""
        for resdir_name in __PACK_SUBDIR_LIST:
            index_file.write(res_comma + "\n        \"" + resdir_name + "\": {")
            res_comma = ","

            resdir = subdir + "/" + resdir_name

            # Get a list of yaml files in this dir
            yaml_list = glob.glob(resdir + "/*.yaml")
            resource_list = []

            # Process the files
            for yaml_file in yaml_list:
                if os.path.isfile(yaml_file):
                    with open(yaml_file, "r") as file:
                        res_yaml = yaml.safe_load(file)
                    
                    resource_list.append(res_yaml["name"])
                    
            # Add the resource info
            index_file.write("\n          \"count\": " + str(len(resource_list)) + ",\n")
            index_file.write("          \"resources\": [")

            res_comma = ""
            for resname in resource_list:
                index_file.write(res_comma + "\n            \"" + resname + "\"")
                res_comma = ","

            index_file.write("\n          ]\n")

        index_file.write("        }\n      },\n")

        # Close out the description
        index_file.write("      \"repo_url\": \"" + __GITHUB_URL_BASE + subdir_name + "\"\n")
        index_file.write("    }")

# Close the index file
index_file.write("\n  }\n}\n")
index_file.close()
