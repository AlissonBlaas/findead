CLASS_COMPONENT=''
FIRST_LETTER_COMPONENT=''
declare -a COMPONENTS
AUX_ARRAY_COMPONENTS=''
COUNTER_UNUSED_COMPONENTS=0
AUX_COUNTER=0
for FOLDER_TO_SEARCH_IMPORTS; do true; done
FIND_RETURN=''
FIRST_ARGUMENT=$1

center() {
  termwidth="$(tput cols)"
  padding="$(printf '%0.1s' ={1..500})"
  printf '%*.*s %s %*.*s\n' 0 "$(((termwidth - 2 - ${#1}) / 2))" "$padding" "$1" 0 "$(((termwidth - 1 - ${#1}) / 2))" "$padding"
}

centerResult() {
  termwidth="$(tput cols)"
  padding="$(printf '%0.1s' ={1..500})"
  printf "\e[0m%*.*s $2%s\e[0m %*.*s\n" 0 "$(((termwidth - 2 - ${#1}) / 2))" "$padding" "$1" 0 "$(((termwidth - 1 - ${#1}) / 2))" "$padding"
}

searchFiles() {
  FIND_RETURN=$(find $FIRST_ARGUMENT -type f \( -name "*.js" -o -name "*.jsx" \))
}

FILE_PATH=''
getClassComponents() {
  CLASS_COMPONENT=$(cat ${FILE_PATH} | grep -o "class.*Component" | awk '{ print $2 }')
  USED_IN_SAME_FILE=$(grep -o "<$CLASS_COMPONENT" ${FILE_PATH})
  if [ ! -z "$CLASS_COMPONENT" ]; then
    [[ -z "$USED_IN_SAME_FILE" ]] && COMPONENTS+=("$CLASS_COMPONENT;$FILE_PATH")
  fi
  AUX_ARRAY_COMPONENTS=${COMPONENTS[@]}
}

CURRENT_FUNCTIONS=''
checkFunctions() {
  for FUNCTION in $CURRENT_FUNCTIONS; do
    if [[ ! $FUNCTION =~ ^(\[|\]|\{|\})$ ]]; then
      FIRST_LETTER_FUNCTION_COMPONENT="$(echo "$FUNCTION" | head -c 1)"
      USED_IN_SAME_FILE=$(grep -o "<$FUNCTION" ${FILE_PATH})
      [[ "$FIRST_LETTER_FUNCTION_COMPONENT" =~ [A-Z] ]] &&
        [[ -z "$USED_IN_SAME_FILE" ]] && COMPONENTS+=("$FUNCTION;$FILE_PATH")
    fi
    AUX_ARRAY_COMPONENTS=${COMPONENTS[@]}
  done
}

getES5FunctionComponents() {
  CURRENT_FUNCTIONS=$(cat ${FILE_PATH} | grep -o "function.*(" | awk '{  print $2 }' | cut -d "(" -f 1)
  checkFunctions
}

getES6FunctionComponents() {
  CURRENT_FUNCTIONS=$(cat ${FILE_PATH} | grep -o "const.*= (.*) =>" | awk '{  print $2 }')
  checkFunctions
}

getFunctionComponents() {
  IS_REACT_FILE=$(cat ${FILE_PATH} | grep 'import.*React')
  if [ ! -z "$IS_REACT_FILE" ]; then
    getES5FunctionComponents
    getES6FunctionComponents
  fi
}

getComponents() {
  for ITEM in $FIND_RETURN; do
    FILE_PATH=$ITEM
    getClassComponents
    getFunctionComponents
  done
}

searchImports() {
  GREP_RECURSIVE_RESULT=''
  for COMPONENT in ${COMPONENTS[@]}; do
    COMPONENT_NAME=$(echo $COMPONENT | cut -d ";" -f 1)
    COMPONENT_FILE_PATH=$(echo $COMPONENT | cut -d ";" -f 2)
    GREP_RECURSIVE_RESULT=$(find ${FOLDER_TO_SEARCH_IMPORTS} -type f -exec grep "import.*$COMPONENT_NAME.*from" {} +)
    COMMENTED_IMPORT=$(echo $GREP_RECURSIVE_RESULT | grep //)
    if [ -z "$GREP_RECURSIVE_RESULT" ] || [ ! -z "$COMMENTED_IMPORT" ]; then
      ((COUNTER_UNUSED_COMPONENTS++))
      printf "\e[39m%40s | \e[33m%s\n" $COMPONENT_NAME "$COMPONENT_FILE_PATH"
    fi
    AUX_COUNTER=$COUNTER_UNUSED_COMPONENTS
  done
}

showResult() {
  if [ $COUNTER_UNUSED_COMPONENTS -eq 0 ]; then
    echo -e "No unused components found"
  else
    centerResult "Result $COUNTER_UNUSED_COMPONENTS possible dead components :/" '\e[33m' '\e[0m'
  fi
}

if [[ $FIRST_ARGUMENT == "--version" || $FIRST_ARGUMENT == "-v" ]]; then
  echo "findead@0.2.1"
elif [[ $FIRST_ARGUMENT == "--help" || $FIRST_ARGUMENT == "-h" ]]; then
  cat <<EOF

  findead is used for looking for possible unused components(Dead components)

  usage:
    findead path/to/search/components path/to/find/imports(optional)
    findead -h | --help
    findead -v | --version

  report bugs to: https://github.com/narcello/findead/issues

EOF
else
  tput clear
  tput cup 1 0
  tput rev
  tput bold
  center 'Findead is looking for components...'
  tput sgr0
  tput cup 3 0
  searchFiles && getComponents && searchImports && showResult
fi
