#!/bin/bash

# hello-env.sh - A tool to load environment variables from .env files

function show_help {
  echo "Usage: source hello-env.sh [OPTIONS] [FILES]"
  echo ""
  echo "Load environment variables from .env files into the current shell."
  echo ""
  echo "Options:"
  echo "  -h, --help      Show this help message"
  echo "  -l, --list      List variables after loading (values hidden)"
  echo "  -v, --verbose   Show variables being loaded with their values"
  echo "  -o, --overwrite Overwrite existing environment variables"
  echo ""
  echo "Examples:"
  echo "  source hello-env.sh                # Load from .env in current directory"
  echo "  source hello-env.sh .env.dev       # Load from .env.dev"
  echo "  source hello-env.sh .env .env.dev  # Load from multiple files"
  echo ""
  echo "Note: This script must be sourced, not executed, to affect the current shell."
  echo "      If you run it with './hello-env.sh', the variables won't be available."
}

# Check if the script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: This script must be sourced, not executed."
  echo "Please run: source $(basename "${0}") [OPTIONS] [FILES]"
  exit 1
fi

# Default options
LIST=false
VERBOSE=false
OVERWRITE=false
FILES=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      return 0
      ;;
    -l|--list)
      LIST=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -o|--overwrite)
      OVERWRITE=true
      shift
      ;;
    -*)
      echo "Error: Unknown option $1"
      show_help
      return 1
      ;;
    *)
      FILES+=("$1")
      shift
      ;;
  esac
done

# If no files specified, default to .env
if [ ${#FILES[@]} -eq 0 ]; then
  FILES=(".env")
fi

LOADED_COUNT=0
SKIPPED_COUNT=0

# Process each file
for FILE in "${FILES[@]}"; do
  if [ ! -f "$FILE" ]; then
    echo "Warning: File not found: $FILE"
    continue
  fi
  
  echo "Loading variables from $FILE..."
  
  # Read file line by line
  while IFS= read -r LINE || [ -n "$LINE" ]; do
    # Skip comments and empty lines
    if [[ "$LINE" =~ ^[[:space:]]*$ || "$LINE" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    
    # Remove inline comments
    LINE=$(echo "$LINE" | sed 's/[[:space:]]*#.*$//')
    
    # Extract variable name and value
    if [[ "$LINE" =~ ^[[:space:]]*export[[:space:]]+([^=]+)=(.*)$ ]]; then
      VAR_NAME="${BASH_REMATCH[1]}"
      VAR_VALUE="${BASH_REMATCH[2]}"
    elif [[ "$LINE" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
      VAR_NAME="${BASH_REMATCH[1]}"
      VAR_VALUE="${BASH_REMATCH[2]}"
    else
      continue
    fi
    
    # Trim whitespace
    VAR_NAME=$(echo "$VAR_NAME" | xargs)
    
    # Remove surrounding quotes if present
    if [[ "$VAR_VALUE" =~ ^\"(.*)\"$ || "$VAR_VALUE" =~ ^\'(.*)\'$ ]]; then
      VAR_VALUE="${BASH_REMATCH[1]}"
    fi
    
    # Check if variable already exists and handle accordingly
    eval "VAR_VALUE_CURRENT=\${$VAR_NAME}"
    if [ -n "$VAR_VALUE_CURRENT" ] && [ "$OVERWRITE" = false ]; then
      if [ "$VERBOSE" = true ]; then
        echo "  Skipping $VAR_NAME (already set)"
      fi
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      continue
    fi
    
    # Export the variable
    export "$VAR_NAME"="$VAR_VALUE"
    
    if [ "$VERBOSE" = true ]; then
      echo "  Loaded $VAR_NAME = $VAR_VALUE"
    fi
    
    LOADED_COUNT=$((LOADED_COUNT + 1))
  done < "$FILE"
done

echo "Loaded $LOADED_COUNT variables from ${#FILES[@]} file(s)."
if [ $SKIPPED_COUNT -gt 0 ]; then
  echo "Skipped $SKIPPED_COUNT existing variables. Use --overwrite to replace them."
fi

# List loaded variables if requested
if [ "$LIST" = true ]; then
  echo "Environment variables loaded:"
  for FILE in "${FILES[@]}"; do
    if [ ! -f "$FILE" ]; then
      continue
    fi
    
    echo "From $FILE:"
    grep -v '^#' "$FILE" | grep '=' | sed 's/=.*$//' | sed 's/^export //' | while read -r VAR_NAME; do
      VAR_NAME=$(echo "$VAR_NAME" | xargs)
      if [ -n "$VAR_NAME" ]; then
        echo "  $VAR_NAME"
      fi
    done
  done
fi
