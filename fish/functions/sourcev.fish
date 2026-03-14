function sourcev --wraps='source .venv/bin/activate.fish' --description 'alias sourcev=source .venv/bin/activate.fish'
    source .venv/bin/activate.fish $argv
end
