import json
import sys
import time

query = json.loads(sys.argv[1])
if query["width"] == 1440:
    time.sleep(0.5)
if query["width"] == 1100:
    print("{}")
else:
    print(
        json.dumps(
            {
                "name": "compact",
                "x": query["width"] / 10,
                "y": 48,
                "scale": 1,
                "backdropOpacity": 0,
                "backdropColor": "#000000",
                "accent": "#eb2cde",
                "available": True,
            }
        )
    )
