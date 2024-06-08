## MeMaS 

MeMaS, (`/'mɛm-mə/`) (MEta-Manifold Audiovisual System), a set of tools for exploring a connection between image and sound, utilising computer vision with corpus-based concatinative synthesis

- `/memas_sc`: a SuperCollider extension ([`FluCoMa`](https://github.com/flucoma/flucoma-sc/releases/tag/1.0.7) library is required).
- `/python_ball_tracking`: a Python tool for tracking target by `OpenCV`
- `/esp32_setup`: setup [esp32-camera](https://th.cytron.io/c-camera-image-sensor/p-esp32-cam-wireless-iot-vision-development-board) (the easiest way is using `Arduino IDE`)
- `/supercollider_setup`: setup SC for live-performance

## setup
- `export PYTHONPATH=.`, expose port so python can find relative path   
- `python3 algo/warp_perspective_video.py --video resources/pp2.mp4`, test example

## resources
- esp32+opencv: https://www.digikey.com/en/maker/projects/esp32-cam-python-stream-opencv-example/840608badd0f4a5eb21b1be25ecb42cb
