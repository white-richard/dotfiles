function ,o-code
    set model "qwen3.6:27b"
    set ip "100.100.16.25"

    for arg in $argv
        switch $arg
            case --model=*
                set model (string split --max 1 "=" $arg)[2]
            case --ip=*
                set ip (string split --max 1 "=" $arg)[2]
        end
    end

    set -gx ANTHROPIC_BASE_URL http://$ip:11434
    set -gx ANTHROPIC_AUTH_TOKEN ollama
    set -gx ANTHROPIC_API_KEY "not-used"

    claude --model $model
end
