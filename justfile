push-rack:
    rsync -avrz --progress ./data/ bottom:~/documents/sleep-stages-comp/data/

sync-targets:
    rsync -avrz --progress --delete bottom:~/documents/sleep-stages-comp/_targets/ ./_targets/

complix-build:
    complix build --model gemini/gemini-3-flash-preview
