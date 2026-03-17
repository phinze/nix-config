#!/usr/bin/env bash

# Screenshot - Capture website screenshot and share via GitHub gist
# Uses Puppeteer (via pageres-cli's bundled copy) for full browser control

set -euo pipefail

# Function to show help
show_help() {
    cat << EOF
Usage: screenshot <url> [resolution...] [options]

Examples:
  screenshot https://example.com                    # Default resolution (1366x768)
  screenshot https://example.com 1920x1080          # Single resolution
  screenshot https://example.com 1920x1080 768x1024 # Multiple resolutions
  screenshot http://localhost:3000/admin --login=http://localhost:3000/users/sign_in \\
    --login-field-user='user[email]' --login-field-pass='user[password]' \\
    --login-user=admin@example.com --login-pass=password
  screenshot http://localhost:3000/items/123 \\
    --selector='.card' --padding=20 --highlight='.toast-warning'

Options:
  --login=<url>               Login URL (form-based auth)
  --login-field-user=<name>   Name attribute of the username/email input (default: email)
  --login-field-pass=<name>   Name attribute of the password input (default: password)
  --login-user=<value>        Username/email value
  --login-pass=<value>        Password value
  --selector=<element>        Capture a specific DOM element
  --padding=<px>              Padding around --selector capture (default: 0)
  --highlight=<selector>      Highlight elements with a colored box (repeatable)
  --highlight-color=<color>   Highlight color (default: rgba(255,200,0,0.25))
  --highlight-border=<color>  Highlight border color (default: rgba(255,160,0,0.8))
  --full-page                 Capture full scrollable page (default: viewport only)
  -h, --help                  Show this help message

The screenshot will be uploaded to a GitHub gist and the URL will be provided.
EOF
}

# Check for help flag or no arguments
if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Parse arguments
url="$1"
shift

resolutions=()
login_url=""
login_field_user="email"
login_field_pass="password"
login_user=""
login_pass=""
selector=""
padding="0"
highlights=()
highlight_color="rgba(255,200,0,0.25)"
highlight_border="rgba(255,160,0,0.8)"
full_page="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --login=*) login_url="${1#--login=}" ;;
        --login-field-user=*) login_field_user="${1#--login-field-user=}" ;;
        --login-field-pass=*) login_field_pass="${1#--login-field-pass=}" ;;
        --login-user=*) login_user="${1#--login-user=}" ;;
        --login-pass=*) login_pass="${1#--login-pass=}" ;;
        --selector=*) selector="${1#--selector=}" ;;
        --padding=*) padding="${1#--padding=}" ;;
        --highlight=*) highlights+=("${1#--highlight=}") ;;
        --highlight-color=*) highlight_color="${1#--highlight-color=}" ;;
        --highlight-border=*) highlight_border="${1#--highlight-border=}" ;;
        --full-page) full_page="true" ;;
        *) [[ "$1" =~ ^[0-9]+x[0-9]+$ ]] && resolutions+=("$1") ;;
    esac
    shift
done

# Use default resolution if none specified
if [[ ${#resolutions[@]} -eq 0 ]]; then
    resolutions=("1366x768")
fi

# Setup temporary directory
timestamp=$(date +%Y%m%d-%H%M%S)
temp_dir="/tmp/screenshot-$timestamp"
mkdir -p "$temp_dir"

echo "📸 Capturing screenshot..."
echo "URL: $url"
echo "Resolution(s): ${resolutions[*]}"

# Find puppeteer from pageres-cli's node_modules
pageres_bin=$(readlink -f "$(which pageres)")
puppeteer_dir="$(dirname "$pageres_bin")/../lib/node_modules/pageres-cli/node_modules/puppeteer"

if [[ ! -d "$puppeteer_dir" ]]; then
    echo "Error: Could not find puppeteer in pageres-cli's node_modules"
    exit 1
fi

# Build resolutions as JSON array
resolutions_json=$(printf '%s\n' "${resolutions[@]}" | jq -R 'split("x") | {width: (.[0] | tonumber), height: (.[1] | tonumber)}' | jq -s '.')

# Generate and run the Puppeteer script
node_script="$temp_dir/capture.js"
cat > "$node_script" << 'NODESCRIPT'
const puppeteer = require('puppeteer');
const { join } = require('path');

const config = JSON.parse(process.argv[2]);

(async () => {
  const browser = await puppeteer.launch({
    headless: true,
    executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || undefined,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const page = await browser.newPage();

  // Login if configured
  if (config.loginUrl) {
    console.log(`🔑 Logging in at ${config.loginUrl}...`);
    await page.goto(config.loginUrl, { waitUntil: 'networkidle2' });

    // Fill in and submit the login form using JavaScript evaluation
    // This avoids CSS selector escaping issues with field names like "user[email]"
    await page.evaluate((fieldUser, fieldPass, user, pass) => {
      const userInput = document.querySelector(`input[name="${fieldUser}"]`);
      const passInput = document.querySelector(`input[name="${fieldPass}"]`);
      if (!userInput) throw new Error(`Could not find input[name="${fieldUser}"]`);
      if (!passInput) throw new Error(`Could not find input[name="${fieldPass}"]`);

      // Set values using native setter to trigger framework change handlers
      const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
        window.HTMLInputElement.prototype, 'value').set;
      nativeInputValueSetter.call(userInput, user);
      nativeInputValueSetter.call(passInput, pass);
      userInput.dispatchEvent(new Event('input', { bubbles: true }));
      passInput.dispatchEvent(new Event('input', { bubbles: true }));

      // Submit the form
      userInput.closest('form').submit();
    }, config.loginFieldUser, config.loginFieldPass, config.loginUser, config.loginPass);

    // Wait for navigation after form submit
    await page.waitForNavigation({ waitUntil: 'networkidle2', timeout: 15000 })
      .catch(() => null);
    await new Promise(r => setTimeout(r, 1000));
    console.log('✔ Logged in');
  }

  // Take screenshots at each resolution
  for (const res of config.resolutions) {
    await page.setViewport(res);
    await page.goto(config.url, { waitUntil: 'networkidle2' });

    // Apply highlights before capturing
    if (config.highlights && config.highlights.length > 0) {
      await page.evaluate((selectors, bgColor, borderColor) => {
        for (const sel of selectors) {
          const els = document.querySelectorAll(sel);
          for (const el of els) {
            el.style.outline = `3px solid ${borderColor}`;
            el.style.outlineOffset = '2px';
            el.style.backgroundColor = bgColor;
          }
        }
      }, config.highlights, config.highlightColor, config.highlightBorder);
      // Let repaint settle
      await new Promise(r => setTimeout(r, 200));
    }

    const filename = `${config.filenameBase}-${res.width}x${res.height}.png`;
    const filepath = join(config.outputDir, filename);

    if (config.selector) {
      const element = await page.$(config.selector);
      if (element) {
        if (config.padding > 0) {
          // Screenshot with padding: get bounding box, expand, clip
          const box = await element.boundingBox();
          const vp = page.viewport();
          const clip = {
            x: Math.max(0, box.x - config.padding),
            y: Math.max(0, box.y - config.padding),
            width: Math.min(box.width + config.padding * 2, vp.width - Math.max(0, box.x - config.padding)),
            height: box.height + config.padding * 2,
          };
          await page.screenshot({ path: filepath, clip });
        } else {
          await element.screenshot({ path: filepath });
        }
      } else {
        console.error(`Selector "${config.selector}" not found, falling back to full page`);
        await page.screenshot({ path: filepath, fullPage: config.fullPage });
      }
    } else {
      await page.screenshot({ path: filepath, fullPage: config.fullPage });
    }

    console.log(`✔ Captured ${res.width}x${res.height}`);
  }

  await browser.close();
})();
NODESCRIPT

# Build highlights as JSON array
if [[ ${#highlights[@]} -gt 0 ]]; then
    highlights_json=$(printf '%s\n' "${highlights[@]}" | jq -R '.' | jq -s '.')
else
    highlights_json="[]"
fi

# Build config JSON
config_json=$(jq -n \
    --arg url "$url" \
    --arg outputDir "$temp_dir" \
    --arg filenameBase "screenshot-$timestamp" \
    --arg loginUrl "$login_url" \
    --arg loginFieldUser "$login_field_user" \
    --arg loginFieldPass "$login_field_pass" \
    --arg loginUser "$login_user" \
    --arg loginPass "$login_pass" \
    --arg selector "$selector" \
    --argjson padding "$padding" \
    --argjson highlights "$highlights_json" \
    --arg highlightColor "$highlight_color" \
    --arg highlightBorder "$highlight_border" \
    --argjson fullPage "$full_page" \
    --argjson resolutions "$resolutions_json" \
    '{
        url: $url,
        outputDir: $outputDir,
        filenameBase: $filenameBase,
        loginUrl: (if $loginUrl == "" then null else $loginUrl end),
        loginFieldUser: $loginFieldUser,
        loginFieldPass: $loginFieldPass,
        loginUser: $loginUser,
        loginPass: $loginPass,
        selector: (if $selector == "" then null else $selector end),
        padding: $padding,
        highlights: $highlights,
        highlightColor: $highlightColor,
        highlightBorder: $highlightBorder,
        fullPage: $fullPage,
        resolutions: $resolutions
    }')

# Run with puppeteer from pageres-cli's node_modules
# Use the same Chromium that pageres is configured to use
PUPPETEER_EXECUTABLE_PATH="${PUPPETEER_EXECUTABLE_PATH:-$(which chromium 2>/dev/null || echo "")}"
if [[ -z "$PUPPETEER_EXECUTABLE_PATH" ]]; then
    echo "Error: Could not find chromium. Set PUPPETEER_EXECUTABLE_PATH."
    exit 1
fi
export PUPPETEER_EXECUTABLE_PATH
NODE_PATH="$(dirname "$puppeteer_dir")" node "$node_script" "$config_json"

# Find generated screenshots
cd "$temp_dir"
screenshots=(screenshot-$timestamp*.png)

if [[ ${#screenshots[@]} -eq 0 ]] || [[ ! -f "${screenshots[0]}" ]]; then
    echo "No screenshots generated"
    cd - > /dev/null
    rm -rf "$temp_dir"
    exit 1
fi

# Create description
description="Screenshot of $url at ${resolutions[*]}"

# Create markdown file
md_file="$temp_dir/README.md"
{
    echo "# $description"
    echo ""
    echo "Created: $(date)"
    echo ""
    echo "## Screenshots"
    echo ""

    for screenshot in "${screenshots[@]}"; do
        if [[ "$screenshot" =~ -([0-9]+x[0-9]+)\.png$ ]]; then
            resolution="${BASH_REMATCH[1]}"
            echo "### $resolution"
        fi
        echo "![$screenshot]($screenshot)"
        echo ""
    done

    echo "## Source"
    echo "- URL: $url"
    echo "- Captured: $(date)"
} > "$md_file"

echo "📤 Creating private GitHub gist..."
gist_output=$(gh gist create --desc "$description" "$md_file" 2>&1)
gist_url=$(echo "$gist_output" | tail -1)

if [[ ! "$gist_url" =~ https://gist.github.com/ ]]; then
    echo "Failed to create gist"
    cd - > /dev/null
    rm -rf "$temp_dir"
    exit 1
fi

# Extract gist ID from URL
gist_id="${gist_url##*/}"

echo "📎 Adding screenshots to gist..."
gist_dir="/tmp/gist-$gist_id"

# Clone the gist
if ! git clone -q "https://gist.github.com/$gist_id.git" "$gist_dir" 2>/dev/null; then
    echo "Failed to clone gist"
    cd - > /dev/null
    rm -rf "$temp_dir"
    exit 1
fi

# Copy screenshots to gist and push
cp "${screenshots[@]}" "$gist_dir/"
cd "$gist_dir"
git add *.png
git commit -q --no-gpg-sign -m "Add screenshots"

if ! { git push -q origin master 2>/dev/null || git push -q origin main 2>/dev/null; }; then
    echo "Failed to upload screenshots to gist"
    cd - > /dev/null
    rm -rf "$temp_dir" "$gist_dir"
    exit 1
fi

cd - > /dev/null

echo "✅ Screenshots uploaded!"
echo "Gist URL: $gist_url"
echo ""
echo "📋 Direct image URLs:"
for screenshot in "${screenshots[@]}"; do
    github_user=$(gh api user --jq .login 2>/dev/null || echo "phinze")
    echo "https://gist.githubusercontent.com/$github_user/$gist_id/raw/$screenshot"
done
echo ""
echo "📋 Markdown embeds:"
for screenshot in "${screenshots[@]}"; do
    github_user=$(gh api user --jq .login 2>/dev/null || echo "phinze")
    if [[ "$screenshot" =~ -([0-9]+x[0-9]+)\.png$ ]]; then
        resolution="${BASH_REMATCH[1]}"
        echo "![$resolution](https://gist.githubusercontent.com/$github_user/$gist_id/raw/$screenshot)"
    else
        echo "![$screenshot](https://gist.githubusercontent.com/$github_user/$gist_id/raw/$screenshot)"
    fi
done

# Clean up
rm -rf "$temp_dir" "$gist_dir"
