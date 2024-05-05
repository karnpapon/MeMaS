## memas

memas, (MEta-MAnifold Sound eXploration) is a set of tools for live-performance utilising computer vision with corpus-based concatinative synthesis

- `/sound_map`: a SuperCollider tool for mapping ball movement to sound corpus.
- `/python_ball_tracking`: a Python tool for tracking ping-pong ball by `OpenCV`
- `/rust_ball_tracking`: a Rust tool for tracking ping-pong ball by `OpenCV`
- `/esp32_setup`: setup esp32 (the easiest way is using `Arduino IDE`)
- `/bela_setup`: soon


## setup
- `export PYTHONPATH=.`, expose port so python can find relative path   
- `python3 algo/warp_perspective_video.py --video resources/pp2.mp4`, test example


## setup vscode + arduino
- https://medium.com/@thomas.kilmar/arduino-cli-with-visual-studio-code-on-macos-d2ad32ff0276
- `arduino-cli config init`, to init `arduino-cli.yaml`
- set library `enable_unsafe_install: true`, then install downloaded `esp32cam` library by `arduino-cli lib install --zip-path /Users/xxxxxxxx/Downloads/esp32cam.zip`

## resources
- esp32+opencv: https://www.digikey.com/en/maker/projects/esp32-cam-python-stream-opencv-example/840608badd0f4a5eb21b1be25ecb42cb