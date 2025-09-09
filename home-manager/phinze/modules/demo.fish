function demo --description "Record terminal demo and share as GIF via GitHub gist"
    set -l description (echo $argv | string join " ")

    if test -z "$description"
        echo "Usage: demo <description>"
        echo "Records a terminal demo and shares it as a GIF via GitHub gist"
        return 1
    end

    set -l timestamp (date +%Y%m%d-%H%M%S)
    set -l cast_file "/tmp/demo-$timestamp.cast"
    set -l gif_file "/tmp/demo-$timestamp.gif"
    set -l md_file "/tmp/demo-$timestamp.md"

    echo "🎬 Recording terminal session..."
    echo "Press Ctrl+D when done"

    asciinema rec $cast_file

    if test $status -ne 0
        echo "Recording cancelled"
        return 1
    end

    echo "🎨 Converting to GIF..."
    agg $cast_file $gif_file

    if test $status -ne 0
        echo "Failed to convert to GIF"
        return 1
    end

    # Create a markdown file with placeholder for the GIF
    echo "# Demo: $description" > $md_file
    echo "" >> $md_file
    echo "Created: $(date)" >> $md_file
    echo "" >> $md_file
    echo "## Demo" >> $md_file
    echo "" >> $md_file
    echo "![Demo Animation](demo-$timestamp.gif)" >> $md_file
    echo "" >> $md_file
    echo "## Files" >> $md_file
    echo "- `demo-$timestamp.cast` - Original asciinema recording" >> $md_file
    echo "- `demo-$timestamp.gif` - GIF animation" >> $md_file

    echo "📤 Creating private GitHub gist..."
    set -l gist_output (gh gist create --desc "$description" $md_file $cast_file 2>&1)
    set -l gist_url (echo $gist_output | tail -1)

    if test $status -ne 0
        echo "Failed to create gist"
        return 1
    end

    # Extract gist ID from URL
    set -l gist_id (echo $gist_url | sed 's|.*/||')

    echo "📎 Adding GIF to gist..."
    set -l gist_dir "/tmp/gist-$gist_id"
    
    # Clone the gist
    git clone -q "https://gist.github.com/$gist_id.git" $gist_dir 2>/dev/null
    
    if test $status -ne 0
        echo "Failed to clone gist"
        return 1
    end
    
    # Copy files to gist and push
    cp $gif_file "$gist_dir/demo-$timestamp.gif"
    cd $gist_dir
    git add "demo-$timestamp.gif"
    git commit -q --no-gpg-sign -m "Add demo GIF"
    git push -q origin master 2>/dev/null || git push -q origin main 2>/dev/null
    
    if test $status -ne 0
        echo "Failed to upload GIF to gist"
        cd -
        rm -rf $gist_dir
        return 1
    end
    
    cd -
    
    echo "✅ Demo uploaded!"
    echo "Gist URL: $gist_url"
    echo "Raw GIF URL: https://gist.githubusercontent.com/phinze/$gist_id/raw/demo-$timestamp.gif"
    echo ""
    echo "📋 Markdown embed:"
    echo "![Demo](https://gist.githubusercontent.com/phinze/$gist_id/raw/demo-$timestamp.gif)"

    # Clean up
    rm -rf $gist_dir $md_file $cast_file $gif_file
end