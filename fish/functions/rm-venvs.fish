function rm-venvs --description "Recursively delete all .venv dirs from a given path"
    set search_path $argv[1]
    
    if test -z "$search_path"
        set search_path .
    end
    
    find $search_path -type d \( -name ".venv" -o -name "venv" \) -prune -exec echo "Removing {}" \; -exec rm -rf {} \; 
    deactivate
end