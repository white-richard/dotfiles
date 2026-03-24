function ghwf --description "Run github workflow on the working branch."
    gh workflow run --ref $(git branch --show-current)
end