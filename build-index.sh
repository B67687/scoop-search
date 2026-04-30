#!/bin/bash
# Index builder for scoop-search - creates pre-computed search index
# Usage: ./build-index.sh <scoop_home>

SCOOP_HOME="${1:-$USERPROFILE/scoop}"
INDEX_FILE="$SCOOP_HOME/cache/search-index.txt"

echo "Building search index..."

{
    echo "# scoop-search pre-computed index"
    echo "# Format: bucket|name|version|binary1,binary2,..."
    
    for bucket_dir in "$SCOOP_HOME/buckets"/*/bucket 2>/dev/null; do
        [ -d "$bucket_dir" ] || continue
        bucket_name=$(basename "$(dirname "$bucket_dir")")
        
        for manifest in "$bucket_dir"/*.json; do
            [ -f "$manifest" ] || continue
            app_name=$(basename "$manifest" .json)
            
            # Get version
            version=$(grep -oP '"version"\s*:\s*"\K[^"]+' "$manifest" 2>/dev/null || echo "")
            
            # Get bins
            bins=$(grep -oP '"bin"\s*:\s*"\K[^"]+' "$manifest" 2>/dev/null | head -1)
            if [ -z "$bins" ]; then
                bins=$(grep -oP '"\K[^"]+\.exe(?=",|\s*\])' "$manifest" 2>/dev/null | head -2 | tr '\n' ',' | sed 's/,$//')
            fi
            
            echo "$bucket_name|$app_name|$version|$bins"
        done
    done
} > "$INDEX_FILE"

echo "Index built: $INDEX_FILE"
wc -l < "$INDEX_FILE"