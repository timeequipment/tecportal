#!/bin/bash

read -p "Would you like to change the name of this app (y/n)? " a
if [[ $a == "Y" || $a == "y" ]]; then

  echo -e "\n  The following questions are CASE-SENSITIVE: \n"

  # In the following code, here is how the find command breaks down:
  # find .         # find all files in all dirs from this one down
  # -path "./.git" -prune -o     # but exclude the entire .git directory
  # -type f        # and then include only files (not dirs or links)
  # -exec sed...   # and then for every file in that list, 
                   # execute sed to rename text in the file

  read -p "What is the new name for: NewAuth? " name1
  find . -path "./.git" -prune -o -type f -exec sed -i '' s/NewAuth/"$name1"/g {} +

  read -p "What is the new name for: newauth? " name2
  find . -path "./.git" -prune -o -type f -exec sed -i '' s/newauth/"$name2"/g {} +

  read -p "What is the new name for: Newauth? " name3
  find . -path "./.git" -prune -o -type f -exec sed -i '' s/Newauth/"$name3"/g {} +

  echo "Done!"
else
  echo "Good-bye"
fi