#!/usr/bin/env fish

function strip-req --description 'Strip version specifiers from each line in requirements.txt'
    if test (count $argv) -eq 0
        echo "Usage: strip-req FILE..." >&2
        return 1
    end
    set -l files $argv
    for f in $files
        if test -f "$f"
            perl -i -pe 's/\s*[><=!~][><=!~]?.*//; s/[ \t]+$//;' "$f"
            echo "Processed: $f"
        else
            echo "File not found: $f" >&2
        end
    end
end
