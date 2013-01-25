#!/bin/bash

read -p "Would you like to change the name of this app (y/n)? " a
if [[ $a == "Y" || $a == "y" ]]; then

  echo -e "\n  The following questions are CASE-SENSITIVE: \n"

  read -p "What is the new name for: NewAuth? " name1
  find . -type f -exec sed -i '' s/NewAuth/"$name1"/g {} +

  read -p "What is the new name for: newauth? " name2
  find . -type f -exec sed -i '' s/newauth/"$name2"/g {} +

  read -p "What is the new name for: Newauth? " name3
  find . -type f -exec sed -i '' s/Newauth/"$name3"/g {} +

  echo -e "Done! \n"
else
  echo "Good-bye"
fi
