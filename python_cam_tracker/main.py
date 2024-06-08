from collections import deque
import argparse
import cv2
from core.ball_tracker import BallTracker
from pythonosc import udp_client
from core.esp32 import set_resolution, set_quality, URL, cap

set_resolution(URL, index=6)
set_quality(URL, value=38)

ap = argparse.ArgumentParser()
ap.add_argument("-b", "--buffer", type=int, default=16, help="max buffer size")
ap.add_argument("--ip", default="127.0.0.1", help="The ip of the OSC server")
ap.add_argument("--port", type=int, default=57120, help="The port the OSC server is listening on")
args = vars(ap.parse_args())

colorLower = (78, 0, 137)
colorUpper = (117, 141, 236)
pts = deque(maxlen=args["buffer"])
client = udp_client.SimpleUDPClient(args["ip"], args["port"])
ball_tracker = BallTracker(pts, colorLower, colorUpper, args, client)

while True:
  if cap.isOpened():
    ret, frame = cap.read()
    if ret:
      ball_tracker.detect_ball(frame)

    # esc to quit
    if cv2.waitKey(1) & 0xFF == 27: break

cv2.destroyAllWindows()
cap.release()
