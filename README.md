# 🖨️ Website to PDF Converter (Bash Script)

This Bash script downloads a website recursively and converts its HTML pages into a single PDF.  
It supports JavaScript-heavy sites (e.g., React, Vue) by serving the downloaded content locally before conversion.

---

## 🔧 Requirements

- `wget`
- `qpdf`
- `python3`
- **Google Chrome** (with headless mode support)

> ✅ On macOS (using Homebrew):
```bash
brew install wget qpdf python
```

> ✅ On Ubuntu/Debian:
```bash
sudo apt install wget qpdf python3
```
Make sure Google Chrome is installed and accessible.  
Update the `CHROME_EXEC` path in the script if necessary:
```bash
CHROME_EXEC="/path/to/google-chrome"
```

---

## 📦 Usage

```bash
./website_to_pdf.sh <start_url> <output_file.pdf> [depth]
```

- `<start_url>`: The website's entry URL.
- `<output_file.pdf>`: The name of the final combined PDF file.
- `[depth]` *(optional)*: Link crawl depth (default: **1**).

Example:

```bash
./website_to_pdf.sh https://example.com output.pdf
```

---

## 🧹 Cleanup

After generating the PDF, the script will ask whether to delete the temporary download directory.

---

## 🛠️ Features

- Downloads all required HTML, JS, CSS, and image assets using `wget`.
- Serves the site locally with Python’s `http.server` to avoid file access issues.
- Converts each page to a PDF using headless Chrome.
- Merges all pages into a single, ordered PDF with `qpdf`.

---

## 📌 Notes

- On macOS, Chrome is typically located at:
  ```
  /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
  ```
  Change this path for Linux if needed.
- The script renames downloaded HTML files based on the order they were fetched for accurate sequencing.

---

## 📄 License

This script is free to use and modify under the MIT License.
