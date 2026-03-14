function pt-print --description "Inspect PyTorch .pt file keys and shapes"
    if test (count $argv) -lt 1
        echo "Usage: pt-print <file.pt>"
        return 1
    end

    set -l file_path $argv[1]

    set -l py_code "
import torch
import sys
import os

# Try to import pandas to allowlist its types
try:
    import pandas as pd
    torch.serialization.add_safe_globals([pd.DataFrame, pd.Index, pd.Series])
except ImportError:
    pass

file_path = sys.argv[1]

try:
    try:
        data = torch.load(file_path, map_location='cpu', weights_only=True)
    except Exception:
        data = torch.load(file_path, map_location='cpu', weights_only=False)

    if not isinstance(data, dict):
        print(f'Content Type: {type(data)}')
        if hasattr(data, 'shape'): print(f'Shape: {data.shape}')
        if hasattr(data, 'columns'): print(f'Columns: {list(data.columns)}')
        sys.exit(0)

    header = '{:<60} | {:<20}'.format('KEY NAME', 'SHAPE / INFO')
    print(header)
    print('-' * len(header))

    for k, v in data.items():
        if torch.is_tensor(v):
            info = str(list(v.shape))
        elif hasattr(v, 'shape'): # For DataFrames/Numpy
            info = f'Table/Array {list(v.shape)}'
        elif isinstance(v, (list, dict)):
            info = f'{type(v).__name__} (len: {len(v)})'
        else:
            info = str(type(v).__name__)

        print('{:<60} | {:<20}'.format(str(k), info))

    print('-' * len(header))
    print(f'Total Keys: {len(data)}')

except Exception as e:
    print(f'Error: {e}')
"

    printf "%s" $py_code | python - "$file_path"
end