push-rack:
    rsync -avrz --progress ./data/ bottom:~/documents/sleep-stages-comp/data/

sync-targets:
    rsync -avrz --progress --delete bottom:~/documents/sleep-stages-comp/_targets/ ./_targets/

complix-build:
    complix build --model gemini/gemini-3-flash-preview

sync-m3:
    rsync -avrz --progress --delete m3:bc41_scratch2/sleep-stages-comp/_targets/ ./_targets/

push-m3-data:
    rsync -avrz --progress ./data/ m3:bc41_scratch2/sleep-stages-comp/data/
