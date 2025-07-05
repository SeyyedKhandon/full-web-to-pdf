#!/bin/bash

# --- Script to Recursively Convert a Website to a Single PDF (v1) ---
#
# Description:
# Serving downloaded files from a temporary local web server before printing.
#
# Dependencies:
# - wget, qpdf, Google Chrome, python3
#

# --- 1. Argument and Dependency Checks ---

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <start_url> <output_file.pdf> [depth]"
  exit 1
fi

# On macOS, Chrome is here. You may need to change this for other systems.
# e.g., for Linux: CHROME_EXEC="google-chrome" or "chromium-browser"
CHROME_EXEC="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

if ! command -v wget &> /dev/null || ! command -v qpdf &> /dev/null || ! command -v python3 &> /dev/null || [ ! -f "$CHROME_EXEC" ]; then
  echo "Error: A required dependency is missing." >&2
  echo "Please ensure you have installed: wget, qpdf, python3, and Google Chrome." >&2
  echo "On macOS (with Homebrew): brew install wget qpdf python" >&2
  exit 1
fi

# --- 2. Set Variables ---

START_URL="$1"
OUTPUT_PDF="$2"
DEPTH=${3:-1}
DOMAIN=$(echo "$START_URL" | awk -F/ '{print $3}')
TEMP_DIR="website_download_$(date +%s)"
PDF_PAGES_DIR="${TEMP_DIR}/pdf_pages"
SERVER_PORT=8888 # Use a less common port to avoid conflicts
LOGFILE="$TEMP_DIR/wget.log"
SUBDIR=$(basename "$(echo "$START_URL" | sed 's:/*$::')")

echo "$SUBDIR"
echo "Configuration:"
echo "  URL: $START_URL"
echo "  Crawl Depth: $DEPTH"
echo "  Output PDF: $OUTPUT_PDF"
echo "  Subdirectory: $SUBDIR"
echo "-------------------------------------"

# --- 3. Download the Website ---

echo "🌐 Starting website download with wget..."

mkdir -p "$TEMP_DIR"

wget --recursive --level="$DEPTH" --convert-links --page-requisites \
     --adjust-extension --span-hosts --no-parent \
     --directory-prefix="$TEMP_DIR" --domains "$DOMAIN" \
     "$START_URL" --output-file="$LOGFILE"


if [ $? -ne 0 ]; then echo "Error: wget failed. Aborting." >&2; exit 1; fi
echo "✅ Website download complete."

# --- 3a. Rename downloaded .html files in download order ---

echo "🔄 Renaming downloaded .html files in download order..."

# Extract saved file paths in order from wget log
grep 'Saving to:' "$LOGFILE" | sed -E 's/.*Saving to: .?//;s/.?$//' > "$TEMP_DIR/files_in_order.txt"

counter=1
while IFS= read -r file; do
  # Only rename .html files (case-insensitive)
  if [[ "$file" =~ \.html?$ ]]; then
    dir=$(dirname "$file")
    orig=$(basename "$file")
    newname="$dir/$(printf "%04d" $counter)+$orig"
    
    if [[ "$file" != "$newname" ]]; then
      echo "🔄 Renaming '$file' → '$newname'"
      mv "$file" "$newname"
    fi
    ((counter++))
  fi
done < "$TEMP_DIR/files_in_order.txt"

echo "✅ Renaming complete."

# --- 4. Start Local Server ---

# The actual content is usually in a sub-directory named after the domain
DOC_ROOT="$TEMP_DIR/$DOMAIN/$SUBDIR"
if [ ! -d "$DOC_ROOT" ]; then
    # Fallback to the top temp directory if the domain subdir doesn't exist
    DOC_ROOT="$TEMP_DIR"
fi

echo "🚀 Starting temporary web server in '$DOC_ROOT' on port $SERVER_PORT..."
cd "$DOC_ROOT"
python3 -m http.server $SERVER_PORT &
SERVER_PID=$!
cd - > /dev/null

# Give the server a moment to start up
sleep 2

# --- 5. Convert HTML files to Individual PDFs in Download Order ---

echo "📄 Converting pages to PDF via local web server..."
mkdir -p "$PDF_PAGES_DIR"

COUNT=0

# Find HTML files and create relative paths for the URL
HTML_FILES=$(find "$DOC_ROOT" -name "*.html" | sort)
if [ -z "$HTML_FILES" ]; then
    echo "Error: No HTML files were found." >&2
    kill $SERVER_PID
    exit 1
fi

COUNT=0
for FILE_PATH in $HTML_FILES; do
    COUNT=$((COUNT+1))
    # Get path relative to the document root for the URL
    RELATIVE_PATH=${FILE_PATH#"$DOC_ROOT/"}
    PAGE_URL="http://localhost:$SERVER_PORT/$RELATIVE_PATH"
    PDF_OUTPUT_PATH="${PWD}/${PDF_PAGES_DIR}/$(printf "%04d" $COUNT)-page.pdf"
    
    echo " -> Converting ${PAGE_URL}"
    "$CHROME_EXEC" --headless --disable-gpu --print-to-pdf="$PDF_OUTPUT_PATH" "$PAGE_URL" > /dev/null 2>&1
done

# --- 6. Stop Server and Merge PDFs ---

echo "🛑 Stopping temporary web server..."
kill $SERVER_PID

echo "📚 Merging all ${COUNT} pages into a single PDF..."
qpdf --empty --pages "${PDF_PAGES_DIR}"/*.pdf -- "$OUTPUT_PDF"

if [ $? -eq 0 ]; then
  echo "🎉 Success! PDF created: $OUTPUT_PDF"
else
  echo "Error: qpdf failed to merge the PDF files." >&2
  exit 1
fi

# --- 7. Cleanup ---

read -p "Do you want to delete the temporary download directory '$TEMP_DIR'? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "🧹 Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
  echo "✅ Cleanup complete."
fi

exit 0
