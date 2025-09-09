function screenshot --description "Capture website screenshot and share via GitHub gist"
    # Parse arguments
    set -l url ""
    set -l resolutions
    set -l description ""
    set -l help_flag 0
    
    # Check for help flag
    for arg in $argv
        if test "$arg" = "--help" -o "$arg" = "-h"
            set help_flag 1
            break
        end
    end
    
    if test $help_flag -eq 1 -o (count $argv) -eq 0
        echo "Usage: screenshot <url> [resolution...] [options]"
        echo ""
        echo "Examples:"
        echo "  screenshot https://example.com                    # Default resolution (1366x768)"
        echo "  screenshot https://example.com 1920x1080          # Single resolution"
        echo "  screenshot https://example.com 1920x1080 768x1024 # Multiple resolutions"
        echo ""
        echo "Options:"
        echo "  -h, --help     Show this help message"
        echo ""
        echo "The screenshot will be uploaded to a GitHub gist and the URL will be provided."
        return 0
    end
    
    # First argument is the URL
    set url $argv[1]
    
    # Remaining arguments are resolutions (if they match the pattern)
    set -l resolution_pattern '^[0-9]+x[0-9]+$'
    for i in (seq 2 (count $argv))
        if string match -qr $resolution_pattern $argv[$i]
            set -a resolutions $argv[$i]
        end
    end
    
    # If no resolutions specified, use default
    if test (count $resolutions) -eq 0
        set resolutions "1366x768"
    end
    
    # Create description from URL and resolutions
    set description "Screenshot of $url at "(string join ", " $resolutions)
    
    set -l timestamp (date +%Y%m%d-%H%M%S)
    set -l temp_dir "/tmp/screenshot-$timestamp"
    mkdir -p $temp_dir
    
    echo "📸 Capturing screenshot..."
    echo "URL: $url"
    echo "Resolution(s): "(string join ", " $resolutions)
    
    # Build pageres command
    set -l pageres_cmd pageres $url $resolutions --filename="screenshot-$timestamp"
    
    # Execute pageres in temp directory
    cd $temp_dir
    eval $pageres_cmd
    
    if test $status -ne 0
        echo "Failed to capture screenshot"
        cd -
        rm -rf $temp_dir
        return 1
    end
    
    # Find generated files
    set -l screenshots (ls screenshot-$timestamp*.png 2>/dev/null)
    
    if test (count $screenshots) -eq 0
        echo "No screenshots generated"
        cd -
        rm -rf $temp_dir
        return 1
    end
    
    # Ask for confirmation before uploading
    echo ""
    echo -n "📤 Upload "(count $screenshots)" screenshot(s) to GitHub gist? [Y/n] "
    read -l confirm
    
    if test -z "$confirm" -o "$confirm" = "y" -o "$confirm" = "Y"
        # Proceed with upload
    else
        echo "Upload cancelled. Screenshots saved in: $temp_dir"
        cd -
        return 0
    end
    
    # Create a markdown file with screenshots
    set -l md_file "$temp_dir/README.md"
    echo "# $description" > $md_file
    echo "" >> $md_file
    echo "Created: $(date)" >> $md_file
    echo "" >> $md_file
    echo "## Screenshots" >> $md_file
    echo "" >> $md_file
    
    # Add each screenshot to markdown
    for screenshot in $screenshots
        set -l resolution (echo $screenshot | sed -E 's/.*-([0-9]+x[0-9]+)\.png/\1/')
        echo "### $resolution" >> $md_file
        echo "![$resolution]($screenshot)" >> $md_file
        echo "" >> $md_file
    end
    
    echo "## Source" >> $md_file
    echo "- URL: $url" >> $md_file
    echo "- Captured: $(date)" >> $md_file
    
    echo "📤 Creating private GitHub gist..."
    set -l gist_output (gh gist create --desc "$description" $md_file 2>&1)
    set -l gist_url (echo $gist_output | tail -1)
    
    if test $status -ne 0
        echo "Failed to create gist"
        cd -
        rm -rf $temp_dir
        return 1
    end
    
    # Extract gist ID from URL
    set -l gist_id (echo $gist_url | sed 's|.*/||')
    
    echo "📎 Adding screenshots to gist..."
    set -l gist_dir "/tmp/gist-$gist_id"
    
    # Clone the gist
    git clone -q "https://gist.github.com/$gist_id.git" $gist_dir 2>/dev/null
    
    if test $status -ne 0
        echo "Failed to clone gist"
        cd -
        rm -rf $temp_dir
        return 1
    end
    
    # Copy screenshots to gist and push
    cp $screenshots $gist_dir/
    cd $gist_dir
    git add *.png
    git commit -q --no-gpg-sign -m "Add screenshots"
    git push -q origin master 2>/dev/null || git push -q origin main 2>/dev/null
    
    if test $status -ne 0
        echo "Failed to upload screenshots to gist"
        cd -
        rm -rf $temp_dir $gist_dir
        return 1
    end
    
    cd -
    
    echo "✅ Screenshots uploaded!"
    echo "Gist URL: $gist_url"
    echo ""
    echo "📋 Direct image URLs:"
    for screenshot in $screenshots
        echo "https://gist.githubusercontent.com/phinze/$gist_id/raw/$screenshot"
    end
    echo ""
    echo "📋 Markdown embeds:"
    for screenshot in $screenshots
        set -l resolution (echo $screenshot | sed -E 's/.*-([0-9]+x[0-9]+)\.png/\1/')
        echo "![$resolution](https://gist.githubusercontent.com/phinze/$gist_id/raw/$screenshot)"
    end
    
    # Clean up
    rm -rf $temp_dir $gist_dir
end