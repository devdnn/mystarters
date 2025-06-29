#!/bin/bash

# Define the base directory
# Check if an argument is provided for the base directory; if not, use the current directory
baseDir="${1:-$(pwd)}"

echo "Creating roles directory structure in: $baseDir"

# create an array for folders needed in the role directory
folders=(defaults files handlers tasks templates vars)

# create an array of folders where main.yml file is needed
mainFolders=(defaults handlers tasks vars)

# Create the role directory for each folder
for folder in ${folders[@]}; do
  echo "Creating $folder directory..."
  mkdir -p $baseDir/$folder

  # if the folder is in the mainFolders array, create a main.yml file
    if [[ " ${mainFolders[@]} " =~ " ${folder} " ]]; then
        echo "Creating main.yml file in $folder directory..."
        touch $baseDir/$folder/main.yml
    fi
done


# echo include_vars into main.yml inside tasks folder
echo "---" > $baseDir/tasks/main.yml
echo "- include_vars: main.yml" >> $baseDir/tasks/main.yml
